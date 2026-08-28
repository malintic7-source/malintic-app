const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const zlib = require('zlib');

const app = express();
app.disable('x-powered-by');

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

app.use(express.json({ limit: '15mb' }));
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, ngrok-skip-browser-warning');
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
      } catch (_) { }
    }
    throw new Error(`Base locale illisible : ${error.message}`);
  }
}

// ─── Synchronisation Supabase ─────────────────────────────────────────────────
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://mzixlwnrsqoxolzafmjb.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_KEY || 'sb_publishable_X9Srmcc9dIppUO8Hl0EDAw_C-giTCqt';
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

function _mapUser(u) {
  return {
    id: u.id,
    email: u.email || '',
    nom: u.nom || '',
    prenom: u.prenom || '',
    phone: u.phone || '',
    matricule: u.matricule || null,
    role: _cleanRole(u.role),
    photo_url: u.photoUrl || u.photo_url || null,
    specialite: u.specialite || null,
    sexe: u.sexe || 'Homme',
    est_actif: u.estActif !== false,
    assigned_formations: u.assignedFormations || u.assigned_formations || [],
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
      return; // ne pas retenter si erreur schema (4xx)
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
    const tableMap = {
      formations: { rows: state.formations || [], mapper: _mapFormation },
      users: { rows: state.users || [], mapper: _mapUser },
      inscriptions: { rows: state.inscriptions || [], mapper: _mapInscription },
      payments: { rows: state.payments || [], mapper: _mapPayment },
    };
    for (const [table, { rows, mapper }] of Object.entries(tableMap)) {
      for (const row of rows) {
        await _supabaseUpsert(table, mapper(row));
      }
    }
  });
  setImmediate(_drainSyncQueue);
}

function enqueueSyncDocument(collection, doc, deleted = false) {
  const mappers = { formations: _mapFormation, users: _mapUser, inscriptions: _mapInscription, payments: _mapPayment };
  const mapper = mappers[collection];
  if (!mapper) return;
  _syncQueue.push(async () => {
    if (deleted) await _supabaseDelete(collection, doc.id);
    else await _supabaseUpsert(collection, mapper(doc));
  });
  setImmediate(_drainSyncQueue);
}

// ─── Snapshot des IDs précédents pour sync différentielle ────────────────────
const _prevIds = { formations: new Set(), users: new Set(), inscriptions: new Set(), payments: new Set() };
const _syncTables = ['formations', 'users', 'inscriptions', 'payments'];
let _lastSyncHash = '';
let _lastSyncTime = 0;
const SYNC_THROTTLE_MS = 30_000; // sync Supabase max toutes les 30 secondes

function _stateHash(state) {
  // Hash léger basé sur les IDs + versions des documents
  const parts = _syncTables.map(t =>
    (state[t] || []).map(r => `${r.id}:${r.dateModification || r.dateCreation || ''}`).join(',')
  );
  return parts.join('|');
}

