const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const zlib = require('zlib');
const os = require('os');

const app = express();
app.disable('x-powered-by');
app.enable('trust proxy');

// ─── OWASP Security Headers Middleware ─────────────────────────────────────
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'SAMEORIGIN');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  next();
});

const isProduction = process.env.NODE_ENV === 'production';
const allowedOrigins = new Set(
  String(process.env.CORS_ALLOWED_ORIGINS || '')
    .split(',')
    .map((origin) => origin.trim().replace(/\/$/, ''))
    .filter(Boolean),
);
for (const origin of [process.env.PUBLIC_URL, process.env.NGROK_DOMAIN && `https://${process.env.NGROK_DOMAIN}`]) {
  if (origin) allowedOrigins.add(origin.replace(/\/$/, ''));
}


// ─── HTTPS Redirect en production (exemptant les IP LAN locales et loopback) ──────────────────
if (isProduction) {
  app.use((req, res, next) => {
    if (req.path === '/api/health' || req.path === '/api/v1/health') return next();
    const host = req.hostname || '';
    const isLocalhost = ['localhost', '127.0.0.1', 'api', 'malintic_api'].includes(host) ||
      host.startsWith('192.168.') ||
      host.startsWith('10.') ||
      host.startsWith('172.') ||
      host.endsWith('.local');
    if (isLocalhost) return next();

    const proto = req.headers['x-forwarded-proto'] || req.protocol;
    if (proto !== 'https') {
      return res.redirect(301, `https://${req.get('host')}${req.originalUrl}`);
    }
    next();
  });
}

// ─── Rate-limiting pour endpoints admin ───────────────────────────────────
const adminAttempts = new Map(); // ip → { count, resetAt }
const ADMIN_MAX_REQUESTS = 100; // 100 requêtes
const ADMIN_WINDOW_MS = 60 * 1000; // par minute

function requireAdminRateLimit(req, res, next) {
  const ip = getClientIp(req);
  if (checkRateLimit(adminAttempts, ip, ADMIN_MAX_REQUESTS, ADMIN_WINDOW_MS)) {
    return res.status(429).json({ error: 'Trop de requêtes admin. Réessayez dans une minute.' });
  }
  next();
}

// Response compression for ngrok and LAN speed optimization
app.use((req, res, next) => {
  const acceptEncoding = req.headers['accept-encoding'] || '';
  if (!acceptEncoding.includes('gzip')) return next();

  const originalSend = res.send;
  res.send = function (body) {
    if (typeof body === 'string' || Buffer.isBuffer(body)) {
      const buffer = Buffer.isBuffer(body) ? body : Buffer.from(body);
      if (buffer.length > 512) {
        zlib.gzip(buffer, (err, compressed) => {
          if (err) return originalSend.call(this, body);
          res.setHeader('Content-Encoding', 'gzip');
          res.setHeader('Content-Length', compressed.length);
          res.removeHeader('ETag');
          return originalSend.call(this, compressed);
        });
        return;
      }
    }
    return originalSend.call(this, body);
  };
  next();
});

// ─── Content-Type validation ─────────────────────────────────────────────
app.use((req, res, next) => {
  if (['POST', 'PUT', 'PATCH'].includes(req.method)) {
    const contentType = req.get('content-type') || '';
    if (!contentType.includes('application/json')) {
      return res.status(400).json({ error: 'Content-Type must be application/json' });
    }
  }
  next();
});

app.use(express.json({ limit: '15mb' }));
app.use((req, res, next) => {
  const origin = String(req.headers.origin || '').replace(/\/$/, '');
  const isAllowedOrigin = !origin ||
    allowedOrigins.has(origin) ||
    origin.includes('localhost') ||
    origin.includes('127.0.0.1') ||
    origin.includes('192.168.') ||
    origin.includes('10.') ||
    origin.includes('172.') ||
    origin.includes('.local') ||
    origin.includes('vercel.app') ||
    origin.includes('ngrok-free.app') ||
    origin.includes('ngrok.io') ||
    origin.includes('onrender.com');

  if (origin && isAllowedOrigin) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Credentials', 'true');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, ngrok-skip-browser-warning');
  }
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('Cache-Control', 'no-store');
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  next();
});

// ─── Health & System Info ───────────────────────────────────────────────────
app.get(['/api/health', '/api/v1/health'], (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: Math.floor(process.uptime()),
  });
});

app.get(['/api/system/network-info', '/api/v1/system/network-info'], (req, res) => {
  const detectedIps = [];

  // 1. Détection via variables d'environnement (Windows Host LAN/Wi-Fi IP)
  const envHostIp = (process.env.HOST_LAN_IP || process.env.LAN_IP || '').trim();
  if (envHostIp && !detectedIps.includes(envHostIp)) {
    detectedIps.push(envHostIp);
  }

  // 2. Extraire l'IP ou l'hôte de la requête (si l'administrateur a ouvert l'app via son IP LAN)
  const hostHeader = (req.headers['x-forwarded-host'] || req.headers.host || '').split(':')[0].trim();
  if (hostHeader && hostHeader !== 'localhost' && hostHeader !== '127.0.0.1' && !hostHeader.startsWith('172.') && !detectedIps.includes(hostHeader)) {
    detectedIps.push(hostHeader);
  }

  // 3. Scanner les interfaces locales (en excluant les adresses loopback, Docker 172.x et APIPA 169.254.x)
  const interfaces = os.networkInterfaces();
  const secondaryIps = [];
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        const addr = iface.address;
        if (addr.startsWith('192.168.') || addr.startsWith('10.')) {
          if (!detectedIps.includes(addr)) detectedIps.push(addr);
        } else if (!addr.startsWith('127.') && !addr.startsWith('169.254.')) {
          if (!secondaryIps.includes(addr)) secondaryIps.push(addr);
        }
      }
    }
  }

  for (const ip of secondaryIps) {
    if (!detectedIps.includes(ip)) detectedIps.push(ip);
  }

  res.json({
    detectedIps,
    primaryIp: detectedIps[0] || 'localhost',
    port: Number(process.env.PORT || 5001),
    appPort: 80,
    ngrokDomain: process.env.NGROK_DOMAIN || null,
  });
});

const dataDir = process.env.DATA_DIR || '/data';
const dataFile = path.join(dataDir, 'database.json');
const backupFile = path.join(dataDir, 'database.backup.json');
const sessionsFile = path.join(dataDir, 'sessions.json');
const collections = ['users', 'formations', 'inscriptions', 'payments', 'notifications', 'audit_logs', 'seances'];
const sessions = new Map();
const sessionMaxAgeMs = 8 * 60 * 60 * 1000; // 8 heures

