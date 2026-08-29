# 🗄️ Migration PostgreSQL — M@LI-NTIC

> Guide complet pour passer de JSON file à PostgreSQL en production.
> **Recommandé pour** : > 100 utilisateurs simultanés, > 50K formations/inscriptions.

---

## 📊 État actuel vs PostgreSQL

| Métrique | JSON File | PostgreSQL |
|---|---|---|
| **Limite scalabilité** | ~50 users | 10K+ users |
| **Temps requête** | 100-500ms | 5-50ms |
| **Persistance** | Fichier local | Serveur dédié |
| **Backups** | Manuel (zip) | Automatique |
| **Transactions** | Aucune (risqué) | ACID complètes |
| **Concurrence** | ❌ Pas de locking | ✅ Row-level locking |
| **Coût Render** | $0 (tier gratuit) | $7-50/mois |
| **Fiabilité prod** | ⚠️ Risqué | ✅ Production-ready |

---

## 🚀 Phase 1 : Préparation (1-2 jours)

### 1.1 Créer une instance PostgreSQL

#### Option A : Render (recommandé)
```bash
# Goto: https://render.com → Dashboard → New → PostgreSQL
# Configuration:
# - Region: eu-west-1 (Irlande) ou us-east-1
# - Plan: Starter ($7/moz, 1GB, backups auto)
# - Name: malintic-db
# - Database: malintic_prod
# - Username: postgres
# - Password: (auto-generated, save it!)

# Récupérer la connection string
# Format: postgres://user:password@host:port/database
# Sauvegarder dans .env:
DATABASE_URL=postgres://user:password@xxxxx.onrender.com:5432/malintic_prod
```

#### Option B : Railway
```bash
# goto: https://railway.app → New → PostgreSQL
# Plus simple que Render, même pricing
```

#### Option C : Vercel Postgres
```bash
# goto: vercel.com → Storage → Postgres
# Intégré à Vercel, mais à $15/mois minimum
```

### 1.2 Créer le schéma (SQL)

Fichier : `server/migrations/001_init_schema.sql`

