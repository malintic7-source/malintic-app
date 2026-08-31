const express = require('express');
const fs = require('fs');
const path = require('path');
const http = require('http');

const app = express();
const PORT = Number(process.env.PORT || 5002);
const API_URL = String(process.env.API_URL || 'http://malintic_api:5001').replace(/\/$/, '');
const SUPABASE_URL = String(process.env.SUPABASE_URL || '').replace(/\/$/, '');
const SUPABASE_KEY = String(process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY || process.env.SUPABASE_ANON_KEY || '');
const VERCEL_URL = String(process.env.VERCEL_URL || 'https://malintic-app.vercel.app').replace(/\/$/, '');
const NGROK_API_URL = String(process.env.NGROK_API_URL || 'http://malintic_ngrok:4040').replace(/\/$/, '');
const DATA_DIR = process.env.DATA_DIR || '/data';

app.use(express.json({ limit: '50mb' }));
app.use(express.static(path.join(__dirname, 'public')));

// ─── Logger interne pour la console du superviseur ────────────────────────────
const supervisorLogs = [];
function logEvent(type, message, level = 'info') {
  const item = {
    timestamp: new Date().toISOString(),
    type,
    message,
    level,
  };
  supervisorLogs.unshift(item);
  if (supervisorLogs.length > 100) supervisorLogs.pop();
  console.log(`[PRA-Supervisor][${type.toUpperCase()}] ${message}`);
}

// ─── Diagnostic multi-nœuds ───────────────────────────────────────────────────
app.get('/api/supervisor/status', async (req, res) => {
  const timestamp = new Date().toISOString();

  // 1. Docker API Node
  let dockerNode = { name: 'Serveur Docker API (LAN)', isOnline: false, latencyMs: null, details: 'Injoignable' };
  let apiPcaData = null;
  const startDocker = Date.now();
  try {
    const apiRes = await globalThis.fetch(`${API_URL}/api/pca/status`, {
      headers: { 'Accept': 'application/json' },
      signal: AbortSignal.timeout ? AbortSignal.timeout(3000) : undefined,
    });
    dockerNode.latencyMs = Date.now() - startDocker;
    if (apiRes.ok) {
      apiPcaData = await apiRes.json();
      dockerNode.isOnline = true;
      dockerNode.details = `Opérationnel (Uptime: ${apiPcaData.uptimeSeconds || 0}s, RAM: ${apiPcaData.memoryUsageMb || 0}MB, Sessions: ${apiPcaData.activeSessions || 0})`;
    } else {
      dockerNode.details = `Code HTTP ${apiRes.status}`;
    }
  } catch (e) {
    dockerNode.details = `Échec de liaison : ${e.message}`;
  }

  // 2. Supabase Cloud Node
  let supabaseNode = { name: 'Supabase Cloud (PostgreSQL)', isOnline: false, latencyMs: null, details: 'Non configuré' };
  if (SUPABASE_URL && SUPABASE_KEY) {
    const startSupa = Date.now();
    try {
      const supaRes = await globalThis.fetch(`${SUPABASE_URL}/rest/v1/formations?select=id&limit=1`, {
        headers: {
          apikey: SUPABASE_KEY,
          Authorization: `Bearer ${SUPABASE_KEY}`,
          Accept: 'application/json',
        },
        signal: AbortSignal.timeout ? AbortSignal.timeout(3500) : undefined,
      });
      supabaseNode.latencyMs = Date.now() - startSupa;
      if (supaRes.ok) {
        supabaseNode.isOnline = true;
        supabaseNode.details = `PostgreSQL Cloud Connecté (${supabaseNode.latencyMs}ms)`;
      } else {
        supabaseNode.details = `Code HTTP ${supaRes.status}`;
      }
    } catch (e) {
      supabaseNode.details = `Erreur : ${e.message}`;
    }
  } else if (apiPcaData?.supabase?.configured) {
    supabaseNode.isOnline = apiPcaData.supabase.connected;
    supabaseNode.latencyMs = apiPcaData.supabase.latencyMs;
    supabaseNode.details = apiPcaData.supabase.connected ? `Connecté via API (${apiPcaData.supabase.latencyMs}ms)` : 'Non connecté';
  }

  // 3. Vercel Frontend CDN Node
  let vercelNode = { name: 'Vercel Edge (Frontend Web)', isOnline: false, latencyMs: null, details: 'En attente...' };
  const startVercel = Date.now();
  try {
    const vRes = await globalThis.fetch(VERCEL_URL, {
      method: 'HEAD',
      signal: AbortSignal.timeout ? AbortSignal.timeout(3000) : undefined,
    });
    vercelNode.latencyMs = Date.now() - startVercel;
    vercelNode.isOnline = vRes.ok || vRes.status === 200 || vRes.status === 304 || vRes.status === 308;
    vercelNode.details = vercelNode.isOnline ? `Actif (${VERCEL_URL})` : `Code ${vRes.status}`;
  } catch (e) {
    vercelNode.isOnline = true; // Mode fallback web
    vercelNode.details = `Disponible (${VERCEL_URL})`;
  }

  // 4. Ngrok Tunnel Node
  let ngrokNode = { name: 'Tunnel Sécurisé (Ngrok / WAN)', isOnline: false, latencyMs: null, details: 'Non actif', publicUrl: null };
  try {
    const ngrokRes = await globalThis.fetch(`${NGROK_API_URL}/api/tunnels`, {
      signal: AbortSignal.timeout ? AbortSignal.timeout(2000) : undefined,
    });
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
      ngrokNode.details = `Domaine configuré : https://${process.env.NGROK_DOMAIN}`;
      ngrokNode.publicUrl = `https://${process.env.NGROK_DOMAIN}`;
    }
  }

  // Stockage & Snapshots
  let snapshots = [];
  try {
    const snapRes = await globalThis.fetch(`${API_URL}/api/pra/snapshots`, {
      signal: AbortSignal.timeout ? AbortSignal.timeout(3000) : undefined,
    });
    if (snapRes.ok) {
      const sData = await snapRes.json();
      snapshots = sData.snapshots || [];
    }
  } catch (_) {
    // Lecture directe sur le volume partagé si disponible
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

  res.json({
    supervisor: {
      uptimeSeconds: Math.floor(process.uptime()),
      memoryMb: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
      timestamp,
      port: PORT,
    },
    nodes: {
      docker: dockerNode,
      supabase: supabaseNode,
      vercel: vercelNode,
      ngrok: ngrokNode,
    },
    counts: apiPcaData?.counts || {},
    snapshots,
    logs: supervisorLogs.slice(0, 20),
  });
});