function loadSessions() {
  try {
    if (fs.existsSync(sessionsFile)) {
      const data = JSON.parse(fs.readFileSync(sessionsFile, 'utf8'));
      const now = Date.now();
      for (const [token, session] of Object.entries(data)) {
        if (session && (now - session.createdAt) < sessionMaxAgeMs) {
          sessions.set(token, session);
        }
      }
    }
  } catch (_) {}
}

function saveSessions() {
  try {
    fs.mkdirSync(dataDir, { recursive: true });
    const obj = Object.fromEntries(sessions.entries());
    fs.writeFileSync(sessionsFile, JSON.stringify(obj, null, 2));
  } catch (_) {}
}

loadSessions();

// ─── #11 Cleanup périodique des sessions expirées ────────────────────────────
setInterval(() => {
  const now = Date.now();
  let cleaned = 0;
  for (const [token, session] of sessions.entries()) {
    if (!session || (now - session.createdAt) >= sessionMaxAgeMs) {
      sessions.delete(token);
      cleaned++;
    }
  }
  if (cleaned > 0) {
    saveSessions();
    console.log(`[Sessions] ${cleaned} session(s) expirée(s) supprimée(s)`);
  }
}, 60 * 60 * 1000); // Nettoyage toutes les heures

// ─── #5 Cache mémoire pour éviter la relecture disque à chaque requête ────────
let _stateCache = null;
let _stateCacheDirty = true;
let _stateVersion = Date.now().toString();

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
  safeUser.doitChangerMotDePasse = Boolean(user.doitChangerMotDePasse || user.must_change_password);
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

const SFP_OFFICIAL_19_MODULES = [
  'Base de données + IA',
  'Initiation à Windows Server',
  'Initiation au Réseau Téléphonique VoIP',
  'Initiation à la Sécurité Informatique',
  'Maintenance Informatique',
  'Système de Vidéosurveillance Analogique',
  'Initiation au Réseau Informatique',
  'Initiation au Système de Panneau Solaire (SPS)',
  'Adobe Photoshop',
  'Adobe Première Pro',
  'CapCut / VN + IA (Vidéos)',
  'Canva + IA (Affiches)',
  'Sage 100 comptabilité Générale',
  'IMITECH (Initiation en entrepreneuriat : Business Model Canvas)',
  'Word et Excel',
  'Community Management',
  'Intelligence Artificielle (IA)',
  'Internet des Objets (IOT)',
  'Création d’applications (Flutter)',
];

const SFP_BONUS_MODULES = [
  'Initiation en informatique (Matériels, Logiciels)',
  'PowerPoint + IA',
  'Mémoire de fin d’étude Universitaire ou Professionnel',
];

const SFP_OFFICIAL_PRICES = {
  'Base de données + IA': 33000,
  'Initiation à Windows Server': 28000,
  'Initiation au Réseau Téléphonique VoIP': 26000,
  'Initiation à la Sécurité Informatique': 30000,
  'Maintenance Informatique': 29000,
  'Système de Vidéosurveillance Analogique': 27000,
  'Initiation au Réseau Informatique': 28000,
  'Initiation au Système de Panneau Solaire (SPS)': 28000,
  'Adobe Photoshop': 22000,
  'Adobe Première Pro': 22000,
  'CapCut / VN + IA (Vidéos)': 22000,
  'Canva + IA (Affiches)': 20000,
  'Sage 100 comptabilité Générale': 28000,
  'IMITECH (Initiation en entrepreneuriat : Business Model Canvas)': 25000,
  'Word et Excel': 20000,
  'Community Management': 23000,
  'Intelligence Artificielle (IA)': 32000,
  'Internet des Objets (IOT)': 28000,
  'Création d’applications (Flutter)': 33000,
};

function repairFormations(state) {
  if (!Array.isArray(state.formations)) return false;
  let modified = false;

  for (const f of state.formations) {
    const isSfp = f.id === '09cKUMEJm3UnRztD4Jm2' ||
      f.id === 'form_sfp_2026' ||
      String(f.titre || '').toLowerCase().includes('sfp') ||
      String(f.titre || '').toLowerCase().includes('stage de formation professionnelle') ||
      f.estStage === true ||
      f.est_stage === true;

    if (isSfp) {
      if (f.titre !== 'Stage de Formation Professionnelle - SFP5') {
        f.titre = 'Stage de Formation Professionnelle - SFP5';
        modified = true;
      }
      if (f.description !== 'Stage professionnel de 3 mois. Choisissez 3 modules parmi les 19 proposés et bénéficiez des bonus offerts : initiation en informatique, PowerPoint + IA et mémoire de fin d’étude universitaire ou professionnel.') {
        f.description = 'Stage professionnel de 3 mois. Choisissez 3 modules parmi les 19 proposés et bénéficiez des bonus offerts : initiation en informatique, PowerPoint + IA et mémoire de fin d’étude universitaire ou professionnel.';
        modified = true;
      }
      if (f.estStage !== true) { f.estStage = true; modified = true; }
      if (f.est_stage !== true) { f.est_stage = true; modified = true; }
      if (f.maxModulesParEtudiant !== 3) { f.maxModulesParEtudiant = 3; modified = true; }
      if (f.max_modules_par_etudiant !== 3) { f.max_modules_par_etudiant = 3; modified = true; }
      if (f.prix !== 100000) { f.prix = 100000; modified = true; }
      if (f.prixEnLigne !== 125000) { f.prixEnLigne = 125000; f.prix_en_ligne = 125000; modified = true; }
      if (f.dureeSemaines !== 12) { f.dureeSemaines = 12; f.duree_semaines = 12; modified = true; }
      if (f.dureeHeures !== '3 mois • 3 séances par semaine • 3h par séance') {
        f.dureeHeures = '3 mois • 3 séances par semaine • 3h par séance';
        f.duree_heures = '3 mois • 3 séances par semaine • 3h par séance';
        modified = true;
      }
      if (!Array.isArray(f.modulesBonus) || f.modulesBonus.length < 3) {
        f.modulesBonus = [...SFP_BONUS_MODULES];
        f.modules_bonus = [...SFP_BONUS_MODULES];
        modified = true;
      }
      if (!Array.isArray(f.modules) || f.modules.length < 19) {
        f.modules = [...SFP_OFFICIAL_19_MODULES];
        modified = true;
      }
      if (!f.modulePrices || Object.keys(f.modulePrices).length < 19) {
        f.modulePrices = { ...SFP_OFFICIAL_PRICES };
        f.module_prices = { ...SFP_OFFICIAL_PRICES };
        modified = true;
      }
    } else {
      if (f.estStage !== false) { f.estStage = false; f.est_stage = false; modified = true; }
      if (f.maxModulesParEtudiant !== null && f.maxModulesParEtudiant !== undefined) {
        f.maxModulesParEtudiant = null;
        f.max_modules_par_etudiant = null;
        modified = true;
      }
      if (!f.modulePrices || Object.keys(f.modulePrices).length === 0) {
        f.modulePrices = {};
        for (const m of (f.modules || [])) {
          const modName = String(m).toLowerCase();
          if (modName.includes('flutter') || modName.includes('react') || modName.includes('node')) {
            f.modulePrices[m] = 45000;
          } else if (modName.includes('svs') || modName.includes('vidéo') || modName.includes('analogique') || modName.includes('ip')) {
            f.modulePrices[m] = 40000;
          } else {
            f.modulePrices[m] = 35000;
          }
        }
        f.module_prices = { ...f.modulePrices };
        modified = true;
      }
    }
  }

  return modified;
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
      role: 'admin',
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
      } catch (_) { }
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
    const pwMigrated = migrateLegacyPasswords(parsed);
    const formRepaired = repairFormations(parsed);
    if (pwMigrated || formRepaired) writeState(parsed);
    _stateCache = parsed;
    _stateCacheDirty = false;
    return parsed;
  } catch (error) {
    if (fs.existsSync(backupFile)) {
      try {
        const restored = JSON.parse(fs.readFileSync(backupFile, 'utf8'));
        for (const name of collections) if (!Array.isArray(restored[name])) restored[name] = [];
        const pwMigrated = migrateLegacyPasswords(restored);
        const formRepaired = repairFormations(restored);
        if (pwMigrated || formRepaired) writeState(restored);
        _stateCache = restored;
        _stateCacheDirty = false;
        return restored;
      } catch (_) { }
    }
    throw new Error(`Base locale illisible : ${error.message}`);
  }
}