```sql
-- ═══════════════════════════════════════════════════════════════════
-- M@LI-NTIC Database Schema
-- Version: 1.0
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- 1. Users (Authentification & Rôles)
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  nom VARCHAR(100) NOT NULL,
  prenom VARCHAR(100) NOT NULL,
  role VARCHAR(50) NOT NULL,  -- admin, dg, daf, comptable, assistant, formateur, apprenant
  phone VARCHAR(20),
  matricule VARCHAR(50) UNIQUE,
  photo_url VARCHAR(500),
  sexe VARCHAR(20),
  est_actif BOOLEAN DEFAULT true,
  doit_changer_motdepasse BOOLEAN DEFAULT false,
  date_creation TIMESTAMP DEFAULT NOW(),
  date_modification TIMESTAMP DEFAULT NOW(),
  INDEX idx_email (email),
  INDEX idx_role (role),
  INDEX idx_matricule (matricule)
);

-- ─────────────────────────────────────────────────────────────────
-- 2. Formations (Catalogue de formations)
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS formations (
  id UUID PRIMARY KEY,
  titre VARCHAR(255) NOT NULL,
  description TEXT,
  type VARCHAR(50),  -- enligne, presentielle, mixte
  status VARCHAR(50),  -- programmee, enCours, terminee
  prix DECIMAL(10, 2),
  prix_enligne DECIMAL(10, 2),
  duree_semaines INT,
  duree_heures VARCHAR(50),
  date_debut DATE,
  date_fin DATE,
  capacite_max INT,
  nombre_inscrits INT DEFAULT 0,
  est_stage BOOLEAN DEFAULT false,
  max_modules_par_etudiant INT,
  date_creation TIMESTAMP DEFAULT NOW(),
  date_modification TIMESTAMP DEFAULT NOW(),
  INDEX idx_type (type),
  INDEX idx_status (status),
  INDEX idx_date_debut (date_debut)
);

-- ─────────────────────────────────────────────────────────────────
-- 3. Modules (Partie d'une formation)
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS modules (
  id UUID PRIMARY KEY,
  formation_id UUID NOT NULL REFERENCES formations(id) ON DELETE CASCADE,
  nom VARCHAR(255) NOT NULL,
  prix DECIMAL(10, 2),
  formateur_id UUID REFERENCES users(id),
  INDEX idx_formation_id (formation_id),
  INDEX idx_formateur_id (formateur_id)
);

-- ─────────────────────────────────────────────────────────────────
-- 4. Inscriptions (Candidatures & suivi)
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS inscriptions (
  id UUID PRIMARY KEY,
  apprenant_id UUID REFERENCES users(id),
  formation_id UUID NOT NULL REFERENCES formations(id),
  status VARCHAR(50),  -- enAttente, acceptee, rejetee
  date_inscription TIMESTAMP DEFAULT NOW(),
  date_acceptation TIMESTAMP,
  paiement_effectue BOOLEAN DEFAULT false,
  motif_rejet TEXT,
  source VARCHAR(50),  -- web, mobile
  INDEX idx_apprenant_id (apprenant_id),
  INDEX idx_formation_id (formation_id),
  INDEX idx_status (status)
);

-- ─────────────────────────────────────────────────────────────────
-- 5. Paiements (Encaissements & tranches)
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY,
  inscription_id UUID NOT NULL REFERENCES inscriptions(id),
  montant_total DECIMAL(10, 2),
  montant_paye DECIMAL(10, 2),
  moyen_paiement VARCHAR(50),  -- Espèces, Chèque, Virement
  remise DECIMAL(10, 2),
  recu_genere_pdf VARCHAR(500),
  date_creation TIMESTAMP DEFAULT NOW(),
  date_effectuation TIMESTAMP,
  INDEX idx_inscription_id (inscription_id),
  INDEX idx_date_effectuation (date_effectuation)
);

-- Tranches de paiement (sous-table)
CREATE TABLE IF NOT EXISTS payment_tranches (
  id UUID PRIMARY KEY,
  payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  numero INT,
  montant DECIMAL(10, 2),
  date_limite DATE,
  date_encaissement DATE,
  justificatif VARCHAR(500),
  INDEX idx_payment_id (payment_id)
);

-- ─────────────────────────────────────────────────────────────────
-- 6. Séances (Planning des cours)
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS seances (
  id UUID PRIMARY KEY,
  formation_id UUID NOT NULL REFERENCES formations(id),
  module_id UUID REFERENCES modules(id),
  date_debut TIMESTAMP NOT NULL,
  date_fin TIMESTAMP NOT NULL,
  lieu_ou_lien VARCHAR(500),  -- "Salle 101" ou "https://meet.google.com/..."
  formateur_id UUID REFERENCES users(id),
  status VARCHAR(50),  -- programmee, validee, terminee
  INDEX idx_formation_id (formation_id),
  INDEX idx_date_debut (date_debut),
  INDEX idx_formateur_id (formateur_id)
);

-- Présences (sous-table)
CREATE TABLE IF NOT EXISTS seance_presences (
  id UUID PRIMARY KEY,
  seance_id UUID NOT NULL REFERENCES seances(id) ON DELETE CASCADE,
  apprenant_id UUID NOT NULL REFERENCES users(id),
  est_present BOOLEAN DEFAULT false,
  INDEX idx_seance_id (seance_id),
  INDEX idx_apprenant_id (apprenant_id)
);

-- ─────────────────────────────────────────────────────────────────
-- 7. Notifications (Alertes temps réel)
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY,
  titre VARCHAR(255),
  message TEXT,
  type VARCHAR(50),  -- info, success, warning, error
  action VARCHAR(500),  -- Lien action
  date_creation TIMESTAMP DEFAULT NOW(),
  source VARCHAR(50),  -- system, admin, formateur
  INDEX idx_date_creation (date_creation)
);

-- Destinataires de notification
CREATE TABLE IF NOT EXISTS notification_destinataires (
  id UUID PRIMARY KEY,
  notification_id UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id),
  lue BOOLEAN DEFAULT false,
  date_lecture TIMESTAMP,
  INDEX idx_notification_id (notification_id),
  INDEX idx_user_id (user_id)
);

-- ─────────────────────────────────────────────────────────────────
-- 8. Audit Logs (Traçabilité complète)
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  action VARCHAR(255) NOT NULL,  -- create_formation, accept_inscription
  collection VARCHAR(100) NOT NULL,  -- formations, inscriptions
  document_id VARCHAR(255),
  changements JSONB,  -- avant/après
  date_action TIMESTAMP DEFAULT NOW(),
  ip_address VARCHAR(45),
  INDEX idx_user_id (user_id),
  INDEX idx_action (action),
  INDEX idx_date_action (date_action)
);

-- ─────────────────────────────────────────────────────────────────
-- Indexes supplémentaires pour performances
-- ─────────────────────────────────────────────────────────────────
CREATE INDEX idx_inscriptions_formation_status 
ON inscriptions(formation_id, status);

CREATE INDEX idx_payments_date_range 
ON payments(date_creation, date_effectuation);

CREATE INDEX idx_seances_date_range 
ON seances(date_debut, date_fin);

-- Trigger: auto-update date_modification
CREATE OR REPLACE FUNCTION update_date_modification()
RETURNS TRIGGER AS $$
BEGIN
  NEW.date_modification = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_date BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_date_modification();

CREATE TRIGGER update_formations_date BEFORE UPDATE ON formations
FOR EACH ROW EXECUTE FUNCTION update_date_modification();
```

