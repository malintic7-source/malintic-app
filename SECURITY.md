# 🔐 SECURITY — Politique de sécurité M@LI-NTIC

> **Document important** : À lire avant tout déploiement en production.
> Politique de gestion des secrets, credentials et variables sensibles.

---

## 📋 Vue d'ensemble

Ce projet gère des données sensibles :
- 👤 Identités utilisateurs (email, mot de passe)
- 💰 Informations financières (paiements, tranches)
- 📝 Données académiques (formations, inscriptions)
- 🔑 Tokens d'authentification (sessions, ngrok)

**Responsabilité** : Toutes les variables sensibles doivent être **traitées comme des secrets**.

---

## 🚫 RÈGLES ABSOLUES

### 1️⃣ JAMAIS commiter de credentials

```bash
# ❌ FAUX (FAILLE DE SÉCURITÉ)
git add .env
git commit -m "Add credentials"
git push

# ✅ BON
# .env est dans .gitignore
# Seul .env.example est commité
```

### 2️⃣ JAMAIS hardcoder de secrets en dur

```dart
// ❌ FAUX
const url = 'https://mzixlwnrsqoxolzafmjb.supabase.co';
const apiKey = 'sb_publishable_X9Srmcc9dIppUO8Hl0EDAw_C-giTCqt';

// ✅ BON
const url = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const apiKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
```

### 3️⃣ JAMAIS partager de liens ngrok publiquement

```dart
// ❌ FAUX (expose le tunnel d'admin)
final frontendUrl = 'https://boil-prude-curry.ngrok-free.dev';
QRCode.generate(frontendUrl);

// ✅ BON
// QR codes pointent TOUJOURS vers Vercel (public)
// Ngrok reste réservé aux admins
```

### 4️⃣ JAMAIS utiliser le même ngrok domain pour plusieurs environnements

```bash
# ❌ FAUX (risque de collision)
# Admin A utilise: boil-prude-curry.ngrok-free.dev
# Admin B utilise: boil-prude-curry.ngrok-free.dev ← COLLISION!

# ✅ BON (chacun son domaine personnel)
# Admin A : NGROK_DOMAIN=adam-personal.ngrok-free.dev
# Admin B : NGROK_DOMAIN=bambara-personal.ngrok-free.dev
```

---

## 🔐 Gestion des secrets par environnement

### Local (développement)

```bash
# 1. Copier template
cp .env.example .env

# 2. Remplir .env avec vraies valeurs (local uniquement)
# .env (ne jamais commiter)
NGROK_AUTHTOKEN=your_personal_ngrok_token
NGROK_DOMAIN=your-custom-domain.ngrok-free.dev
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=sb_your_anon_key

# 3. Charger automatiquement
docker compose --env-file .env up -d
```

### Production (Vercel + Render)

**Vercel Dashboard** → Settings → Environment Variables

| Variable | Value |
|---|---|
| (aucune nécessaire) | Vercel ne déploie que le frontend statique |

**Render Backend** → Settings → Environment Variables

| Variable | Value |
|---|---|
| `PORT` | 5001 |
| `NODE_ENV` | production |
| `CORS_ALLOWED_ORIGINS` | https://malintic-app.vercel.app |
| `PUBLIC_URL` | https://malintic-app.vercel.app |

> 🎯 Render gère la persistance BD. Aucun secret Supabase si vous utilisez Render.

---

## 🛠️ Workflow sécurisé

### A. Développement local

```powershell
# 1. Cloner le repo
git clone https://github.com/your-org/gestion_malintic.git
cd gestion_malintic

# 2. Configurer secrets locaux (ne jamais commiter)
cp .env.example .env
# → Éditer .env avec VOS vraies valeurs

# 3. Vérifier pas de secrets en dur
git diff lib/Services/supabase_config.dart
# → Doit afficher defaultValue: ''

# 4. Démarrer local
docker compose --env-file .env up -d

# 5. Développer & tester
dart analyze  # Pas d'erreurs
flutter test  # Tests passent
```

### B. Fusion sur main

```bash
# AVANT de pusher, vérifier :
git diff --stat HEAD
# → Pas de .env
# → Pas de credentials en dur

git push origin feature-branch
# → Code review (GitHub)
# → Merge si OK
# → GitHub Actions / CI/CD valide
```

