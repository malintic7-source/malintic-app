# 📡 API Versioning - Documentation

## Overview

Malintic utilise versioning d'API pour assurer la compatibilité rétroactive et faciliter les migrations.

### Versions Supportées

| Version | Status | Endpoint | Support jusqu'à |
|---------|--------|----------|------------------|
| v1 | Current | `/api/v1/...` | 2027-12-31 |
| - | Legacy | `/api/...` (sans version) | 2027-06-30 |

---

## Routes Disponibles

### Health & System
```
GET    /api/v1/health              → Health check
GET    /api/v1/system/network-info → Infos réseau (admin)
```

### Authentication
```
POST   /api/v1/auth/login          → Login (email/phone/matricule)
POST   /api/v1/auth/logout         → Logout
GET    /api/v1/auth/session        → Session courante
POST   /api/v1/auth/change-password → Changer mot de passe
```

### Collections (CRUD)
```
GET    /api/v1/:collection           → Lister
GET    /api/v1/:collection/:id       → Détail
POST   /api/v1/:collection           → Créer
PUT    /api/v1/:collection/:id       → Mettre à jour
DELETE /api/v1/:collection/:id       → Supprimer
```

**Collections disponibles** :
- `users` (admin)
- `formations`
- `inscriptions`
- `payments` (admin/finance)
- `seances` (formateurs)
- `notifications`
- `audit_logs` (admin)

### Admin Routes (Rate-limited 100 req/min)
```
POST   /api/v1/admin/users/:id/password          → Reset password
DELETE /api/v1/audit_logs/clear                  → Clear audit logs
POST   /api/v1/trainer/students/:id/attendance   → Mark attendance
POST   /api/v1/trainer/students/:id/progress     → Update progress
```

---

## Migration Guide

### De `/api/` vers `/api/v1/`

Les deux endpoints sont **identiques** pour le moment. Migration progressive recommandée :

**1. Frontend (Flutter/Web)**
```dart
// Avant
final response = await http.get(Uri.base.resolve('/api/formations'));

// Après (recommandé)
final response = await http.get(Uri.base.resolve('/api/v1/formations'));
```

**2. Clients externes**
```bash
# Avant
curl -X GET https://api.malintic.ml/api/formations

# Après
curl -X GET https://api.malintic.ml/api/v1/formations
```

---

## Bonnes Pratiques

### 1. Toujours spécifier la version
```javascript
// ✅ Bon
fetch('/api/v1/formations')

// ⚠️ Avoid (sera déprécié)
fetch('/api/formations')
```

### 2. Gérer les erreurs de version
```javascript
async function fetchWithFallback(path) {
  try {
    // Essayer v1 en premier
    const res = await fetch(`/api/v1${path}`);
    if (res.ok) return await res.json();
  } catch (err) {
    console.warn(`v1 failed: ${err.message}`);
  }
  
  // Fallback à l'ancienne API
  return await fetch(`/api${path}`).then(r => r.json());
}
```

### 3. Content-Type requis
```javascript
// ✅ Correct
fetch('/api/v1/users', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email: 'test@example.com' })
})

// ❌ Erreur 400
fetch('/api/v1/users', {
  method: 'POST',
  body: JSON.stringify({ email: 'test@example.com' })
  // Manque Content-Type!
})
```

---

## Changelog

### v1 (2026-08-29)
- ✅ Versioning API établi
- ✅ Rate-limiting admin
- ✅ Validation Content-Type
- ✅ API documentation complète

---

## Support

Pour des questions ou migration :
1. Vérifier cette documentation
2. Consulter [README.md](README.md)
3. Ouvrir une issue dans le gestionnaire de versions

**Statut** : Production-ready ✅  
**Dernière mise à jour** : 2026-08-29