### 1.3 Exécuter le schéma

```bash
# Connexion à PostgreSQL via psql
psql $DATABASE_URL < server/migrations/001_init_schema.sql

# Vérifier les tables
psql $DATABASE_URL -c "\dt"
```

---

## 🔄 Phase 2 : Migration des données (1-2 jours)

### 2.1 Exporter données JSON

```bash
# Sauvegarder database.json (backup)
cp server/database.json server/database.json.backup

# Examiner la structure
cat server/database.json | jq '.formations | length'  # Nombre formations
```

### 2.2 Script de migration JSON → PostgreSQL

Fichier : `server/scripts/migrate_to_postgres.js`

```javascript
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');  // npm install pg

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

async function migrateData() {
  try {
    // 1. Charger données JSON
    const dbPath = path.join(__dirname, '../database.json');
    const db = JSON.parse(fs.readFileSync(dbPath, 'utf8'));
    
    console.log('📦 Données JSON chargées');
    console.log(`   - ${db.users?.length || 0} users`);
    console.log(`   - ${db.formations?.length || 0} formations`);
    console.log(`   - ${db.inscriptions?.length || 0} inscriptions`);
    
    // 2. Migrer users
    console.log('\n👤 Migration users...');
    for (const user of (db.users || [])) {
      await pool.query(
        `INSERT INTO users (id, email, nom, prenom, role, phone, matricule, date_creation)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (id) DO UPDATE SET date_modification = NOW()`,
        [user.id, user.email, user.nom, user.prenom, user.role, user.phone, user.matricule, new Date()]
      );
    }
    console.log(`✅ ${db.users?.length || 0} users migrés`);
    
    // 3. Migrer formations
    console.log('\n📚 Migration formations...');
    for (const formation of (db.formations || [])) {
      await pool.query(
        `INSERT INTO formations (id, titre, description, type, status, prix, date_debut, date_fin, date_creation)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         ON CONFLICT (id) DO UPDATE SET date_modification = NOW()`,
        [formation.id, formation.titre, formation.description, formation.type, formation.status, 
         formation.prix, formation.dateDebut, formation.dateFin, new Date()]
      );
    }
    console.log(`✅ ${db.formations?.length || 0} formations migrées`);
    
    // 4. Migrer inscriptions
    console.log('\n📝 Migration inscriptions...');
    for (const inscription of (db.inscriptions || [])) {
      await pool.query(
        `INSERT INTO inscriptions (id, apprenant_id, formation_id, status, date_inscription, paiement_effectue)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (id) DO NOTHING`,
        [inscription.id, inscription.apprenantId, inscription.formationId, inscription.status, 
         inscription.dateInscription, inscription.paiementEffectue]
      );
    }
    console.log(`✅ ${db.inscriptions?.length || 0} inscriptions migrées`);
    
    // 5. Migrer paiements
    console.log('\n💰 Migration paiements...');
    for (const payment of (db.payments || [])) {
      await pool.query(
        `INSERT INTO payments (id, inscription_id, montant_total, montant_paye, moyen_paiement, date_creation)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (id) DO NOTHING`,
        [payment.id, payment.inscriptionId, payment.montantTotal, payment.montantPaye, 
         payment.moyenPaiement, payment.dateCreation]
      );
    }
    console.log(`✅ ${db.payments?.length || 0} paiements migrés`);
    
    console.log('\n✅ Migration complète!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur migration:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

migrateData();
```

