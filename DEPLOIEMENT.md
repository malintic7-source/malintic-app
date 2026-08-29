# 🚀 Procédure de Déploiement — M@LI-NTIC Gestion

> **Document à lire OBLIGATOIREMENT avant tout déploiement.**
> Ce guide est destiné aux agents IA (Codex, Gemini, Copilot, etc.) et aux développeurs.

---

## 📐 Architecture de production

`
[Code source Flutter]
        │
        ▼
  flutter build web --release
        │
        ▼
   build/web/           ← Artefact statique (HTML/JS/CSS)
        │
        ▼
  Docker (nginx:alpine)
        │
        ├── Accès LOCAL (LAN bureau)  →  http://192.168.x.x:8080
        └── Accès ADMIN (ngrok)       →  https://boil-prude-curry.ngrok-free.dev
                                           (réservé aux admins système)

[Vercel] ← déploiement automatique depuis GitHub main
        └── Accès PUBLIC (apprenants) →  https://malintic-app.vercel.app
`

---

## ✅ Règle d'or avant tout déploiement

**Toujours valider le code AVANT de builder ou pousser :**

```powershell
# 1. Analyse statique — doit retourner "No issues found!"
dart analyze

# 2. Tests unitaires — doit retourner "All tests passed!"
flutter test
```

> ⛔ **Ne JAMAIS déployer si `dart analyze` retourne des erreurs.**

---

## 🔄 Procédure complète de déploiement

### Étape 1 — Valider le code

```powershell
dart analyze
flutter test
```

### Étape 2 — Committer et pousser sur GitHub

```powershell
git add .
git commit -m "type(scope): description courte en français"
git push origin main
```

> Vercel se déploie **automatiquement** dès que `main` est mis à jour.
> Pas besoin de faire quoi que ce soit de plus pour Vercel.

### Étape 3 — Rebuilder l'image Docker locale

```powershell
flutter build web --release
docker compose -p malintic_app build --no-cache app
docker compose -p malintic_app up -d --no-deps --force-recreate app
```

### Commande unique (tout en une seule ligne)

```powershell
dart analyze && flutter test && git add . && git commit -m "fix: description" && git push origin main && flutter build web --release && docker compose -p malintic_app build --no-cache app && docker compose -p malintic_app up -d --no-deps --force-recreate app
```

---

## 🔄 Synchronisation Docker ↔ Supabase

Le conteneur API utilise Supabase comme source de données partagée :

- les écritures locales sont envoyées vers Supabase ;
- l’API relit les tables partagées toutes les 5 secondes ;
- au redémarrage, le conteneur recharge l’état partagé ;
- `restart: unless-stopped` relance automatiquement les services arrêtés ;
- le volume Docker conserve un cache local et un secours si Supabase est momentanément indisponible.

Dans `.env`, le backend doit recevoir `SUPABASE_URL` et une clé serveur (`SUPABASE_SERVICE_ROLE_KEY`, recommandée) ou `SUPABASE_KEY`. Ne jamais utiliser une clé `service_role` dans Flutter ou dans Vercel côté navigateur.

```powershell
docker compose -p malintic_app up -d --build
docker compose -p malintic_app ps
```

La synchronisation est éventuelle (quelques secondes), et non une réplication PostgreSQL instantanée. Pour une haute disponibilité stricte, Supabase reste la source de vérité unique.

---

## 🏗️ Stack technique

| Composant | Technologie |
|---|---|
| Framework UI | Flutter 3.x (stable) |
| Langage | Dart 3.x |
| Web build | flutter build web --release |
| Serveur web | nginx:alpine (Docker) |
| CI/CD public | Vercel (auto depuis GitHub) |
| Tunnel admin | ngrok (réservé admins) |

---

## 🌍 URLs du projet

| Environnement | URL | Usage |
|---|---|---|
| Production publique | https://malintic-app.vercel.app | Apprenants, QR codes |
| Local bureau | http://192.168.x.x:8080 | Réseau Wi-Fi du centre |
| Admin système | https://boil-prude-curry.ngrok-free.dev | Admins uniquement (ngrok) |

> ⚠️ ngrok est RÉSERVÉ aux administrateurs système.
> Les QR codes et liens aux apprenants utilisent TOUJOURS Vercel.

---

## 🎨 Charte graphique

Toutes les couleurs sont dans lib/config/theme.dart. Ne jamais coder de couleurs hex en dur pour les éléments de marque.

```dart
AppTheme.primary        // Bleu principal (#1D447A)
AppTheme.logoRed        // Rouge logo (#C0392B)
AppTheme.heroGradient   // Gradient rouge→bleu→rouge (headers)
AppTheme.heroShadow     // Ombre des headers
AppTheme.success        // Vert succès
AppTheme.error          // Rouge erreur
AppTheme.textPrimary    // Texte principal
AppTheme.textSecondary  // Texte secondaire
```

Le gradient heroGradient est intentionnel et doit être conservé sur tous les headers.

---

## 📱 Règles mobile

- Breakpoint : MediaQuery.of(context).size.width < 600
- Boutons dans les dialogs : TOUJOURS en colonne pleine-largeur (CrossAxisAlignment.stretch)
- Jamais en ligne horizontale dans actions:[] → cause des overflows
- Grilles : utiliser Wrap ou 2 colonnes sur mobile

---

## 🔒 Règles de sécurité