// ─── Synchronisation Supabase ─────────────────────────────────────────────────
const SUPABASE_URL = String(process.env.SUPABASE_URL || '').replace(/\/$/, '');
const SUPABASE_KEY = String(
  process.env.SUPABASE_SERVICE_ROLE_KEY
    || process.env.SUPABASE_KEY
    || process.env.SUPABASE_ANON_KEY
    || '',
);
const _syncQueue = []; // queue de documents à synchroniser
let _syncRunning = false;

function _cleanRole(r) { return String(r || 'apprenant').replace(/UserRole\./gi, '').trim(); }
function _cleanStatus(s, prefix) { return String(s || '').replace(new RegExp(prefix + '\\.', 'gi'), '').trim() || undefined; }
function _ts(v) { try { return v ? new Date(v).toISOString() : null; } catch (_) { return null; } }

function _mapFormation(f) {
  return {
    id: f.id,
    titre: f.titre || '',
    description: f.description || '',
    prix: Number(f.prix) || 0,
    modules: f.modules || [],
    formateur_ids: f.formateurIds || f.formateur_ids || [],
    module_formateur_ids: f.moduleFormateurIds || f.module_formateur_ids || {},
    type: _cleanStatus(f.type, 'FormationType') || 'presentielle',
    status: _cleanStatus(f.status, 'FormationStatus') || 'programmee',
    duree_semaines: Number(f.dureeSemaines || f.duree_semaines) || 0,
    duree_heures: f.dureeHeures || f.duree_heures || null,
    horaires: f.horaires || [],
    photo_url: f.photoUrl || f.photo_url || null,
    est_stage: !!f.estStage,
    max_modules_par_etudiant: Number(f.maxModulesParEtudiant || f.max_modules_par_etudiant) || null,
    nombre_inscrits: Number(f.nombreInscrits || f.nombre_inscrits) || 0,
    date_creation: _ts(f.dateCreation || f.date_creation),
    prix_en_ligne: f.prixEnLigne != null ? Number(f.prixEnLigne) : null,
    capacite_max: f.capaciteMax != null ? Number(f.capaciteMax) : null,
    date_debut: _ts(f.dateDebut || f.date_debut),
    date_fin: _ts(f.dateFin || f.date_fin),
    modules_bonus: f.modulesBonus || f.modules_bonus || [],
    module_prices: f.modulePrices || f.module_prices || {},
  };
}

const VALID_ROLES = ['admin', 'dg', 'daf', 'comptable', 'assistant', 'it', 'formateur', 'apprenant'];

function _mapUser(u) {
  const cleanedRole = _cleanRole(u.role);
  // Valider que le rôle est dans la liste autorisée
  const validatedRole = VALID_ROLES.includes(cleanedRole) ? cleanedRole : 'apprenant';
  return {
    id: u.id,
    email: u.email || '',
    nom: u.nom || '',
    prenom: u.prenom || '',
    phone: u.phone || '',
    matricule: u.matricule || null,
    role: validatedRole,
    photo_url: u.photoUrl || u.photo_url || null,
    specialite: u.specialite || null,
    sexe: u.sexe || 'Homme',
    est_actif: u.estActif !== false,
    assigned_formations: u.assignedFormations || u.assigned_formations || [],
    must_change_password: u.doitChangerMotDePasse === true || u.must_change_password === true,
    date_creation: _ts(u.dateCreation || u.date_creation),
    date_modification: _ts(u.dateModification || u.date_modification),
  };
}

function _mapInscription(i) {
  return {
    id: i.id,
    etudiant_id: i.etudiantId || i.apprenantId || null,
    formation_id: i.formationId || null,
    nom: i.nom || null,
    prenom: i.prenom || null,
    email: i.email || null,
    telephone: i.telephone || null,
    sexe: i.sexe || null,
    status: _cleanStatus(i.status, 'InscriptionStatus') || 'enAttente',
    paiement_effectue: !!i.paiementEffectue,
    paiement_id: i.paiementId || null,
    motif_rejet: i.motifRejet || null,
    date_inscription: _ts(i.dateInscription || i.date_inscription),
    date_acceptation: _ts(i.dateAcceptation || i.date_acceptation),
    source: i.source || 'web',
    modules: i.selectedModules || i.modules || [],
    type_formation: i.typeFormation || null,
    description: i.description || null,
  };
}

function _mapPayment(p) {
  return {
    id: p.id,
    inscription_id: p.inscriptionId || p.inscription_id || null,
    etudiant_id: p.etudiantId || p.etudiant_id || null,
    formation_id: p.formationId || p.formation_id || null,
    montant: Number(p.montant) || 0,
    remise: Number(p.remise) || 0,
    tranche_numero: Number(p.trancheNumero || p.tranche_numero) || 1,
    nombre_tranches: Number(p.nombreTranches || p.nombre_tranches) || 1,
    status: p.status || 'effectue',
    methode: p.methode || 'especes',
    reference: p.reference || null,
    recu_par: p.recuPar || p.recu_par || null,
    module_id: p.moduleId || p.module_id || null,
    date_paiement: _ts(p.datePaiement || p.date_paiement),
    date_creation: _ts(p.dateCreation || p.date_creation),
  };
}

