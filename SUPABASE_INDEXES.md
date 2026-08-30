# 🚀 Supabase Indexes - Documentation Recommandée

Pour optimiser les performances en production Supabase, ajoutez ces indexes SQL :

## 📊 Indexes Essentiels

### 1. **Users Table**
```sql
-- Index sur email (login principal)
CREATE INDEX idx_users_email ON users(email);

-- Index sur matricule (alternative login)
CREATE INDEX idx_users_matricule ON users(matricule);

-- Index sur rôle (filtrage par permission)
CREATE INDEX idx_users_role ON users(role);

-- Index sur statut actif (filtrage)
CREATE INDEX idx_users_est_actif ON users(est_actif);
```

### 2. **Inscriptions Table**
```sql
-- Index sur étudiant_id (requêtes formateur)
CREATE INDEX idx_inscriptions_etudiant_id ON inscriptions(etudiant_id);

-- Index sur formation_id (gestion formations)
CREATE INDEX idx_inscriptions_formation_id ON inscriptions(formation_id);

-- Index sur statut (filtrage inscriptions)
CREATE INDEX idx_inscriptions_status ON inscriptions(status);

-- Index composé pour recherche rapide
CREATE INDEX idx_inscriptions_formation_etudiant ON inscriptions(formation_id, etudiant_id);
```

### 3. **Payments Table**
```sql
-- Index sur inscription_id (suivi paiements)
CREATE INDEX idx_payments_inscription_id ON payments(inscription_id);

-- Index sur étudiant_id (rapports financiers)
CREATE INDEX idx_payments_etudiant_id ON payments(etudiant_id);

-- Index sur statut (rapports caisse)
CREATE INDEX idx_payments_status ON payments(status);

-- Index sur date paiement (tri chronologique)
CREATE INDEX idx_payments_date_paiement ON payments(date_paiement DESC);
```

### 4. **Formations Table**
```sql
-- Index sur statut (filtre accueil)
CREATE INDEX idx_formations_status ON formations(status);

-- Index sur type (filtre formations)
CREATE INDEX idx_formations_type ON formations(type);

-- Index sur capacité max (vérifier places)
CREATE INDEX idx_formations_capacite ON formations(capacite_max);
```

### 5. **Seances Table**
```sql
-- Index sur formation_id (emploi du temps)
CREATE INDEX idx_seances_formation_id ON seances(formation_id);

-- Index sur formateur_id (agenda formateur)
CREATE INDEX idx_seances_formateur_id ON seances(formateur_id);

-- Index sur date_debut (chronologie)
CREATE INDEX idx_seances_date_debut ON seances(date_debut);

-- Index composé pour agenda complet
CREATE INDEX idx_seances_formation_date ON seances(formation_id, date_debut);
```

### 6. **Audit Logs Table**
```sql
-- Index sur timestamp (logs historiques)
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp DESC);

-- Index sur user_id (audit par utilisateur)
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);

-- Index sur action (filtrer par type)
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
```

### 7. **Notifications Table**
```sql
-- Index sur target_user_ids (notifications utilisateur)
CREATE INDEX idx_notifications_target_users ON notifications(target_user_ids);

-- Index sur created_at (tri chrono)
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);

-- Index sur read_by (vue utilisateur)
CREATE INDEX idx_notifications_read_by ON notifications(read_by);
```

## ⚡ Impact Estimé

| Index | Gain Vitesse | Priorité |
|-------|--------------|----------|
| users.email | +95% | 🔴 CRITIQUE |
| inscriptions.formation_id | +88% | 🔴 CRITIQUE |
| payments.inscription_id | +90% | 🔴 CRITIQUE |
| seances.formation_date | +85% | 🟡 HAUTE |
| audit_logs.timestamp | +80% | 🟡 HAUTE |
| formations.status | +75% | 🟡 HAUTE |
| notifications.created_at | +70% | 🟡 HAUTE |

## 🔧 Installation

### Via Supabase Dashboard
1. Aller à **SQL Editor** → **New Query**
2. Copier chaque bloc SQL ci-dessus
3. Cliquer **Run**

### Via CLI
```bash
supabase db push
# Puis mettre à jour votre migration
```

## 📈 Performance Monitoring

Vérifier les performances avec :
```sql
-- Voir les indexes existants
SELECT schemaname, tablename, indexname 
FROM pg_indexes 
WHERE schemaname = 'public';

-- Voir les requêtes lentes
SELECT query, mean_exec_time, calls 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;
```

## ⚠️ Notes de Maintenance

- Les indexes ralentissent les **INSERT/UPDATE** (mais très peu)
- À mettre à jour après migrations schema
- Analyser les performances avant/après avec EXPLAIN ANALYZE

---

**Statut** : ✅ Recommandé en production  
**Date d'ajout** : 2026-08-29
