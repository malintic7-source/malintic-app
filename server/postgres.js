const { Pool } = require('pg');

const DATABASE_URL = String(process.env.DATABASE_URL || '').trim();
const isDatabaseEnabled = () => Boolean(DATABASE_URL);

let pool = null;
let schemaReady = null;
let pendingState = null;
let stateWriteInProgress = false;
let stateWritePromise = null;

if (isDatabaseEnabled()) {
  try {
    pool = new Pool({
      connectionString: DATABASE_URL,
      max: 10,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 5_000,
      ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : undefined,
    });

    pool.on('error', (error) => {
      console.error('[PostgreSQL] erreur du pool:', error.message);
    });
  } catch (error) {
    console.error('[PostgreSQL] impossible d_initialiser le pool:', error.message);
    pool = null;
  }
}

async function ensureSchema() {
  if (!pool) return false;
  if (!schemaReady) {
    schemaReady = pool.query(`
      CREATE TABLE IF NOT EXISTS app_state (
        id SERIAL PRIMARY KEY,
        data JSONB NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);
  }
  await schemaReady;
  return true;
}

async function loadStateFromDatabase(fallbackState) {
  if (!pool) return fallbackState;

  try {
    await ensureSchema();
    const result = await pool.query(
      'SELECT data FROM app_state ORDER BY updated_at DESC, id DESC LIMIT 1'
    );

    if (result.rowCount > 0 && result.rows[0] && result.rows[0].data && typeof result.rows[0].data === 'object') {
      return result.rows[0].data;
    }

    if (fallbackState) {
      await saveStateToDatabase(fallbackState);
    }

    return fallbackState;
  } catch (error) {
    console.error('[PostgreSQL] lecture impossible:', error.message);
    return fallbackState;
  }
}

async function saveStateToDatabase(state) {
  if (!pool || !state || typeof state !== 'object') return false;
  pendingState = state;
  if (stateWriteInProgress) return stateWritePromise ?? true;

  stateWriteInProgress = true;
  stateWritePromise = (async () => {
    let success = true;
    try {
      await ensureSchema();
      while (pendingState) {
        const nextState = pendingState;
        pendingState = null;
        await pool.query(
          `INSERT INTO app_state (id, data, updated_at)
           VALUES (1, $1, NOW())
           ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, updated_at = NOW()`,
          [nextState]
        );
      }
    } catch (error) {
      success = false;
      console.error('[PostgreSQL] sauvegarde impossible:', error.message);
    } finally {
      stateWriteInProgress = false;
      stateWritePromise = null;
    }
    return success;
  })();
  return stateWritePromise;
}

async function initializeDatabaseState(initialState) {
  if (!isDatabaseEnabled()) return initialState;
  try {
    const dbState = await loadStateFromDatabase(initialState);
    if (dbState && typeof dbState === 'object') {
      return dbState;
    }
  } catch (error) {
    console.warn('[PostgreSQL] initialisation impossible, conservation du mode JSON local:', error.message);
  }
  return initialState;
}

module.exports = {
  isDatabaseEnabled,
  loadStateFromDatabase,
  saveStateToDatabase,
  initializeDatabaseState,
};
