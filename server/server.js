const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '15mb' }));
app.use((_, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('Cache-Control', 'no-store');
  next();
});

const dataDir = process.env.DATA_DIR || '/data';
const dataFile = path.join(dataDir, 'database.json');
const backupFile = path.join(dataDir, 'database.backup.json');
const collections = ['users', 'formations', 'inscriptions', 'payments', 'notifications', 'audit_logs', 'seances'];
const sessions = new Map();
const sessionMaxAgeMs = 8 * 60 * 60 * 1000; // 8 heures

// ─── #5 Cache mémoire pour éviter la relecture disque à chaque requête ────────
let _stateCache = null;
let _stateCacheDirty = true;

// ─── #7 Rate-limiting login (5 tentatives / 15 min / IP) ─────────────────────
const loginAttempts = new Map(); // ip → { count, resetAt }
const LOGIN_MAX_ATTEMPTS = 5;
const LOGIN_WINDOW_MS = 15 * 60 * 1000; // 15 minutes

// ─── #19 Rate-limiting inscriptions publiques (10 / heure / IP) ──────────────
const inscriptionAttempts = new Map(); // ip → { count, resetAt }
const INSCRIPTION_MAX_PER_HOUR = 10;
const INSCRIPTION_WINDOW_MS = 60 * 60 * 1000; // 1 heure

function checkRateLimit(map, ip, maxCount, windowMs) {
  const now = Date.now();
  const entry = map.get(ip);
  if (!entry || now > entry.resetAt) {
    map.set(ip, { count: 1, resetAt: now + windowMs });
    return false; // not rate-limited
  }
  entry.count += 1;
  if (entry.count > maxCount) return true; // rate-limited
  return false;
}