function writeState(state) {
  const temporary = `${dataFile}.tmp`;
  fs.writeFileSync(temporary, JSON.stringify(state, null, 2));
  if (fs.existsSync(dataFile)) fs.copyFileSync(dataFile, backupFile);
  fs.renameSync(temporary, dataFile);
  _stateCache = state;
  _stateCacheDirty = false;
  _stateVersion = Date.now().toString();

  // Sync différentielle vers Supabase avec throttle (ne bloque pas la réponse HTTP)
  const now = Date.now();
  const hash = _stateHash(state);
  const hasChanged = hash !== _lastSyncHash;
  const canSync = (now - _lastSyncTime) >= SYNC_THROTTLE_MS;

  if (!hasChanged) return; // Rien n'a changé, pas besoin de sync
  if (!canSync && _lastSyncTime > 0) return; // Throttle actif

  _lastSyncHash = hash;
  _lastSyncTime = now;

  const mappers = { formations: _mapFormation, users: _mapUser, inscriptions: _mapInscription, payments: _mapPayment };
  const snap = {};
  for (const t of _syncTables) snap[t] = new Set((state[t] || []).map(r => r.id));

  _syncQueue.push(async () => {
    for (const t of _syncTables) {
      const mapper = mappers[t];
      const rows = state[t] || [];
      // 1. Upsert tous les documents actuels
      for (const row of rows) await _supabaseUpsert(t, mapper(row));
      // 2. Supprimer dans Supabase les IDs qui n'existent plus dans Docker
      for (const oldId of _prevIds[t]) {
        if (!snap[t].has(oldId)) await _supabaseDelete(t, oldId);
      }
      // 3. Mettre à jour le snapshot des IDs connus
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
  saveSessions();
  // Cookie de session sans Max-Age (automatiquement détruit à la fermeture du navigateur)
  res.setHeader('Set-Cookie', `malintic_session=${token}; Path=/; HttpOnly; SameSite=Lax`);
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
    const matches = verifyPassword(currentPassword, user.passwordHash) || legacyPasswordMatches(currentPassword, user.password);
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

app.post('/api/admin/users/:id/password', (req, res) => {
  const session = sessionFromRequest(req);
  const adminId = req.headers['x-admin-id'] || req.body?.adminId;
  const state = readState();
  const isAdminRequest = isAdministrator(session) ||
      (adminId && state.users.some(u => String(u.id) === String(adminId) && ['admin', 'dg', 'it'].includes(String(u.role || '').toLowerCase().replace('userrole.', ''))));

  if (!isAdminRequest && session) {
    return res.status(403).json({ error: "Accès réservé à l'administration" });
  }

  const { newPassword, mustChangePassword = true } = req.body || {};
  const password = String(newPassword || '').trim();
  if (!password || password.length < 6) {
    return res.status(400).json({ error: 'Le mot de passe doit contenir au moins 6 caractères.' });
  }

  const user = state.users.find((item) => String(item.id) === String(req.params.id));
  if (!user) return res.status(404).json({ error: 'Utilisateur introuvable.' });

  user.passwordHash = hashPassword(password);
  delete user.password;
  user.doitChangerMotDePasse = Boolean(mustChangePassword);
  user.dateModification = new Date().toISOString();

  // Log in audit trail
  const adminUser = state.users.find((u) => u.id === (session?.userId || adminId));
  const adminNom = adminUser ? `${adminUser.prenom} ${adminUser.nom}`.trim() : 'Administration';
  const targetNom = `${user.prenom} ${user.nom}`.trim();

  recordAuditLog(state, {
    userNom: adminNom,
    userRole: session?.role || 'admin',
    action: 'Réinitialisation mot de passe admin',
    description: `Mot de passe de ${targetNom} (${user.email}) modifié par ${adminNom} (Forcer changement 1ère connexion: ${mustChangePassword ? 'Oui' : 'Non'})`,
    targetId: user.id,
    targetType: 'user',
    userId: session?.userId || adminId,
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

app.put('/api/:collection/:id', (req, res) => {
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

app.delete('/api/audit_logs/clear', (req, res) => {
  const state = readState();
  state.audit_logs = [];
  writeState(state);
  res.status(200).json({ success: true, message: 'Logs vidés avec succès.' });
});

app.delete('/api/:collection/:id', (req, res) => {
  const { collection, id } = req.params;
  if (collection === 'audit_logs' && id === 'clear') {
    const state = readState();
    state.audit_logs = [];
    writeState(state);
    return res.status(200).json({ success: true });
  }
  if (!isCollection(collection)) return res.status(404).json({ error: 'Collection inconnue' });
  const state = readState();
  const session = sessionFromRequest(req);
  const callerId = req.headers['x-admin-id'] || req.headers['x-user-id'];
  const callerUser = callerId ? state.users.find(u => String(u.id) === String(callerId)) : null;
  const effectiveRole = session ? roleOf(session) : (callerUser ? roleOf({ role: callerUser.role }) : 'admin');

  if (session && !isEmployee(session) && !callerUser) {
    return res.status(403).json({ error: 'Accès réservé au personnel' });
  }
  state[collection] = state[collection].filter((item) => String(item.id) !== id);
  if (collection === 'users') {
    state.inscriptions = (state.inscriptions || []).filter((ins) => String(ins.etudiantId) !== id && String(ins.id) !== id);
  }
  writeState(state);
  res.status(204).end();
});

app.listen(5001, () => console.log('API Malintic disponible sur le port 5001'));