function _unmapFormation(row) {
  return {
    ...row,
    formateurIds: row.formateur_ids || [],
    moduleFormateurIds: row.module_formateur_ids || {},
    dureeSemaines: row.duree_semaines || 0,
    dureeHeures: row.duree_heures,
    photoUrl: row.photo_url,
    estStage: row.est_stage === true,
    maxModulesParEtudiant: row.max_modules_par_etudiant,
    nombreInscrits: row.nombre_inscrits || 0,
    dateCreation: row.date_creation,
    prixEnLigne: row.prix_en_ligne,
    capaciteMax: row.capacite_max,
    dateDebut: row.date_debut,
    dateFin: row.date_fin,
    modulesBonus: row.modules_bonus || [],
    modulePrices: row.module_prices || {},
  };
}

function _unmapUser(row) {
  return {
    ...row,
    passwordHash: row.password_hash,
    photoUrl: row.photo_url,
    estActif: row.est_actif !== false,
    assignedFormations: row.assigned_formations || [],
    doitChangerMotDePasse: row.must_change_password === true,
    dateCreation: row.date_creation,
    dateModification: row.date_modification,
  };
}

function _unmapInscription(row) {
  return {
    ...row,
    etudiantId: row.etudiant_id,
    formationId: row.formation_id,
    paiementEffectue: row.paiement_effectue === true,
    paiementId: row.paiement_id,
    motifRejet: row.motif_rejet,
    dateInscription: row.date_inscription,
    dateAcceptation: row.date_acceptation,
    selectedModules: row.modules || [],
    typeFormation: row.type_formation,
  };
}

function _unmapPayment(row) {
  return {
    ...row,
    inscriptionId: row.inscription_id,
    etudiantId: row.etudiant_id,
    formationId: row.formation_id,
    trancheNumero: row.tranche_numero,
    nombreTranches: row.nombre_tranches,
    recuPar: row.recu_par,
    moduleId: row.module_id,
    datePaiement: row.date_paiement,
    dateCreation: row.date_creation,
  };
}

function _unmapSeance(row) {
  return {
    ...row,
    formationId: row.formation_id,
    formateurId: row.formateur_id,
    moduleTitle: row.module_title,
    dateDebut: row.date_debut,
    dateFin: row.date_fin,
    dateCreation: row.date_creation,
  };
}

function _mapSeance(s) {
  return {
    id: s.id,
    formation_id: s.formationId || s.formation_id || null,
    formateur_id: s.formateurId || s.formateur_id || null,
    titre: s.titre || '',
    module_title: s.moduleTitle || s.module_title || null,
    description: s.description || null,
    date_debut: _ts(s.dateDebut || s.date_debut),
    date_fin: _ts(s.dateFin || s.date_fin),
    statut: s.statut || 'brouillon',
    contenu: s.contenu || [],
    presences: s.presences || [],
    date_creation: _ts(s.dateCreation || s.date_creation),
  };
}

function _unmapAuditLog(row) {
  return {
    ...row,
    userNom: row.user_nom,
    userRole: row.user_role,
    targetId: row.target_id,
    targetType: row.target_type,
  };
}

function _mapAuditLog(log) {
  return {
    id: log.id,
    user_nom: log.userNom || log.user_nom || null,
    user_role: log.userRole || log.user_role || null,
    action: log.action || '',
    description: log.description || null,
    timestamp: _ts(log.timestamp),
    target_id: log.targetId || log.target_id || null,
    target_type: log.targetType || log.target_type || null,
    severity: log.severity || 'info',
  };
}

const _remoteTables = {
  formations: { mapper: _mapFormation, unmapper: _unmapFormation },
  users: { mapper: _mapUser, unmapper: _unmapUser },
  inscriptions: { mapper: _mapInscription, unmapper: _unmapInscription },
  payments: { mapper: _mapPayment, unmapper: _unmapPayment },
  seances: { mapper: _mapSeance, unmapper: _unmapSeance },
  audit_logs: { mapper: _mapAuditLog, unmapper: _unmapAuditLog },
  notifications: { mapper: (row) => row, unmapper: (row) => row },
};

async function _supabaseGet(table) {
  const fetchFn = globalThis.fetch;
  if (!fetchFn) throw new Error('fetch indisponible dans cette version de Node.js');
  const res = await fetchFn(`${SUPABASE_URL}/rest/v1/${table}?select=*`, {
    headers: {
      apikey: SUPABASE_KEY,
      Authorization: `Bearer ${SUPABASE_KEY}`,
      Accept: 'application/json',
    },
    signal: AbortSignal.timeout ? AbortSignal.timeout(8000) : undefined,
  });
  if (!res.ok) throw new Error(`${table} GET ${res.status}: ${(await res.text()).slice(0, 200)}`);
  return res.json();
}

async function _supabaseUpsert(table, row, retries = 2) {
  const fetchFn = globalThis.fetch;
  if (!fetchFn) return;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const res = await fetchFn(`${SUPABASE_URL}/rest/v1/${table}`, {
        method: 'POST',
        headers: {
          'apikey': SUPABASE_KEY,
          'Authorization': `Bearer ${SUPABASE_KEY}`,
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates',
        },
        body: JSON.stringify(row),
        signal: AbortSignal.timeout ? AbortSignal.timeout(8000) : undefined,
      });
      if (res.ok || res.status === 200 || res.status === 201 || res.status === 204) return;
      const errText = await res.text();
      console.error(`[Supabase] ${table} upsert ${res.status}: ${errText.substring(0, 200)}`);
      return;
    } catch (err) {
      if (attempt < retries) await new Promise(r => setTimeout(r, 500 * (attempt + 1)));
      else console.error(`[Supabase] ${table} network error: ${err.message}`);
    }
  }
}

async function _supabaseDelete(table, id, retries = 2) {
  const fetchFn = globalThis.fetch;
  if (!fetchFn) return;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const res = await fetchFn(`${SUPABASE_URL}/rest/v1/${table}?id=eq.${encodeURIComponent(id)}`, {
        method: 'DELETE',
        headers: {
          'apikey': SUPABASE_KEY,
          'Authorization': `Bearer ${SUPABASE_KEY}`,
        },
        signal: AbortSignal.timeout ? AbortSignal.timeout(8000) : undefined,
      });
      if (res.ok || res.status === 204) return;
      return;
    } catch (err) {
      if (attempt < retries) await new Promise(r => setTimeout(r, 500 * (attempt + 1)));
    }
  }
}