Exécuter :
```bash
npm install pg
DATABASE_URL=postgres://... node server/scripts/migrate_to_postgres.js
```

---

## 🔧 Phase 3 : Modifier l'API (1-2 jours)

### 3.1 Remplacer les opérations JSON par SQL

Avant :
```javascript
// ❌ ANCIEN: Charger/modifier le fichier entier
function getAllFormations() {
  const db = JSON.parse(fs.readFileSync(dataFile, 'utf8'));
  return db.formations || [];
}

app.get('/api/formations', (req, res) => {
  res.json(getAllFormations());  // Toutes les données chaque fois
});
```

Après :
```javascript
// ✅ NOUVEAU: Requête SQL optimisée
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

app.get('/api/formations', async (req, res) => {
  const { limit = 50, offset = 0 } = req.query;
  
  const result = await pool.query(
    'SELECT * FROM formations ORDER BY date_creation DESC LIMIT $1 OFFSET $2',
    [limit, offset]
  );
  
  res.json(result.rows);
});

app.post('/api/formations', async (req, res) => {
  const { titre, description, type, prix } = req.body;
  const id = uuidv4();
  
  await pool.query(
    `INSERT INTO formations (id, titre, description, type, prix, date_creation)
     VALUES ($1, $2, $3, $4, $5, NOW())`,
    [id, titre, description, type, prix]
  );
  
  res.status(201).json({ id });
});
```

### 3.2 Configuration `.env`

```bash
# Avant (JSON)
NODE_ENV=production
DATA_DIR=/data

# Après (PostgreSQL)
NODE_ENV=production
DATABASE_URL=postgres://user:pass@host:5432/malintic_prod
DATABASE_POOL_SIZE=20  # Nombre connexions simultanées
```

### 3.3 Tester

```bash
# Lancer avec PostgreSQL
NODE_ENV=production DATABASE_URL=... node server/server.js

# Vérifier
curl http://localhost:5001/api/formations
# Doit retourner rapidement (< 50ms)
```

---

## 📋 Checklist complète

- [ ] PostgreSQL instance créée (Render/Railway/Vercel)
- [ ] Schéma exécuté (`001_init_schema.sql`)
- [ ] Backup JSON fait (`database.json.backup`)
- [ ] Script migration testé localement
- [ ] Données migrées vers PostgreSQL
- [ ] API modifiée pour utiliser PostgreSQL
- [ ] Tests passent avec PostgreSQL
- [ ] Render backend configuré (DATABASE_URL env var)
- [ ] Production déployée
- [ ] Monitoring métriques DB activé

---

## 🚨 Rollback (si besoin)

```bash
# 1. Redéployer l'ancienne version (JSON)
git checkout HEAD~1
git push

# 2. Render redéploie auto

# 3. Restaurer données depuis backup
cp server/database.json.backup server/database.json
```

---

## 📊 Après migration : Performance

| Métrique | Avant (JSON) | Après (PostgreSQL) |
|---|---|---|
| **Temps requête** | 200-500ms | 5-50ms |
| **Capacité** | ~100 users | 10K+ users |
| **Backups** | Manuel | Automatique (Render) |
| **Coût** | $0 | $7-50/moz |

---

## 📚 Ressources

- [Render PostgreSQL Docs](https://render.com/docs/databases)
- [PostgreSQL Tutorial](https://www.postgresql.org/docs/current/tutorial.html)
- [Node.js pg client](https://node-postgres.com/)

---

Dernière mise à jour : 2026-08-29
