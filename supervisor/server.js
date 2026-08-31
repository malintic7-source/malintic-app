const express = require('express');
const fs = require('fs');
const path = require('path');
const os = require('os');

const app = express();
const PORT = Number(process.env.PORT || 5002);
const API_URL = String(process.env.API_URL || 'http://malintic_api:5001').replace(/\/$/, '');
const APP_URL = String(process.env.APP_URL || 'http://malintic_app:80').replace(/\/$/, '');
const NGROK_API_URL = String(process.env.NGROK_API_URL || 'http://malintic_ngrok:4040').replace(/\/$/, '');
const DATA_DIR = process.env.DATA_DIR || '/data';

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(express.static(path.join(__dirname, 'public')));

// ─── Logger interne pour la console du superviseur ────────────────────────────
const supervisorLogs = [];
function logEvent(type, message, level = 'info') {
  const item = {
    timestamp: new Date().toISOString(),
    type: String(type || 'info').toUpperCase(),
    message: String(message || ''),
    level,
  };
  supervisorLogs.unshift(item);
  if (supervisorLogs.length > 150) supervisorLogs.pop();
  console.log(`[PRA-Supervisor][${item.type}] ${item.message}`);
}

// ─── Cache Asynchrone de Télémétrie des Nœuds ──────────────────────────────────
let _cachedStatus = {
  lastChecked: null,
  nodes: {
    docker_app: { name: 'Serveur Web Docker (LAN)', isOnline: true, latencyMs: 2, details: 'Initialisation...' },
    docker_api: { name: 'Serveur API Docker (LAN)', isOnline: true, latencyMs: 2, details: 'Initialisation...' },
    ngrok: { name: 'Tunnel Sécurisé (Ngrok / WAN)', isOnline: true, latencyMs: 10, details: 'Initialisation...' },
    database: { name: 'Base & Volume PRA (Local)', isOnline: true, latencyMs: 1, details: 'Initialisation...' },
  },
  counts: { users: 0, formations: 0, inscriptions: 0, payments: 0, seances: 0, notifications: 0, audit_logs: 0 },
  snapshots: [],
};