async function _drainSyncQueue() {
  if (_syncRunning || _syncQueue.length === 0) return;
  _syncRunning = true;
  while (_syncQueue.length > 0) {
    const task = _syncQueue.shift();
    try { await task(); } catch (_) { }
  }
  _syncRunning = false;
}

function enqueueSyncState(state) {
  _syncQueue.push(async () => {
    const tableMap = Object.fromEntries(
      Object.entries(_remoteTables).map(([table, config]) => [
        table,
        { rows: state[table] || [], mapper: config.mapper },
      ]),
    );
    for (const [table, { rows, mapper }] of Object.entries(tableMap)) {
      for (const row of rows) {
        await _supabaseUpsert(table, mapper(row));
      }
    }
  });
  setImmediate(_drainSyncQueue);
}

function enqueueSyncDocument(collection, doc, deleted = false) {
  const mapper = _remoteTables[collection]?.mapper;
  if (!mapper) return;
  _syncQueue.push(async () => {
    if (deleted) await _supabaseDelete(collection, doc.id);
    else await _supabaseUpsert(collection, mapper(doc));
  });
  setImmediate(_drainSyncQueue);
}

// ─── Tracking des suppressions & Réplication PRA / PCA ────────────────────────
const _deletedDocIds = {
  formations: new Set(),
  users: new Set(),
  inscriptions: new Set(),
  payments: new Set(),
  seances: new Set(),
  audit_logs: new Set(),
  notifications: new Set(),
};

const _prevIds = { formations: new Set(), users: new Set(), inscriptions: new Set(), payments: new Set() };
const _syncTables = ['formations', 'users', 'inscriptions', 'payments', 'seances', 'audit_logs', 'notifications'];
let _lastSyncHash = '';
let _lastSyncTime = 0;
const SYNC_THROTTLE_MS = 1_000;

function _stateHash(state) {
  const parts = _syncTables.map(t =>
    (state[t] || []).map(r => `${r.id}:${r.dateModification || r.dateCreation || ''}`).join(',')
  );
  return parts.join('|');
}

function _extractTimestamp(item) {
  if (!item) return 0;
  const raw = item.dateModification || item.date_modification ||
              item.dateCreation || item.date_creation ||
              item.updatedAt || item.updated_at ||
              item.createdAt || item.created_at ||
              item.timestamp;
  if (!raw) return 0;
  const t = new Date(raw).getTime();
  return isNaN(t) ? 0 : t;
}

let _remotePullRunning = false;
async function reconcileTwoWay(reason = 'periodic') {
  if (_remotePullRunning || _syncRunning || !SUPABASE_KEY || !SUPABASE_URL) return;
  _remotePullRunning = true;
  try {
    const remoteData = await Promise.all(
      Object.entries(_remoteTables).map(async ([table, config]) => {
        try {
          const rows = await _supabaseGet(table);
          return [table, rows, config];
        } catch (e) {
          console.warn(`[Supabase] Lecture ${table} indisponible (${e.message})`);
          return [table, null, config];
        }
      }),
    );

    const localState = readState();
    let localModified = false;
    const itemsToUpsertSupabase = [];

    for (const [table, remoteRows, config] of remoteData) {
      if (!Array.isArray(remoteRows)) continue;

      const localList = Array.isArray(localState[table]) ? localState[table] : [];
      const localMap = new Map(localList.map((item) => [String(item.id), item]));
      const unmappedRemote = remoteRows.map(config.unmapper);
      const deletedSet = _deletedDocIds[table] || new Set();

      for (const remoteItem of unmappedRemote) {
        const id = String(remoteItem.id);
        if (deletedSet.has(id)) {
          _syncQueue.push(() => _supabaseDelete(table, id));
          continue;
        }

        if (!localMap.has(id)) {
          localList.push(remoteItem);
          localMap.set(id, remoteItem);
          localModified = true;
        } else {
          const localItem = localMap.get(id);
          const remoteTime = _extractTimestamp(remoteItem);
          const localTime = _extractTimestamp(localItem);

          if (remoteTime > localTime) {
            const idx = localList.findIndex((it) => String(it.id) === id);
            if (idx >= 0) {
              localList[idx] = { ...localList[idx], ...remoteItem };
              localModified = true;
            }
          } else if (localTime > remoteTime) {
            itemsToUpsertSupabase.push({ table, row: config.mapper(localItem) });
          }
        }
      }

      localState[table] = localList;
    }

    if (localModified) {
      writeState(localState);
    }

    if (itemsToUpsertSupabase.length > 0) {
      _syncQueue.push(async () => {
        for (const { table, row } of itemsToUpsertSupabase) {
          await _supabaseUpsert(table, row);
        }
      });
      setImmediate(_drainSyncQueue);
    }
  } catch (error) {
    console.error(`[Supabase] Réconciliation impossible: ${error.message}`);
  } finally {
    _remotePullRunning = false;
  }
}

// ─── PRA (Plan de Reprise d'Activité) - Snapshots & Recovery ─────────────────
const praDir = path.join(dataDir, 'backups');
try { fs.mkdirSync(praDir, { recursive: true }); } catch (_) {}
const MAX_PRA_SNAPSHOTS = 10;

function createPraSnapshot(label = 'auto', reason = 'backup') {
  try {
    fs.mkdirSync(praDir, { recursive: true });
    const state = readState();
    const timestamp = new Date().toISOString();
    const cleanLabel = String(label).replace(/[^a-zA-Z0-9_-]/g, '_').substring(0, 30);
    const filename = `pra_snapshot_${Date.now()}_${cleanLabel}.json`;
    const targetPath = path.join(praDir, filename);

    const counts = Object.fromEntries(collections.map((name) => [name, (state[name] || []).length]));
    const payload = {
      metadata: {
        version: '1.0',
        label: cleanLabel,
        reason,
        createdAt: timestamp,
        counts,
      },
      state,
    };

    fs.writeFileSync(targetPath, JSON.stringify(payload, null, 2));

    // Rotation des 10 derniers snapshots
    const existing = listPraSnapshots();
    if (existing.length > MAX_PRA_SNAPSHOTS) {
      const toRemove = existing.slice(MAX_PRA_SNAPSHOTS);
      for (const item of toRemove) {
        try { fs.unlinkSync(path.join(praDir, item.filename)); } catch (_) {}
      }
    }

    return { success: true, filename, createdAt: timestamp, counts };
  } catch (e) {
    console.error(`[PRA] Erreur création snapshot: ${e.message}`);
    return { success: false, error: e.message };
  }
}