function getClientIp(req) {
  return (req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown').split(',')[0].trim();
}

// ─── Sécurité mots de passe ───────────────────────────────────────────────────
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

function legacyPasswordMatches(password, legacyPassword) {
  if (typeof legacyPassword !== 'string') return false;
  const expectedBuffer = Buffer.from(legacyPassword);
  const actualBuffer = Buffer.from(password);
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

function trainerCanAccessFormation(state, trainerId, formationId) {
  const formation = state.formations.find((item) => String(item.id) === String(formationId));
  if (!formation) return false;
  if ((formation.formateurIds || []).some((id) => String(id) === String(trainerId))) return true;
  return Object.values(formation.moduleFormateurIds || {}).some((id) => String(id) === String(trainerId));
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
      id: 'admin_local_initial',
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

// ─── #5 Lecture avec cache mémoire ────────────────────────────────────────────
function readState() {
  // Retourner le cache si disponible et non invalidé
  if (_stateCache !== null && !_stateCacheDirty) {
    return _stateCache;
  }
  fs.mkdirSync(dataDir, { recursive: true });
  if (!fs.existsSync(dataFile)) {
    const bundledSeed = path.join(__dirname, 'initial_database.json');
    if (fs.existsSync(bundledSeed)) {
      try {
        const seedData = JSON.parse(fs.readFileSync(bundledSeed, 'utf8'));
        for (const name of collections) if (!Array.isArray(seedData[name])) seedData[name] = [];
        migrateLegacyPasswords(seedData);
        fs.writeFileSync(dataFile, JSON.stringify(seedData, null, 2));
        _stateCache = seedData;
        _stateCacheDirty = false;
        return seedData;
      } catch (_) {}
    }
    const state = initialState();
    fs.writeFileSync(dataFile, JSON.stringify(state, null, 2));
    _stateCache = state;
    _stateCacheDirty = false;
    return state;
  }
  try {
    const parsed = JSON.parse(fs.readFileSync(dataFile, 'utf8'));
    for (const name of collections) if (!Array.isArray(parsed[name])) parsed[name] = [];
    if (migrateLegacyPasswords(parsed)) writeState(parsed);
    _stateCache = parsed;
    _stateCacheDirty = false;
    return parsed;
  } catch (error) {
    if (fs.existsSync(backupFile)) {
      try {
        const restored = JSON.parse(fs.readFileSync(backupFile, 'utf8'));
        for (const name of collections) if (!Array.isArray(restored[name])) restored[name] = [];
        migrateLegacyPasswords(restored);
        fs.writeFileSync(dataFile, JSON.stringify(restored, null, 2));
        _stateCache = restored;
        _stateCacheDirty = false;
        return restored;
      } catch (_) {}
    }
    throw new Error(`Base locale illisible : ${error.message}`);
  }
}

function writeState(state) {
  const temporary = `${dataFile}.tmp`;
  fs.writeFileSync(temporary, JSON.stringify(state, null, 2));
  if (fs.existsSync(dataFile)) fs.copyFileSync(dataFile, backupFile);
  fs.renameSync(temporary, dataFile);
  // Invalider le cache après chaque écriture
  _stateCache = state;
  _stateCacheDirty = false;
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

app.get('/api/health', (_, res) => res.json({ status: 'ok' }));

app.get('/api/system/network-info', (req, res) => {
  const os = require('os');
  const interfaces = os.networkInterfaces();
  const detectedIps = [];

  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        detectedIps.push(iface.address);
      }
    }
  }

  const clientIp = getClientIp(req);
  const hostHeader = String(req.headers.host || '').trim();
  const forwardedHost = String(req.headers['x-forwarded-host'] || '').trim();
  const activeHost = forwardedHost || hostHeader;

  const ngrokDomain = process.env.NGROK_DOMAIN || 'boil-prude-curry.ngrok-free.dev';
  const publicUrl = process.env.PUBLIC_URL || (ngrokDomain ? `https://${ngrokDomain}` : null);

  res.json({
    clientIp,
    activeHost,
    detectedIps,
    ngrokDomain,
    publicUrl,
  });
});

// ─── #7 Login avec rate-limiting ─────────────────────────────────────────────
app.post('/api/auth/login', (req, res) => {
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

  const passwordMatches = verifyPassword(password, user.passwordHash) || legacyPasswordMatches(password, user.password);
  if (!passwordMatches) {
    return res.status(401).json({ error: 'Mot de passe incorrect.' });
  }

  // Réinitialiser le compteur en cas de succès
  loginAttempts.delete(ip);
  if (user.password) {
    user.passwordHash = hashPassword(password);
    delete user.password;
  }

  // Enregistrer le log de connexion détaillée
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
  // #6 — Max-Age pour la survie aux redémarrages (8 heures)
  res.setHeader('Set-Cookie', `malintic_session=${token}; Path=/; HttpOnly; SameSite=Lax; Max-Age=28800`);
  res.json(publicUser(user));
});

app.post('/api/auth/logout', requireSession, (req, res) => {
  const token = (req.headers.cookie || '').match(/malintic_session=([^;]+)/)?.[1];
  if (token) sessions.delete(token);

  const state = readState();
  const user = state.users.find((item) => item.id === req.session.userId);
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
  res.status(204).end();
});

app.get('/api/auth/session', requireSession, (req, res) => {
  const user = readState().users.find((item) => item.id === req.session.userId);
  if (!user || user.estActif === false) return res.status(401).json({ error: 'Session invalide' });
  res.json(publicUser(user));
});

app.post('/api/auth/change-password', (req, res) => {
  const session = sessionFromRequest(req);
  const userId = req.body?.userId || req.body?.id || session?.userId;
  const email = String(req.body?.email || req.body?.identifier || '').trim().toLowerCase();
  const currentPassword = String(req.body?.currentPassword || '');
  const newPassword = String(req.body?.newPassword || '').trim();
  const isFirstLogin = Boolean(req.body?.isFirstLogin);

  if (newPassword.length < 6) {
    return res.status(400).json({ error: 'Le nouveau mot de passe doit contenir au moins 6 caractères.' });
  }

  const state = readState();
  const user = state.users.find((item) => {
    if (userId && String(item.id) === String(userId)) return true;
    const itemEmail = String(item.email || '').trim().toLowerCase();
    if (email && itemEmail === email) return true;
    return false;
  });

  if (!user) return res.status(404).json({ error: 'Utilisateur introuvable.' });

  // Si un ancien mot de passe est fourni, on le vérifie
  if (currentPassword) {
    const matches = verifyPassword(currentPassword, user.passwordHash) || legacyPasswordMatches(currentPassword, user.password) || (user.doitChangerMotDePasse && currentPassword === '00000000');
    if (!matches) {
      return res.status(401).json({ error: 'Ancien mot de passe incorrect.' });
    }
  } else if (!user.doitChangerMotDePasse && !isFirstLogin) {
    return res.status(400).json({ error: 'Veuillez saisir votre mot de passe actuel.' });
  }

  user.passwordHash = hashPassword(newPassword);
  delete user.password;
  delete user.motDePasse;
  user.doitChangerMotDePasse = false;
  user.dateModification = new Date().toISOString();

  const userFullName = `${user.prenom || ''} ${user.nom || ''}`.trim() || user.email;
  recordAuditLog(state, {
    userNom: userFullName,
    userRole: user.role,
    action: isFirstLogin ? 'Mot de passe initial défini' : 'Changement mot de passe',
    description: `${userFullName} (${user.email}) a modifié son mot de passe avec succès.`,
    userId: user.id,
    userEmail: user.email,
    targetId: user.id,
    targetType: 'user',
    severity: 'info',
  });

  writeState(state);
  res.json(publicUser(user));
});

app.post('/api/admin/users/:id/password', requireAdministrator, (req, res) => {
  const { newPassword, mustChangePassword = true } = req.body || {};
  const password = String(newPassword || '00000000').trim();
  if (password.length < 6) {
    return res.status(400).json({ error: 'Le mot de passe doit contenir au moins 6 caractères.' });
  }
  const state = readState();
  const user = state.users.find((item) => String(item.id) === String(req.params.id));
  if (!user) return res.status(404).json({ error: 'Utilisateur introuvable.' });

  user.passwordHash = hashPassword(password);
  delete user.password;
  user.doitChangerMotDePasse = Boolean(mustChangePassword);
  user.dateModification = new Date().toISOString();

  // Log in audit trail
  const adminUser = state.users.find((u) => u.id === req.session.userId);
  const adminNom = adminUser ? `${adminUser.prenom} ${adminUser.nom}`.trim() : 'Administration';
  const targetNom = `${user.prenom} ${user.nom}`.trim();

  recordAuditLog(state, {
    userNom: adminNom,
    userRole: req.session.role,
    action: 'Réinitialisation mot de passe admin',
    description: `Mot de passe de ${targetNom} (${user.email}) modifié par ${adminNom} (Forcer changement 1ère connexion: ${mustChangePassword ? 'Oui' : 'Non'})`,
    targetId: user.id,
    targetType: 'user',
    userId: req.session.userId,
    userEmail: adminUser?.email,
    severity: 'warning',
  });

  writeState(state);
  res.json({ success: true, user: publicUser(user) });
});

app.post('/api/trainer/students/:id/attendance', requireEmployee, (req, res) => {
  const { formationId, status, note } = req.body || {};
  const state = readState();
  if (!trainerCanAccessFormation(state, req.session.userId, formationId) && !isAdministrator(req.session)) {
    return res.status(403).json({ error: "Vous n'êtes pas affecté à cette formation." });
  }
  const student = state.users.find((item) => String(item.id) === req.params.id);
  const assignment = student?.assignedFormations?.find((item) => String(item.formationId) === String(formationId));
  if (!student || !assignment) return res.status(404).json({ error: 'Apprenant ou formation introuvable.' });
  assignment.attendance = Array.isArray(assignment.attendance) ? assignment.attendance : [];
  assignment.attendance.push({ date: new Date().toISOString(), status: String(status || ''), note: String(note || '') });
  writeState(state);
  res.status(204).end();
});

app.post('/api/trainer/students/:id/progress', requireEmployee, (req, res) => {
  const { formationId, moduleTitle, delta } = req.body || {};
  const state = readState();
  if (!trainerCanAccessFormation(state, req.session.userId, formationId) && !isAdministrator(req.session)) {
    return res.status(403).json({ error: "Vous n'êtes pas affecté à cette formation." });
  }
  const student = state.users.find((item) => String(item.id) === req.params.id);
  const assignment = student?.assignedFormations?.find((item) => String(item.formationId) === String(formationId));
  const module = assignment?.modules?.find((item) => item.title === moduleTitle);
  if (!module) return res.status(404).json({ error: 'Module introuvable.' });
  const nextHours = Number(module.doneHours || 0) + Number(delta || 0);
  module.doneHours = Math.max(0, Math.min(nextHours, Number(module.assignedHours || nextHours)));
  writeState(state);
  res.status(204).end();
});

app.get('/api/state', (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  const state = readState();
  return res.json(publicState(state));
});

// Browser-driven state migrations are deliberately disabled.
app.put('/api/state', requireAdministrator, (req, res) => {
  res.status(410).json({ error: "Migration navigateur désactivée. Utilisez un outil d'administration dédié." });
});

app.post('/api/state/merge', requireAdministrator, (req, res) => {
  res.status(410).json({ error: 'Fusion navigateur désactivée. Le serveur est la source de vérité.' });
});

app.get('/api/:collection', (req, res) => {
  if (!isCollection(req.params.collection)) return res.status(404).json({ error: 'Collection inconnue' });
  if (req.params.collection !== 'formations' && !sessionFromRequest(req)) {
    return res.status(401).json({ error: 'Authentification requise' });
  }
  if (req.params.collection !== 'formations' && !isEmployee(sessionFromRequest(req))) {
    return res.status(403).json({ error: 'Accès réservé au personnel' });
  }
  res.json(readState()[req.params.collection].map((item) => publicDocument(req.params.collection, item)));
});

app.get('/api/:collection/:id', (req, res) => {
  const { collection, id } = req.params;
  if (!isCollection(collection)) return res.status(404).json({ error: 'Collection inconnue' });
  if (collection !== 'formations') {
    if (!sessionFromRequest(req)) return res.status(401).json({ error: 'Authentification requise' });
    if (!isEmployee(sessionFromRequest(req))) return res.status(403).json({ error: 'Accès réservé au personnel' });
  }
  const item = readState()[collection].find((entry) => String(entry.id) === id);
  if (!item) return res.status(404).json({ error: 'Document introuvable' });
  res.setHeader('Cache-Control', 'no-store');
  res.json(publicDocument(collection, item));
});

app.put('/api/:collection/:id', (req, res) => {
  const { collection, id } = req.params;
  if (!isCollection(collection)) return res.status(404).json({ error: 'Collection inconnue' });
  const isPublicRegistration = collection === 'inscriptions' && req.body?.source === 'web';

  // ─── #19 Rate-limiting pour les inscriptions publiques ───────────────────
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
  if (isPublicRegistration && existingIndex >= 0) {
    return res.status(409).json({ error: 'Une inscription publique ne peut pas être modifiée.' });
  }
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
    if (!data.formationId || !state.formations.some((formation) => String(formation.id) === String(data.formationId))) {
      return res.status(400).json({ error: 'Formation invalide.' });
    }
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
  res.json(publicDocument(collection, data));
});

app.delete('/api/:collection/:id', (req, res) => {
  const { collection, id } = req.params;
  if (!isCollection(collection)) return res.status(404).json({ error: 'Collection inconnue' });
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
  res.status(204).end();
});

app.listen(5001, () => console.log('API Malintic disponible sur le port 5001'));