async function refreshTopologyStatus() {
  const startAll = Date.now();

  // 1. Docker Web App (Frontend Nginx)
  let appNode = { name: 'Serveur Web Docker (LAN)', isOnline: false, latencyMs: null, details: 'Injoignable' };
  const startApp = Date.now();
  try {
    const appRes = await globalThis.fetch(`${APP_URL}/`, {
      headers: { 'User-Agent': 'Malintic-Supervisor' },
      signal: AbortSignal.timeout ? AbortSignal.timeout(3000) : undefined,
    });
    appNode.latencyMs = Date.now() - startApp;
    if (appRes.ok || appRes.status === 304) {
      appNode.isOnline = true;
      appNode.details = `Nginx Web Opérationnel (Port 80 / 8000)`;
    } else {
      appNode.details = `Code HTTP ${appRes.status}`;
    }
  } catch (e) {
    appNode.details = `Échec de liaison Web : ${e.message}`;
  }

  // 2. Docker API Node
  let dockerNode = { name: 'Serveur API Docker (LAN)', isOnline: false, latencyMs: null, details: 'Injoignable' };
  let apiPcaData = null;
  const startDocker = Date.now();
  try {
    const apiRes = await globalThis.fetch(`${API_URL}/api/pca/status`, {
      headers: { 'Accept': 'application/json', 'x-supervisor-auth': 'true' },
      signal: AbortSignal.timeout ? AbortSignal.timeout(4000) : undefined,
    });
    dockerNode.latencyMs = Date.now() - startDocker;
    if (apiRes.ok) {
      apiPcaData = await apiRes.json();
      dockerNode.isOnline = true;
      dockerNode.details = `API Opérationnelle (Uptime: ${apiPcaData.uptimeSeconds || 0}s, RAM: ${apiPcaData.memoryUsageMb || 0}MB, Sessions: ${apiPcaData.activeSessions || 0})`;
    } else {
      dockerNode.details = `Code HTTP ${apiRes.status}`;
    }
  } catch (e) {
    dockerNode.details = `Échec de liaison API : ${e.message}`;
  }

  // 3. Ngrok Tunnel Node (WAN)
  let ngrokNode = { name: 'Tunnel Sécurisé (Ngrok / WAN)', isOnline: false, latencyMs: null, details: 'Non actif', publicUrl: null };
  const startNgrok = Date.now();
  try {
    const ngrokRes = await globalThis.fetch(`${NGROK_API_URL}/api/tunnels`, {
      signal: AbortSignal.timeout ? AbortSignal.timeout(2500) : undefined,
    });
    ngrokNode.latencyMs = Date.now() - startNgrok;
    if (ngrokRes.ok) {
      const data = await ngrokRes.json();
      const tunnel = (data.tunnels || [])[0];
      if (tunnel) {
        ngrokNode.isOnline = true;
        ngrokNode.publicUrl = tunnel.public_url;
        ngrokNode.details = `Tunnel actif : ${tunnel.public_url}`;
      } else {
        ngrokNode.details = 'Tunnel en attente de connexion';
      }
    }
  } catch (_) {
    if (process.env.NGROK_DOMAIN) {
      ngrokNode.isOnline = true;
      ngrokNode.details = `Domaine configuré : https://${process.env.NGROK_DOMAIN}`;
      ngrokNode.publicUrl = `https://${process.env.NGROK_DOMAIN}`;
    }
  }

  // 4. Local Database & Volume PRA Node
  let dbNode = { name: 'Base & Volume PRA (Local)', isOnline: false, latencyMs: 1, details: 'Vérification...' };
  try {
    const dbPath = path.join(DATA_DIR, 'database.json');
    if (fs.existsSync(dbPath)) {
      const stats = fs.statSync(dbPath);
      const sizeKb = (stats.size / 1024).toFixed(1);
      dbNode.isOnline = true;
      dbNode.details = `Volume actif (/data/database.json : ${sizeKb} KB)`;
    } else {
      dbNode.isOnline = true;
      dbNode.details = `Base en mémoire prête pour persistance`;
    }
  } catch (e) {
    dbNode.details = `Erreur accès volume : ${e.message}`;
  }

  // Snapshots
  let snapshots = [];
  try {
    const snapRes = await globalThis.fetch(`${API_URL}/api/pra/snapshots`, {
      headers: { 'Accept': 'application/json', 'x-supervisor-auth': 'true' },
      signal: AbortSignal.timeout ? AbortSignal.timeout(3000) : undefined,
    });
    if (snapRes.ok) {
      const sData = await snapRes.json();
      snapshots = sData.snapshots || [];
    }
  } catch (_) {
    try {
      const praDir = path.join(DATA_DIR, 'backups');
      if (fs.existsSync(praDir)) {
        const files = fs.readdirSync(praDir).filter(f => f.startsWith('pra_snapshot_') && f.endsWith('.json'));
        snapshots = files.map(f => {
          const full = path.join(praDir, f);
          const stats = fs.statSync(full);
          let meta = { label: 'auto', reason: '', counts: {} };
          try {
            const content = JSON.parse(fs.readFileSync(full, 'utf8'));
            if (content.metadata) meta = content.metadata;
          } catch (_) {}
          return {
            filename: f,
            sizeBytes: stats.size,
            createdAt: meta.createdAt || stats.mtime.toISOString(),
            label: meta.label || 'auto',
            reason: meta.reason || '',
            counts: meta.counts || {},
          };
        }).sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
      }
    } catch (_) {}
  }

  _cachedStatus = {
    lastChecked: new Date().toISOString(),
    durationMs: Date.now() - startAll,
    nodes: { docker_app: appNode, docker_api: dockerNode, ngrok: ngrokNode, database: dbNode },
    counts: apiPcaData?.counts || _cachedStatus.counts,
    snapshots,
  };
}

// Rafraîchissement périodique en tâche de fond toutes les 6 secondes
refreshTopologyStatus();
setInterval(refreshTopologyStatus, 6000);

// ─── Endpoints Superviseur ───────────────────────────────────────────────────
app.get('/api/supervisor/status', async (req, res) => {
  const force = req.query.force === 'true';
  if (force || !_cachedStatus.lastChecked) {
    await refreshTopologyStatus();
  }
  const sysMem = Math.round((os.totalmem() - os.freemem()) / 1024 / 1024);
  res.json({
    supervisor: {
      uptimeSeconds: Math.floor(process.uptime()),
      memoryMb: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
      systemMemoryMb: sysMem,
      timestamp: new Date().toISOString(),
      lastChecked: _cachedStatus.lastChecked,
      port: PORT,
    },
    nodes: _cachedStatus.nodes,
    counts: _cachedStatus.counts,
    snapshots: _cachedStatus.snapshots,
    logs: supervisorLogs.slice(0, 30),
  });
});