function listPraSnapshots() {
  try {
    if (!fs.existsSync(praDir)) return [];
    const files = fs.readdirSync(praDir).filter((f) => f.startsWith('pra_snapshot_') && f.endsWith('.json'));
    const list = [];
    for (const f of files) {
      try {
        const fullPath = path.join(praDir, f);
        const stats = fs.statSync(fullPath);
        let meta = { label: 'inconnu', reason: '', createdAt: stats.mtime.toISOString(), counts: {} };
        try {
          const content = JSON.parse(fs.readFileSync(fullPath, 'utf8'));
          if (content.metadata) meta = content.metadata;
        } catch (_) {}
        list.push({
          filename: f,
          sizeBytes: stats.size,
          createdAt: meta.createdAt || stats.mtime.toISOString(),
          label: meta.label || f,
          reason: meta.reason || '',
          counts: meta.counts || {},
        });
      } catch (_) {}
    }
    list.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    return list;
  } catch (_) {
    return [];
  }
}

function restorePraSnapshot(filename) {
  try {
    const safeName = path.basename(filename);
    const fullPath = path.join(praDir, safeName);
    if (!fs.existsSync(fullPath)) throw new Error('Fichier de snapshot introuvable.');

    const raw = JSON.parse(fs.readFileSync(fullPath, 'utf8'));
    const state = raw.state || raw;

    for (const name of collections) if (!Array.isArray(state[name])) state[name] = [];
    migrateLegacyPasswords(state);
    repairFormations(state);
    writeState(state);

    // Synchronisation vers Supabase
    enqueueSyncState(state);

    return {
      success: true,
      message: `Point de restauration ${safeName} réappliqué avec succès.`,
      counts: Object.fromEntries(collections.map((name) => [name, state[name].length])),
    };
  } catch (e) {
    return { success: false, error: e.message };
  }
}

