# Déploiement Backend sur Vercel (Gratuit)

## Option choisie: Vercel Serverless Functions

Cette option est **100% gratuite** et s'intègre parfaitement avec votre frontend déjà sur Vercel.

## 📁 Fichiers créés/modifiés

- ✅ `api/index.js` - Backend converti en Serverless Function
- ✅ `api/package.json` - Dépendances minimales
- ✅ `vercel.json` - Routage `/api/*` vers la function
- ✅ `render.yaml` - Alternative pour Render (si besoin)

## 🚀 Instructions de déploiement

### 1. Variables d'environnement Vercel

Ajoutez ces variables dans votre projet Vercel (Settings > Environment Variables):

```
BOOTSTRAP_ADMIN_EMAIL=admin@example.com
BOOTSTRAP_ADMIN_PASSWORD=ChangeMe123!
```

### 2. Déployer

Pusher les changements sur GitHub:

```bash
git add api/ vercel.json render.yaml
git commit -m "Add Vercel Serverless API"
git push
```

Vercel déploiera automatiquement la nouvelle version avec l'API.

### 3. Limitations de la version gratuite

- **Stockage**: Les données sont stockées dans `/tmp` (éphémère)
- **Persistance**: Les données sont perdues après chaque redéploiement
- **Durée d'exécution**: Max 10s par requête (Vercel Hobby)
- **Mémoire**: 1024 MB

## 💡 Alternative: Render (Gratuit)

Si vous avez besoin de persistance des données:

1. Connectez votre repo GitHub à [Render](https://render.com)
2. Créez un "Web Service"
3. Utilisez le fichier `render.yaml` déjà créé
4. Ajoutez les mêmes variables d'environnement
5. Mettez à jour `vercel.json` avec l'URL Render:
```json
{
  "source": "/api/:match*",
  "destination": "https://votre-api-render.onrender.com/api/:match*"
}
```

## 📝 Note importante

Pour la production, il est recommandé d'utiliser une vraie base de données (PostgreSQL, MongoDB) au lieu du fichier JSON.