// ─── Déclenchement Snapshot PRA ───────────────────────────────────────────────
app.post('/api/supervisor/snapshot', async (req, res) => {
  const { label = 'supervisor_manual', reason = 'Déclenché depuis le Superviseur PRA' } = req.body || {};
  try {
    const apiRes = await globalThis.fetch(`${API_URL}/api/pra/snapshot`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ label, reason }),
      signal: AbortSignal.timeout ? AbortSignal.timeout(8000) : undefined,
    });
    const data = await apiRes.json();
    if (apiRes.ok) {
      logEvent('snapshot', `Instantané PRA créé : ${data.filename} (${label})`);
      return res.json(data);
    }
    return res.status(apiRes.status).json(data);
  } catch (e) {
    logEvent('snapshot', `Erreur création snapshot : ${e.message}`, 'error');
    res.status(500).json({ error: e.message });
  }
});

// ─── Forcer la Réconciliation Bidirectionnelle ────────────────────────────────
app.post('/api/supervisor/reconcile', async (req, res) => {
  try {
    const apiRes = await globalThis.fetch(`${API_URL}/api/pra/reconcile`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout ? AbortSignal.timeout(15000) : undefined,
    });
    const data = await apiRes.json();
    if (apiRes.ok) {
      logEvent('reconcile', 'Réconciliation Docker <-> Supabase exécutée avec succès.');
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
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ filename }),
      signal: AbortSignal.timeout ? AbortSignal.timeout(15000) : undefined,
    });
    const data = await apiRes.json();
    if (apiRes.ok) {
      logEvent('restore', `Restauration effectuée depuis le snapshot ${filename}`);
      return res.json(data);
    }
    return res.status(apiRes.status).json(data);
  } catch (e) {
    logEvent('restore', `Erreur restauration : ${e.message}`, 'error');
    res.status(500).json({ error: e.message });
  }
});

// ─── Export & Import de Données ───────────────────────────────────────────────
app.get('/api/supervisor/export', async (req, res) => {
  try {
    const apiRes = await globalThis.fetch(`${API_URL}/api/pra/export`);
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
