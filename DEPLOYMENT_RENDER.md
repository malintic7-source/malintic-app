# Déploiement Backend sur Render (Gratuit)

## Pourquoi Render ?

- **100% gratuit** pour les services web
- **Stockage persistant** sur disque (1 GB inclus)
- **API Node.js complète** (pas Serverless)
- **Compatible** avec votre code existant

## 📋 Étapes de déploiement

### 1. Créer un compte Render
1. Allez sur https://render.com
2. Créez un compte avec GitHub

### 2. Connecter votre repo
1. Cliquez sur "New +"
2. Sélectionnez "Web Service"
3. Connectez votre repo: `malintic7-source/malintic-app`

### 3. Configurer le service
Render détectera automatiquement le fichier `render.yaml`. Vérifiez:

- **Name**: `malintic-api`
- **Region**: Choisissez la région la plus proche (ex: Frankfurt)
- **Branch**: `main`
- **Runtime**: `Node`
- **Build Command**: `cd server && npm install --omit=dev`
- **Start Command**: `cd server && node server.js`

### 4. Variables d'environnement
Ajoutez ces variables dans la section "Environment Variables":

```
NODE_ENV=production
PORT=5001
DATA_DIR=/data
BOOTSTRAP_ADMIN_EMAIL=admin@example.com
BOOTSTRAP_ADMIN_PASSWORD=ChangeMe123!
```

### 5. Déployer
Cliquez sur "Create Web Service". Render déploiera automatiquement.

## 🔄 Après le déploiement

### 1. Obtenir l'URL Render
Une fois déployé, Render vous donnera une URL comme:
```
https://malintic-api.onrender.com
```

### 2. Mettre à jour vercel.json
Si l'URL est différente, mettez à jour `vercel.json`:

```json
{
  "source": "/api/:path*",
  "destination": "https://VOTRE-URL-RENDER.onrender.com/api/:path*"
}
```

### 3. Pusher les changements
```bash
git add vercel.json
git commit -m "Update Render API URL"
git push origin main
```

## ✅ Vérification

Testez l'API Render:
```bash
curl https://malintic-api.onrender.com/api/health
```

Devrait retourner: `{"status":"ok"}`

## 📱 Résultat final

- **Frontend**: Vercel (https://appmntic.vercel.app)
- **Backend**: Render (https://malintic-api.onrender.com)
- **Synchronisation**: ✅ Fonctionnelle sur tous les appareils

## ⚠️ Limitations du plan gratuit Render

- **Sleep mode**: Le service s'endort après 15 min d'inactivité
- **Cold start**: ~30 secondes pour le premier appel après le sleep
- **Disque**: 1 GB maximum
- **RAM**: 512 MB

Pour un usage professionnel, envisagez le plan Starter ($7/mois).