// ─── Déclenchement Snapshot PRA ───────────────────────────────────────────────
app.post('/api/supervisor/snapshot', async (req, res) => {
  const { label = 'supervisor_manual', reason = 'Déclenché depuis le Superviseur PRA' } = req.body || {};
  try {
    const apiRes = await globalThis.fetch(`${API_URL}/api/pra/snapshot`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-supervisor-auth': 'true' },
      body: JSON.stringify({ label, reason }),
      signal: AbortSignal.timeout ? AbortSignal.timeout(10000) : undefined,
    });
    const data = await apiRes.json();
    if (apiRes.ok) {
      logEvent('snapshot', `Instantané PRA créé : ${data.filename} (${label})`);
      await refreshTopologyStatus();
      return res.json(data);
    }
    return res.status(apiRes.status).json(data);
  } catch (e) {
    logEvent('snapshot', `Erreur création snapshot : ${e.message}`, 'error');
    res.status(500).json({ error: e.message });
  }
});

// ─── Téléchargement d'un Snapshot Spécifique ─────────────────────────────────
app.get('/api/supervisor/snapshot/download', (req, res) => {
  const filename = path.basename(String(req.query.filename || ''));
  if (!filename || !filename.endsWith('.json')) {
    return res.status(400).send('Nom de fichier invalide');
  }
  const praDir = path.join(DATA_DIR, 'backups');
  const filePath = path.join(praDir, filename);
  if (!fs.existsSync(filePath)) {
    return res.status(404).send('Fichier snapshot introuvable');
  }
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  res.setHeader('Content-Type', 'application/json');
  fs.createReadStream(filePath).pipe(res);
});

// ─── Forcer la Réconciliation Bidirectionnelle ────────────────────────────────
app.post(['/api/supervisor/reconcile', '/api/supervisor/sync'], async (req, res) => {
  try {
    const apiRes = await globalThis.fetch(`${API_URL}/api/pra/reconcile`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-supervisor-auth': 'true' },
      signal: AbortSignal.timeout ? AbortSignal.timeout(20000) : undefined,
    });
    const data = await apiRes.json();
    if (apiRes.ok) {
      logEvent('reconcile', 'Réconciliation Docker <-> Supabase exécutée avec succès.');
      await refreshTopologyStatus();
      return res.json(data);
    }
    return res.status(apiRes.status).json(data);
  } catch (e) {
    logEvent('reconcile', `Erreur réconciliation : ${e.message}`, 'error');
    res.status(500).json({ error: e.message });
  }
});

// ─── Restaurer un Point PRA ───────────────────────────────────────────────────
app.post('/api/supervisor/restore', async (req, res) => {
  const { filename } = req.body || {};
  if (!filename) return res.status(400).json({ error: 'Nom du fichier requis' });
  try {
    const apiRes = await globalThis.fetch(`${API_URL}/api/pra/restore`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-supervisor-auth': 'true' },
      body: JSON.stringify({ filename }),
      signal: AbortSignal.timeout ? AbortSignal.timeout(20000) : undefined,
    });
    const data = await apiRes.json();
    if (apiRes.ok) {
      logEvent('restore', `Restauration effectuée depuis le snapshot ${filename}`);
      await refreshTopologyStatus();
      return res.json(data);
    }
    return res.status(apiRes.status).json(data);
  } catch (e) {
    logEvent('restore', `Erreur restauration : ${e.message}`, 'error');
    res.status(500).json({ error: e.message });
  }
});

// ─── Export Archive Complète ─────────────────────────────────────────────────
app.get('/api/supervisor/export', async (req, res) => {
  try {
    const apiRes = await globalThis.fetch(`${API_URL}/api/pra/export`, {
      headers: { 'x-supervisor-auth': 'true' },
    });
    if (apiRes.ok) {
      const text = await apiRes.text();
      res.setHeader('Content-Disposition', `attachment; filename="malintic_supervisor_export_${Date.now()}.json"`);
      res.setHeader('Content-Type', 'application/json');
      return res.send(text);
    }
    res.status(apiRes.status).send('Échec export');
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  logEvent('startup', `Serveur PRA/PCA Superviseur opérationnel sur http://0.0.0.0:${PORT}`);
});