1. Ne jamais exposer le lien ngrok dans l'UI publique
2. Ne jamais modifier db_services.dart sans tester avec flutter test
3. Ne jamais supprimer de données sans confirmation de l'utilisateur
4. ngrok : uniquement pour admins système

---

## 🤖 Instructions pour agents IA

Avant toute modification :
1. Lire lib/config/theme.dart pour la charte
2. dart analyze après chaque modification (attendre 0 erreur)
3. flutter test pour valider la logique métier
4. Ne jamais déployer si erreurs dans l'analyse
5. Respecter la procédure dans l'ordre exact

---

## 📝 Convention de commit

```
feat     → nouvelle fonctionnalité
fix      → correction de bug
ui       → changement d'interface
refactor → refactorisation
test     → tests
chore    → maintenance

Exemple : fix(dialog): corriger overflow des boutons sur mobile
```

---

## 🔐 SÉCURITÉ — Corrections des hardcodes

### ⚠️ Points critiques corrigés (29/08/2026)

#### 1. **Supabase credentials hardcodées** ❌ → ✅ Corrigé
**Problème** : `lib/Services/supabase_config.dart` contenait les credentials en dur
```dart
// ❌ AVANT (FAILLE DE SÉCURITÉ)
defaultValue: 'https://mzixlwnrsqoxolzafmjb.supabase.co'
defaultValue: 'sb_publishable_X9Srmcc9dIppUO8Hl0EDAw_C-giTCqt'
```

**Solution** : Utiliser `--dart-define` au build
```bash
# ✅ APRÈS (SÉCURISÉ)
flutter build web \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_your_anon_key
```

#### 2. **Ngrok domain hardcodé** ❌ → ✅ Corrigé
**Problème** : `boil-prude-curry.ngrok-free.dev` hardcodé partout
- ❌ server.js ligne 627
- ❌ vercel.json ligne 38
- ❌ Documentation statique

**Solution** : Utiliser variable d'environnement NGROK_DOMAIN
```powershell
# .env (non commité)
NGROK_DOMAIN=your-custom-domain.ngrok-free.dev
NGROK_AUTHTOKEN=your_ngrok_token

# Docker charge automatiquement
docker compose --env-file .env up -d ngrok
```

#### 3. **Vercel API routing** ❌ → ✅ Corrigé
**Problème** : URL API hardcodée dans vercel.json

**Solution** : 
- Utiliser `malintic-api.onrender.com` en production
- Script `vercel-config-generator.ps1` pour générer dynamiquement
```powershell
# Générer vercel.json avec bonne URL
.\vercel-config-generator.ps1 -ApiUrl "https://malintic-api.onrender.com"

# Ou Render:
.\vercel-config-generator.ps1 -ApiUrl "https://your-render-backend.onrender.com"
```

#### 4. **Variables d'environnement centralisées** ✅ Ajoutées
**Solution** : Nouveau fichier `.env.example` documenté
```bash
# ✅ À utiliser en local
cp .env.example .env
# Puis éditer .env avec VOS vraies valeurs
```

**Variables gérées** :
- `NGROK_AUTHTOKEN` → ngrok service
- `NGROK_DOMAIN` → ngrok + server.js
- `PUBLIC_URL` → backend CORS
- `SUPABASE_URL`, `SUPABASE_ANON_KEY` → si Supabase utilisé

### 🚀 Nouvelle procédure de déploiement

#### Local (développement)
```powershell
# 1. Copier et configurer .env
cp .env.example .env
# Éditer .env avec vos valeurs locales

# 2. Démarrer les services Docker
docker compose --env-file .env up -d

# 3. Vérifier
curl http://localhost:8000
```

#### Production (Vercel + Render backend)
```powershell
# 1. Configurer vercel.json pour API Render
.\vercel-config-generator.ps1 -ApiUrl "https://malintic-api.onrender.com"
git add vercel.json && git commit -m "chore: update API URL for production"

# 2. Définir variables d'env dans Vercel dashboard
# Aucune variable n'est nécessaire dans Vercel pour ce build

# 3. Push → déploiement auto
git push origin main
```

#### Admin ngrok (tunnel sécurisé)
```powershell
# ⚠️ JAMAIS en dur. Utiliser .env avec votre token personnel
# .env
NGROK_AUTHTOKEN=your_personal_ngrok_token
NGROK_DOMAIN=your-custom-domain.ngrok-free.dev

# Démarrer
docker compose --env-file .env up -d ngrok

# URL publique (admin only)
# https://your-custom-domain.ngrok-free.dev
```

### 📋 Checklist pré-déploiement

- [ ] `.env` configuré avec vraies valeurs ✅
- [ ] `dart analyze` → 0 erreurs ✅
- [ ] `flutter test` → tous tests passent ✅
- [ ] Pas de credentials hardcodées dans le code ✅
- [ ] `vercel.json` a été généré avec la bonne API URL ✅
- [ ] Variables d'env définies dans Vercel dashboard (si besoin) ✅
- [ ] `git push origin main` → Vercel déploie auto ✅

### 🚨 Rappel sécurité

**JAMAIS** commiter `.env` avec les vraies valeurs.
Les credentials doivent TOUJOURS être en variables d'environnement :
- ✅ CI/CD (GitHub Actions, Vercel) : secrets management
- ✅ Docker local : `--env-file .env` (non commité)
- ✅ Compilation Flutter : `--dart-define` flags

```
```

---
Dernière mise à jour : 2026-08-29 — M@LI-NTIC Gestion des Formations
