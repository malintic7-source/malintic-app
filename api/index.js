const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const dataDir = '/tmp';
const dataFile = path.join(dataDir, 'database.json');
const collections = ['users', 'formations', 'inscriptions', 'payments', 'notifications', 'audit_logs', 'seances'];
const sessions = new Map();
const sessionMaxAgeMs = 8 * 60 * 60 * 1000;

let _stateCache = null;
let _stateCacheDirty = true;

function checkRateLimit(map, ip, maxCount, windowMs) {
  const now = Date.now();
  const entry = map.get(ip);
  if (!entry || now > entry.resetAt) {
    map.set(ip, { count: 1, resetAt: now + windowMs });
    return false;
  }
  entry.count += 1;
  if (entry.count > maxCount) return true;
  return false;
}

function getClientIp(req) {
  return (req.headers['x-forwarded-for'] || req.headers['x-real-ip'] || 'unknown').split(',')[0].trim();
}

function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const digest = crypto.scryptSync(password, salt, 64).toString('hex');
  return `scrypt$${salt}$${digest}`;
}

function verifyPassword(password, storedHash) {
  if (!storedHash || !storedHash.startsWith('scrypt$')) return false;
  const [, salt, digest] = storedHash.split('$');
  if (!salt || !digest) return false;
  const actual = crypto.scryptSync(password, salt, 64).toString('hex');
  const expectedBuffer = Buffer.from(digest, 'hex');
  const actualBuffer = Buffer.from(actual, 'hex');
  return expectedBuffer.length === actualBuffer.length && crypto.timingSafeEqual(expectedBuffer, actualBuffer);
}

function publicUser(user) {
  const { password, passwordHash, motDePasse, ...safeUser } = user;
  return safeUser;
}

function publicDocument(collection, document) {
  return collection === 'users' ? publicUser(document) : document;
}

function publicState(state) {
  return Object.fromEntries(collections.map((name) => [
    name,
    state[name].map((item) => publicDocument(name, item)),
  ]));
}

function migrateLegacyPasswords(state) {
  let migrated = false;
  for (const user of state.users || []) {
    if (typeof user.password === 'string' && user.password.length > 0) {
      user.passwordHash = hashPassword(user.password);
      delete user.password;
      migrated = true;
    }
    if (Object.prototype.hasOwnProperty.call(user, 'motDePasse')) {
      delete user.motDePasse;
      migrated = true;
    }
  }
  return migrated;
}

function sessionFromRequest(req) {
  const cookies = Object.fromEntries((req.headers.cookie || '').split(';').map((value) => {
    const [key, ...rest] = value.trim().split('=');
    return [key, decodeURIComponent(rest.join('='))];
  }).filter(([key]) => key));
  const session = sessions.get(cookies.malintic_session);
  if (session && Date.now() - session.createdAt > sessionMaxAgeMs) {
    sessions.delete(cookies.malintic_session);
    return undefined;
  }
  return session;
}

function requireSession(req, res, next) {
  const session = sessionFromRequest(req);
  if (!session) return res.status(401).json({ error: 'Authentification requise' });
  req.session = session;
  next();
}

function isEmployee(session) {
  if (!session) return false;
  const role = String(session?.role || '').toLowerCase().replace('userrole.', '').trim();
  return role !== 'etudiant' && role !== 'apprenant' && role !== 'student' && role.length > 0;
}

function requireEmployee(req, res, next) {
  const session = sessionFromRequest(req);
  if (!isEmployee(session)) return res.status(403).json({ error: 'Accès réservé au personnel' });
  req.session = session;
  next();
}

function isAdministrator(session) {
  const role = String(session?.role || '').toLowerCase().replace('userrole.', '').trim();
  return ['admin', 'dg', 'it'].includes(role);
}

function roleOf(session) {
  return String(session?.role || '').toLowerCase().replace('userrole.', '').trim();
}

function canWriteCollection(session, collection) {
  const role = roleOf(session);
  if (['admin', 'dg', 'it'].includes(role)) return true;
  if (role === 'daf') return ['payments', 'inscriptions', 'notifications', 'audit_logs'].includes(collection);
  if (role === 'comptable') return ['payments', 'notifications', 'audit_logs'].includes(collection);
  if (role === 'assistant') return ['formations', 'inscriptions', 'seances', 'notifications', 'audit_logs'].includes(collection);
  if (role === 'formateur') return ['seances', 'notifications', 'audit_logs'].includes(collection);
  return false;
}