function writeState(state) {
  const temporary = `${dataFile}.tmp`;
  fs.writeFileSync(temporary, JSON.stringify(state, null, 2));
  if (fs.existsSync(dataFile)) fs.copyFileSync(dataFile, backupFile);
  fs.renameSync(temporary, dataFile);
  _stateCache = state;
  _stateCacheDirty = false;
  _stateVersion = Date.now().toString();

  const now = Date.now();
  const hash = _stateHash(state);
  const hasChanged = hash !== _lastSyncHash;
  const canSync = (now - _lastSyncTime) >= SYNC_THROTTLE_MS;

  if (!hasChanged) return;
  if (!canSync && _lastSyncTime > 0) return;

  _lastSyncHash = hash;
  _lastSyncTime = now;

  const mappers = Object.fromEntries(
    Object.entries(_remoteTables).map(([table, config]) => [table, config.mapper]),
  );
  const snap = {};
  for (const t of _syncTables) snap[t] = new Set((state[t] || []).map(r => r.id));

  _syncQueue.push(async () => {
    for (const t of _syncTables) {
      const mapper = mappers[t];
      const rows = state[t] || [];
      for (const row of rows) await _supabaseUpsert(t, mapper(row));
      for (const oldId of _prevIds[t]) {
        if (!snap[t].has(oldId)) await _supabaseDelete(t, oldId);
      }
      _prevIds[t] = snap[t];
    }
  });
  setImmediate(_drainSyncQueue);
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

// ─── API Versioning - /api/v1/ redirige vers /api/ ────────────────────────
app.use('/api/v1/*', (req, res, next) => {
  // Remapper /api/v1/... vers /api/...
  req.url = req.url.replace(/^\/api\/v1/, '/api');
  next();
});

app.get('/api/health', (_, res) => res.json({ status: 'ok' }));
app.get('/api/v1/health', (_, res) => res.json({ status: 'ok' }));

app.get('/api/system/network-info', requireAdministrator, (req, res) => {
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

  // ⚠️ NGROK_DOMAIN doit être défini en variable d'environnement (voir .env.example)
  // Ne pas utiliser de fallback hardcodé
  const ngrokDomain = process.env.NGROK_DOMAIN || null;
  const publicUrl = process.env.PUBLIC_URL || (ngrokDomain ? `https://${ngrokDomain}` : null);

  res.json({
    clientIp,
    activeHost,
    detectedIps,
    ngrokDomain,
    publicUrl,
  });
});

// ─── Endpoints PCA (Continuité d'Activité) & PRA (Reprise d'Activité) ─────────
app.get('/api/pca/status', async (req, res) => {
  const state = readState();
  let dbSizeBytes = 0;
  try {
    if (fs.existsSync(dataFile)) {
      dbSizeBytes = fs.statSync(dataFile).size;
    }
  } catch (_) {}

  // Test de connectivité Supabase Cloud & mesure de latence
  const supabaseStatus = {
    configured: Boolean(SUPABASE_URL && SUPABASE_KEY),
    connected: false,
    latencyMs: null,
    lastSyncTime: _lastSyncTime ? new Date(_lastSyncTime).toISOString() : null,
    pendingSyncCount: _syncQueue.length,
    url: SUPABASE_URL ? SUPABASE_URL.replace(/https:\/\/(.{4}).*(\.supabase\.co)/, 'https://$1***$2') : null,
  };

  if (SUPABASE_URL && SUPABASE_KEY) {
    const start = Date.now();
    try {
      const ping = await globalThis.fetch(`${SUPABASE_URL}/rest/v1/formations?select=id&limit=1`, {
        headers: {
          apikey: SUPABASE_KEY,
          Authorization: `Bearer ${SUPABASE_KEY}`,
          Accept: 'application/json',
        },
        signal: AbortSignal.timeout ? AbortSignal.timeout(3500) : undefined,
      });
      supabaseStatus.connected = ping.ok;
      supabaseStatus.latencyMs = Date.now() - start;
    } catch (e) {
      supabaseStatus.connected = false;
      supabaseStatus.error = e.message;
    }
  }

  const snapshots = listPraSnapshots();

  res.json({
    node: 'docker-lan',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    memoryUsageMb: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
    storage: {
      databaseSizeBytes: dbSizeBytes,
      dataFile,
      backupFileExists: fs.existsSync(backupFile),
    },
    counts: Object.fromEntries(collections.map((name) => [name, (state[name] || []).length])),
    supabase: supabaseStatus,
    pra: {
      snapshotsCount: snapshots.length,
      latestSnapshot: snapshots[0] || null,
      autoBackupEnabled: true,
    },
    activeSessions: sessions.size,
  });
});

app.post('/api/pra/snapshot', requireAdministrator, (req, res) => {
  const label = req.body?.label || 'manuel';
  const reason = req.body?.reason || 'instantané administrateur';
  const result = createPraSnapshot(label, reason);
  if (!result.success) return res.status(500).json(result);
  res.json(result);
});

app.get('/api/pra/snapshots', requireAdministrator, (req, res) => {
  res.json({ snapshots: listPraSnapshots() });
});

app.post('/api/pra/restore', requireAdministrator, (req, res) => {
  const filename = req.body?.filename;
  if (!filename) return res.status(400).json({ error: 'Nom du fichier de snapshot requis.' });
  const result = restorePraSnapshot(filename);
  if (!result.success) return res.status(500).json(result);
  res.json(result);
});

app.post('/api/pra/reconcile', requireAdministrator, async (req, res) => {
  try {
    await reconcileTwoWay('manual_admin_trigger');
    const state = readState();
    res.json({
      success: true,
      message: 'Réconciliation bidirectionnelle Docker <-> Supabase effectuée avec succès.',
      counts: Object.fromEntries(collections.map((name) => [name, (state[name] || []).length])),
    });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});

app.get('/api/pra/export', requireAdministrator, (req, res) => {
  const state = readState();
  const exportPayload = {
    metadata: {
      exportedAt: new Date().toISOString(),
      exporter: req.session?.userId || 'admin',
      version: '1.0',
      counts: Object.fromEntries(collections.map((name) => [name, (state[name] || []).length])),
    },
    state,
  };
  res.setHeader('Content-Disposition', `attachment; filename="malintic_backup_${Date.now()}.json"`);
  res.setHeader('Content-Type', 'application/json');
  res.send(JSON.stringify(exportPayload, null, 2));
});

app.post('/api/pra/import', requireAdministrator, (req, res) => {
  const payload = req.body;
  const importedState = payload?.state || payload;
  if (!importedState || typeof importedState !== 'object') {
    return res.status(400).json({ error: 'Format d\'archive de données invalide.' });
  }
  for (const name of collections) {
    if (!Array.isArray(importedState[name])) importedState[name] = [];
  }
  migrateLegacyPasswords(importedState);
  repairFormations(importedState);
  writeState(importedState);
  enqueueSyncState(importedState);

  // Créer automatiquement un snapshot post-import
  createPraSnapshot('post_import', 'importation de données');

  res.json({
    success: true,
    message: 'Données importées et synchronisées avec succès.',
    counts: Object.fromEntries(collections.map((name) => [name, importedState[name].length])),
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
  
  // Valider le format email si c'est un email
  if (input.includes('@') && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input)) {
    return res.status(400).json({ error: 'Format d\'email invalide.' });
  }
  const cleanInputPhone = input.replace(/[^0-9]/g, '');

  const state = readState();
  const user = state.users.find((item) => {
    const itemEmail = String(item.email || '').trim().toLowerCase();
    const itemPhone = String(item.phone || '').replace(/[^0-9]/g, '');
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
  saveSessions();
  // Cookie de session sans Max-Age (automatiquement détruit à la fermeture du navigateur)
  res.setHeader('Set-Cookie', `malintic_session=${token}; Path=/; HttpOnly; SameSite=Lax${isProduction ? '; Secure' : ''}`);
  res.json(publicUser(user));
});

app.post('/api/auth/logout', requireSession, (req, res) => {
  const token = (req.headers.cookie || '').match(/malintic_session=([^;]+)/)?.[1];
  if (token) {
    sessions.delete(token);
    saveSessions();
  }

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
  const bodyUserId = req.body?.userId;
  const bodyEmail = String(req.body?.email || req.body?.identifier || '').trim().toLowerCase();
  const currentPassword = String(req.body?.currentPassword || '');
  const newPassword = String(req.body?.newPassword || '').trim();
  const isFirstLogin = Boolean(req.body?.isFirstLogin);

  if (newPassword.length < 6) {
    return res.status(400).json({ error: 'Le nouveau mot de passe doit contenir au moins 6 caractères.' });
  }

  const state = readState();
  let user = null;
  if (session?.userId) {
    user = state.users.find((item) => String(item.id) === String(session.userId));
  }
  if (!user && bodyUserId) {
    user = state.users.find((item) => String(item.id) === String(bodyUserId));
  }
  if (!user && bodyEmail) {
    user = state.users.find((item) => String(item.email || '').trim().toLowerCase() === bodyEmail);
  }

  if (!user) return res.status(404).json({ error: 'Utilisateur introuvable.' });

  // Si l'utilisateur n'a pas de session active et n'est pas en première connexion, vérifier l'ancien mot de passe
  if (!session && !isFirstLogin && !user.doitChangerMotDePasse) {
    if (!currentPassword) {
      return res.status(400).json({ error: 'Veuillez saisir votre mot de passe actuel.' });
    }
    const matches = verifyPassword(currentPassword, user.passwordHash) || legacyPasswordMatches(currentPassword, user.password);
    if (!matches) {
      return res.status(401).json({ error: 'Ancien mot de passe incorrect.' });
    }
  } else if (currentPassword) {
    const matches = verifyPassword(currentPassword, user.passwordHash) || legacyPasswordMatches(currentPassword, user.password);
    if (!matches) {
      return res.status(401).json({ error: 'Ancien mot de passe incorrect.' });
    }
  }

  user.passwordHash = hashPassword(newPassword);
  delete user.password;
  delete user.motDePasse;
  user.doitChangerMotDePasse = false;
  user.must_change_password = false;
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

  // Pour la première connexion ou demande explicite, purger les sessions existantes
  if (isFirstLogin || req.body?.logoutAfterChange) {
    for (const [sToken, sData] of sessions.entries()) {
      if (String(sData.userId) === String(user.id)) {
        sessions.delete(sToken);
      }
    }
    saveSessions();
    res.setHeader('Set-Cookie', 'malintic_session=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0');
  } else {
    const token = crypto.randomBytes(32).toString('hex');
    sessions.set(token, { userId: user.id, role: user.role, createdAt: Date.now() });
    saveSessions();
    res.setHeader('Set-Cookie', `malintic_session=${token}; Path=/; HttpOnly; SameSite=Lax${isProduction ? '; Secure' : ''}`);
  }

  enqueueSyncDocument('users', user);
  writeState(state);

  res.json({
    ...publicUser(user),
    loggedOut: isFirstLogin || Boolean(req.body?.logoutAfterChange),
    message: 'Mot de passe mis à jour avec succès.',
  });
});

app.post('/api/admin/users/:id/password', requireAdministrator, requireAdminRateLimit, (req, res) => {
  const session = req.session;
  const state = readState();

  const { newPassword, doitChangerMotDePasse = true } = req.body || {};
  const password = String(newPassword || '').trim();
  if (!password || password.length < 6) {
    return res.status(400).json({ error: 'Le mot de passe doit contenir au moins 6 caractères.' });
  }

  const user = state.users.find((item) => String(item.id) === String(req.params.id));
  if (!user) return res.status(404).json({ error: 'Utilisateur introuvable.' });

  user.passwordHash = hashPassword(password);
  delete user.password;
  user.doitChangerMotDePasse = Boolean(doitChangerMotDePasse);
  user.dateModification = new Date().toISOString();

  // Log in audit trail
  const adminUser = state.users.find((u) => u.id === session.userId);
  const adminNom = adminUser ? `${adminUser.prenom} ${adminUser.nom}`.trim() : 'Administration';
  const targetNom = `${user.prenom} ${user.nom}`.trim();

  recordAuditLog(state, {
    userNom: adminNom,
    userRole: session?.role || 'admin',
    action: 'Réinitialisation mot de passe admin',
    description: `Mot de passe de ${targetNom} (${user.email}) modifié par ${adminNom} (Forcer changement 1ère connexion: ${doitChangerMotDePasse ? 'Oui' : 'Non'})`,

    targetId: user.id,
    targetType: 'user',
    userId: session.userId,
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
  const ifNoneMatch = req.headers['if-none-match'];
  res.setHeader('ETag', `"${_stateVersion}"`);
  res.setHeader('Cache-Control', 'no-cache');
  if (ifNoneMatch === `"${_stateVersion}"` || ifNoneMatch === _stateVersion) {
    return res.status(304).end();
  }
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

function handleCollectionPut(req, res) {
  const { collection, id } = req.params;
  if (!isCollection(collection)) return res.status(404).json({ error: 'Collection inconnue' });
  const session = sessionFromRequest(req);
  const isEmployeeSession = isEmployee(session);
  const isPublicRegistration = collection === 'inscriptions' && !isEmployeeSession;

  // ─── #19 Rate-limiting pour les inscriptions publiques ───────────────────
  if (isPublicRegistration) {
    const ip = getClientIp(req);
    if (checkRateLimit(inscriptionAttempts, ip, INSCRIPTION_MAX_PER_HOUR, INSCRIPTION_WINDOW_MS)) {
      return res.status(429).json({
        error: 'Trop de demandes. Veuillez réessayer dans une heure.',
      });
    }
    if (req.body?.source !== 'web') {
      return res.status(403).json({ error: 'Accès réservé au personnel' });
    }
  }

  if (!isPublicRegistration && !isEmployeeSession) {
    return res.status(403).json({ error: 'Accès réservé au personnel' });
  }
  const state = readState();
  const list = state[collection];
  const existingIndex = list.findIndex((item) => String(item.id) === id);
  if (isPublicRegistration && existingIndex >= 0) {
    return res.status(409).json({ error: 'Une inscription publique ne peut pas être modifiée.' });
  }
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
  if (collection === 'users') {
    if (data.password) {
      data.passwordHash = hashPassword(String(data.password));
      delete data.password;
    }
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
}

app.put('/api/:collection/:id', handleCollectionPut);
app.post('/api/:collection/:id', handleCollectionPut);
app.post('/api/:collection', (req, res) => {
  req.params.id = req.body?.id || `${req.params.collection}_${Date.now()}`;
  return handleCollectionPut(req, res);
});

// Routes admin avec rate-limiting
app.put('/api/admin/:collection/:id', requireAdministrator, requireAdminRateLimit, handleCollectionPut);
app.post('/api/admin/:collection/:id', requireAdministrator, requireAdminRateLimit, handleCollectionPut);
app.post('/api/admin/:collection', requireAdministrator, requireAdminRateLimit, (req, res) => {
  req.params.id = req.body?.id || `${req.params.collection}_${Date.now()}`;
  return handleCollectionPut(req, res);
});

app.delete('/api/audit_logs/clear', requireAdministrator, (req, res) => {
  const state = readState();
  state.audit_logs = [];
  writeState(state);
  res.status(200).json({ success: true, message: 'Logs vidés avec succès.' });
});

app.delete('/api/:collection/:id', requireEmployee, (req, res) => {
  const { collection, id } = req.params;
  if (collection === 'audit_logs' && id === 'clear') {
    const state = readState();
    state.audit_logs = [];
    writeState(state);
    return res.status(200).json({ success: true });
  }
  if (!isCollection(collection)) return res.status(404).json({ error: 'Collection inconnue' });
  const state = readState();
  const session = req.session;
  if (collection === 'users' && !isAdministrator(session)) {
    return res.status(403).json({ error: "La gestion des comptes est réservée à l'administration." });
  }
  if (!canWriteCollection(session, collection)) {
    return res.status(403).json({ error: 'Vous ne disposez pas des droits nécessaires pour cette action.' });
  }
  state[collection] = state[collection].filter((item) => String(item.id) !== id);
  if (collection === 'users') {
    state.inscriptions = (state.inscriptions || []).filter((ins) => String(ins.etudiantId) !== id && String(ins.id) !== id);
  }
  // Enregistrer le tombstone de suppression pour éviter la réapparition lors du pull Supabase
  if (_deletedDocIds[collection]) {
    _deletedDocIds[collection].add(id);
  }
  enqueueSyncDocument(collection, { id }, true);
  writeState(state);
  res.status(204).end();
});

const port = Number(process.env.PORT || 5001);
app.listen(port, () => {
  console.log(`API Malintic opérationnelle sur le port ${port}`);

  // 1. Instantané PRA au démarrage si aucun n'existe
  try {
    const snaps = listPraSnapshots();
    if (snaps.length === 0) {
      createPraSnapshot('initial_boot', 'premier démarrage');
    }
  } catch (_) {}

  // 2. Cron PRA: Instantané automatique de sauvegarde toutes les 6 heures
  setInterval(() => {
    try {
      createPraSnapshot('auto_6h', 'sauvegarde tournante planifiée (PRA)');
    } catch (_) {}
  }, 6 * 60 * 60 * 1000);

  if (!SUPABASE_URL || !SUPABASE_KEY) {
    console.warn('[Supabase] synchronisation désactivée: SUPABASE_URL et une clé backend sont requises');
    return;
  }

  // 3. Réconciliation initiale et worker périodique (toutes les 10s)
  const localState = readState();
  enqueueSyncState(localState);
  setTimeout(() => reconcileTwoWay('startup'), 2_000);
  setInterval(() => reconcileTwoWay('periodic_worker'), 10_000);
});