### C. Production

```bash
# Vercel déploie AUTOMATIQUEMENT depuis main
# Aucune action manuelle pour le frontend

# Backend (Render):
# 1. Configurer variables d'env dans Render dashboard
# 2. Render tire du GitHub repo
# 3. Déploie automatiquement
```

---

## 🔑 Rotation des secrets

### Ngrok domain

```bash
# Votre domaine personnel peut changer
# Si vous le perdez, utilisez un nouveau :

# AVANT (ancien)
NGROK_DOMAIN=adam-personal-old.ngrok-free.dev

# APRÈS (nouveau)
NGROK_DOMAIN=adam-personal-new.ngrok-free.dev

# Update .env (local) → redémarrer Docker
docker compose down && docker compose --env-file .env up -d

# ⚠️ Les admins accédant via l'ancienne URL perdront l'accès
# Communiquer le nouveau domaine aux admins
```

### Supabase keys

Si vous utilisez Supabase et que la clé est compromise :

```bash
# Dans Supabase dashboard :
# 1. Aller à Settings → API
# 2. Régénérer anon key
# 3. Mettre à jour SUPABASE_ANON_KEY localement

# Redéployer l'app avec nouveaux --dart-define
flutter build web \
  --dart-define=SUPABASE_ANON_KEY=sb_new_key_here
```

### Session cookies

```bash
# Sessions stockées dans server/database.json
# Durée de vie : 8 heures
# Automatiquement invalidées après 8h

# Forcer logout de tous les utilisateurs :
# Éditer server/database.json → sessions: {} (vider)
# Les utilisateurs doivent se reconnecter
```

---

## ✅ Audits de sécurité

### Avant chaque déploiement production

```bash
# 1. Vérifier pas de hardcodes
git log -p --all -S "boil-prude-curry" | head -50
git log -p --all -S "mzixlwnrsqoxolzafmjb" | head -50

# 2. Vérifier .env est dans .gitignore
cat .gitignore | grep "^.env"
# → Doit afficher ".env"

# 3. Vérifier pas de secrets dans code
grep -r "sb_publishable_" lib/
grep -r "ngrok" lib/Services/db_services.dart | grep -v "skip-browser"
# → Aucun match (ok) ou uniquement header ngrok-skip-browser-warning (ok)

# 4. Vercel.json doit pointer vers API publique
cat vercel.json | grep "destination.*api"
# → Doit afficher malintic-api.onrender.com (pas ngrok)
```

### Après déploiement

```bash
# 1. Vérifier HTTPS
curl -I https://malintic-app.vercel.app
# → HTTP/2 200 (SSL actif)

# 2. Vérifier CORS
curl -H "Origin: https://malintic-app.vercel.app" \
     -H "Access-Control-Request-Method: GET" \
     -X OPTIONS https://malintic-api.onrender.com/api/state -v
# → Access-Control-Allow-Origin: https://malintic-app.vercel.app

# 3. Vérifier pas d'exposition ngrok
curl -s https://malintic-app.vercel.app | grep "ngrok"
# → Aucun match (ok)

# 4. Vérifier logs d'erreur
# → Pas de errors "undefined environment variable"
```

---

## 📚 Références

- [OWASP - Secrets Management](https://owasp.org/www-community/Sensitive_Data_Exposure)
- [Flutter - Environment Variables](https://flutter.dev/docs/deployment/web#environment-variables)
- [GitHub - Managing Secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)
- [Vercel - Environment Variables](https://vercel.com/docs/concepts/projects/environment-variables)
- [Render - Environment Variables](https://render.com/docs/environment-variables)

---

## 📞 Escalade sécurité

**Si vous découvrez une faille de sécurité :**

1. ❌ Ne PAS créer une issue GitHub publique
2. ❌ Ne PAS discuter sur Slack/Discord public
3. ✅ **Contacter l'administrateur système directement** (email privé)
4. ✅ Fournir détails techniques (fichier, ligne, impact)
5. ✅ Attendre confirmation de correction avant divulgation

---

Dernière mise à jour : 2026-08-29  
Mainteneur : M@LI-NTIC Équipe Système