function requireAdministrator(req, res, next) {
  if (!isAdministrator(sessionFromRequest(req))) {
    return res.status(403).json({ error: "Accès réservé à l'administration" });
  }
  req.session = sessionFromRequest(req);
  next();
}

function recordAuditLog(state, { userNom, userRole, action, description, targetId, targetType, severity = 'info', userId, userEmail }) {
  state.audit_logs = Array.isArray(state.audit_logs) ? state.audit_logs : [];
  state.audit_logs.unshift({
    id: `log_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
    userNom: String(userNom || 'Système').trim(),
    userRole: String(userRole || 'Utilisateur').trim(),
    action: String(action || 'Action').trim(),
    description: String(description || '').trim(),
    timestamp: new Date().toISOString(),
    targetId: targetId ? String(targetId) : null,
    targetType: targetType ? String(targetType) : null,
    severity: String(severity || 'info'),
    userId: userId ? String(userId) : null,
    userEmail: userEmail ? String(userEmail) : null,
  });
  if (state.audit_logs.length > 2000) {
    state.audit_logs = state.audit_logs.slice(0, 2000);
  }
}

function initialState() {
  const state = Object.fromEntries(collections.map((name) => [name, []]));
  const email = String(process.env.BOOTSTRAP_ADMIN_EMAIL || '').trim().toLowerCase();
  const password = String(process.env.BOOTSTRAP_ADMIN_PASSWORD || '');
  if (email && password) {
    state.users.push({
      id: 'admin_vercel_initial',
      email,
      nom: 'Administrateur',
      prenom: 'Mamadou',
      phone: '',
      role: 'UserRole.admin',
      passwordHash: hashPassword(password),
      estActif: true,
      dateCreation: new Date().toISOString(),
    });
  }
  return state;
}

function readState() {
  if (_stateCache !== null && !_stateCacheDirty) {
    return _stateCache;
  }
  try {
    if (!fs.existsSync(dataFile)) {
      const state = initialState();
      fs.writeFileSync(dataFile, JSON.stringify(state, null, 2));
      _stateCache = state;
      _stateCacheDirty = false;
      return state;
    }
    const parsed = JSON.parse(fs.readFileSync(dataFile, 'utf8'));
    for (const name of collections) if (!Array.isArray(parsed[name])) parsed[name] = [];
    if (migrateLegacyPasswords(parsed)) writeState(parsed);
    _stateCache = parsed;
    _stateCacheDirty = false;
    return parsed;
  } catch (error) {
    const state = initialState();
    _stateCache = state;
    _stateCacheDirty = false;
    return state;
  }
}

function writeState(state) {
  try {
    fs.writeFileSync(dataFile, JSON.stringify(state, null, 2));
    _stateCache = state;
    _stateCacheDirty = false;
  } catch (error) {
    console.error('Error writing state:', error);
  }
}

function isCollection(name) { return collections.includes(name); }

function validateFormationAssignments(data, users) {
  const modules = Array.isArray(data.modules) ? data.modules.map(String) : [];
  const assignments = data.moduleFormateurIds;
  if (assignments == null) return null;
  if (typeof assignments !== 'object' || Array.isArray(assignments)) {
    return 'moduleFormateurIds doit être un objet {module: idFormateur}.';
  }
  for (const [module, formateurId] of Object.entries(assignments)) {
    if (!formateurId) continue;
    if (!modules.includes(module)) continue;
    const formateur = users.find((user) => String(user.id) === String(formateurId));
    if (formateur) {
      const role = String(formateur.role || '').toLowerCase().replace('userrole.', '').trim();
      if (role === 'apprenant' || role === 'etudiant') {
        return `Le responsable du module « ${module} » ne peut pas être un apprenant.`;
      }
    }
  }
  return null;
}

const loginAttempts = new Map();
const LOGIN_MAX_ATTEMPTS = 5;
const LOGIN_WINDOW_MS = 15 * 60 * 1000;

const inscriptionAttempts = new Map();
const INSCRIPTION_MAX_PER_HOUR = 10;
const INSCRIPTION_WINDOW_MS = 60 * 60 * 1000;

export default function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Credentials', 'true');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const url = new URL(req.url, `http://${req.headers.host}`);
  const path = url.pathname;

  if (path === '/api/health') {
    return res.json({ status: 'ok' });
  }

  if (path === '/api/state') {
    res.setHeader('Cache-Control', 'no-store');
    const state = readState();
    return res.json(publicState(state));
  }

  if (path === '/api/auth/login' && req.method === 'POST') {
    const ip = getClientIp(req);
    if (checkRateLimit(loginAttempts, ip, LOGIN_MAX_ATTEMPTS, LOGIN_WINDOW_MS)) {
      return res.status(429).json({
        error: 'Trop de tentatives de connexion. Réessayez dans 15 minutes.',
      });
    }
    const input = String(req.body?.email || req.body?.identifier || '').trim().toLowerCase();
    const password = String(req.body?.password || '');
    const cleanInputPhone = input.replace(/[^0-9]/g, '');

    const state = readState();
    const user = state.users.find((item) => {
      const itemEmail = String(item.email || '').trim().toLowerCase();
      const itemPhone = String(item.phone || item.telephone || '').replace(/[^0-9]/g, '');
      const itemMatricule = String(item.matricule || '').trim().toLowerCase();
      const emailPrefix = itemEmail.split('@')[0];

      if (itemEmail === input) return true;
      if (emailPrefix === input) return true;
      if (itemMatricule && itemMatricule === input) return true;
      if (cleanInputPhone.length >= 8 && itemPhone.includes(cleanInputPhone)) return true;
      if (`${input}@mntic.ml` === itemEmail || `${input}@malintic.ml` === itemEmail) return true;
      return false;
    });

    if (!user) {
      return res.status(401).json({ error: 'Aucun compte trouvé avec cet identifiant.' });
    }

    if (user.estActif === false) {
      return res.status(403).json({ error: 'Ce compte est désactivé. Veuillez contacter un administrateur.' });
    }

    const passwordMatches = verifyPassword(password, user.passwordHash) || (user.password && password === user.password);
    if (!passwordMatches) {
      return res.status(401).json({ error: 'Mot de passe incorrect.' });
    }

    loginAttempts.delete(ip);
    if (user.password) {
      user.passwordHash = hashPassword(password);
      delete user.password;
    }

    const userFullName = `${user.prenom || ''} ${user.nom || ''}`.trim() || user.email;
    recordAuditLog(state, {
      userNom: userFullName,
      userRole: user.role,
      action: 'Connexion',
      description: `Connexion réussie de ${userFullName} (${user.email}) - Rôle: ${user.role} - IP: ${ip}`,
      userId: user.id,
      userEmail: user.email,
      severity: 'info',
    });
    writeState(state);

    const token = crypto.randomBytes(32).toString('hex');
    sessions.set(token, { userId: user.id, role: user.role, createdAt: Date.now() });
    res.setHeader('Set-Cookie', `malintic_session=${token}; Path=/; HttpOnly; SameSite=Lax; Max-Age=28800`);
    return res.json(publicUser(user));
  }

  if (path === '/api/auth/logout' && req.method === 'POST') {
    const token = (req.headers.cookie || '').match(/malintic_session=([^;]+)/)?.[1];
    if (token) sessions.delete(token);

    const state = readState();
    const user = state.users.find((item) => item.id === req.session?.userId);
    if (user) {
      const userFullName = `${user.prenom || ''} ${user.nom || ''}`.trim() || user.email;
      recordAuditLog(state, {
        userNom: userFullName,
        userRole: user.role,
        action: 'Déconnexion',
        description: `Déconnexion de la session de ${userFullName} (${user.email})`,
        userId: user.id,
        userEmail: user.email,
        severity: 'info',
      });
      writeState(state);
    }

    res.setHeader('Set-Cookie', 'malintic_session=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0');
    return res.status(204).end();
  }

  if (path === '/api/auth/session' && req.method === 'GET') {
    const session = sessionFromRequest(req);
    if (!session) return res.status(401).json({ error: 'Session invalide' });
    const user = readState().users.find((item) => item.id === session.userId);
    if (!user || user.estActif === false) return res.status(401).json({ error: 'Session invalide' });
    return res.json(publicUser(user));
  }

  const collectionMatch = path.match(/^\/api\/([^\/]+)$/);
  if (collectionMatch && req.method === 'GET') {
    const collection = collectionMatch[1];
    if (!isCollection(collection)) return res.status(404).json({ error: 'Collection inconnue' });
    if (collection !== 'formations' && !sessionFromRequest(req)) {
      return res.status(401).json({ error: 'Authentification requise' });
    }
    if (collection !== 'formations' && !isEmployee(sessionFromRequest(req))) {
      return res.status(403).json({ error: 'Accès réservé au personnel' });
    }
    return res.json(readState()[collection].map((item) => publicDocument(collection, item)));
  }

  const itemMatch = path.match(/^\/api\/([^\/]+)\/([^\/]+)$/);
  if (itemMatch) {
    const [collection, id] = [itemMatch[1], itemMatch[2]];
    if (!isCollection(collection)) return res.status(404).json({ error: 'Collection inconnue' });

    if (req.method === 'GET') {
      if (collection !== 'formations') {
        if (!sessionFromRequest(req)) return res.status(401).json({ error: 'Authentification requise' });
        if (!isEmployee(sessionFromRequest(req))) return res.status(403).json({ error: 'Accès réservé au personnel' });
      }
      const item = readState()[collection].find((entry) => String(entry.id) === id);
      if (!item) return res.status(404).json({ error: 'Document introuvable' });
      res.setHeader('Cache-Control', 'no-store');
      return res.json(publicDocument(collection, item));
    }

    if (req.method === 'PUT') {
      const isPublicRegistration = collection === 'inscriptions' && req.body?.source === 'web';
      if (isPublicRegistration) {
        const ip = getClientIp(req);
        if (checkRateLimit(inscriptionAttempts, ip, INSCRIPTION_MAX_PER_HOUR, INSCRIPTION_WINDOW_MS)) {
          return res.status(429).json({
            error: 'Trop de demandes. Veuillez réessayer dans une heure.',
          });
        }
      }

      if (!isPublicRegistration && !isEmployee(sessionFromRequest(req))) {
        return res.status(403).json({ error: 'Accès réservé au personnel' });
      }
      const state = readState();
      const list = state[collection];
      const existingIndex = list.findIndex((item) => String(item.id) === id);
      const session = sessionFromRequest(req);

      if (collection === 'users' && existingIndex >= 0 && String(session?.userId) === String(id)) {
        const existing = list[existingIndex];
        const profileFields = ['nom', 'prenom', 'phone', 'photoUrl', 'sexe', 'specialite'];
        const updatedProfile = { ...existing };
        for (const field of profileFields) {
          if (Object.prototype.hasOwnProperty.call(req.body || {}, field)) updatedProfile[field] = req.body[field];
        }
        updatedProfile.dateModification = new Date().toISOString();
        list[existingIndex] = updatedProfile;
        writeState(state);
        return res.json(publicUser(updatedProfile));
      }

      if (collection === 'users' && !isAdministrator(session)) {
        return res.status(403).json({ error: "La gestion des comptes est réservée à l'administration." });
      }

      if (!isPublicRegistration && !canWriteCollection(session, collection)) {
        return res.status(403).json({ error: 'Vous ne disposez pas des droits nécessaires pour cette action.' });
      }

      const data = { ...(req.body || {}), id };
      if (isPublicRegistration) {
        data.status = 'InscriptionStatus.enAttente';
        data.paiementId = null;
        data.paiementEffectue = false;
        data.dateAcceptation = null;
        data.motifRejet = null;
        data.dateInscription = new Date().toISOString();
      }

      if (collection === 'users' && data.password) {
        data.passwordHash = hashPassword(String(data.password));
        delete data.password;
      } else if (collection === 'users') {
        delete data.password;
        delete data.passwordHash;
      }

      if (collection === 'formations') {
        const assignmentError = validateFormationAssignments(data, state.users);
        if (assignmentError) return res.status(400).json({ error: assignmentError });
      }

      const index = existingIndex;
      if (index >= 0) list[index] = { ...list[index], ...data };
      else list.push(data);
      writeState(state);
      return res.json(publicDocument(collection, data));
    }

    if (req.method === 'DELETE') {
      const session = sessionFromRequest(req);
      if (!isEmployee(session)) return res.status(403).json({ error: 'Accès réservé au personnel' });
      if (collection === 'users' && !isAdministrator(session)) {
        return res.status(403).json({ error: "La gestion des comptes est réservée à l'administration." });
      }
      if (!canWriteCollection(session, collection)) {
        return res.status(403).json({ error: 'Vous ne disposez pas des droits nécessaires pour cette action.' });
      }
      const state = readState();
      state[collection] = state[collection].filter((item) => String(item.id) !== id);
      writeState(state);
      return res.status(204).end();
    }
  }

  return res.status(404).json({ error: 'Endpoint not found' });
}
