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

## 🆘 Dépannage

```powershell
# Logs Docker
docker compose -p malintic_app logs app

# Build propre
flutter clean && flutter pub get && flutter build web --release

# Reset conteneur
docker compose -p malintic_app down
docker compose -p malintic_app build --no-cache app
docker compose -p malintic_app up -d app
```

---
Dernière mise à jour : 2026-08-28 — M@LI-NTIC Gestion des Formations
