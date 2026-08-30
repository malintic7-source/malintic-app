# 🔧 Code Quality Improvements - Minors

## Status: Backlog (Quality improvements, non-blocking)

### 1. **Strict Type Validation in fromMap()**

**Location** : `lib/Models/formation.dart:120` et autres

**Issue** : 
```dart
// ❌ Accepte nulls sans assurance
Horaire.fromMap(Map<String, dynamic> map) {
  jour: map['jour'] ?? '',  // Si map['jour'] est null, utilise ''
  // Mais ne valide pas que c'est une string
}
```

**Recommendation** :
```dart
// ✅ Meilleure validation
static String _parseString(dynamic val, {String defaultValue = ''}) {
  if (val is String) return val.trim();
  if (val == null) return defaultValue;
  return val.toString().trim();
}

Horaire.fromMap(Map<String, dynamic> map) {
  jour: _parseString(map['jour']),
  // ...
}
```

**Impact** : 🟢 Low (defensive programming)  
**Effort** : Medium (refactor tous les models)

---

### 2. **Platform-Specific Imports Consistency**

**Location** : `lib/Services/`

**Current** :
```dart
// imagekit_service.dart
export 'imagekit_service_io.dart' if (dart.library.html) 'imagekit_service_web.dart';

// local_storage.dart
// Utilise un pattern différent
```

**Recommendation** : Unifier le pattern d'imports conditionnels

**Impact** : 🟢 Low (code clarity)  
**Effort** : Low

---

### 3. **Remove Try-Catch Silently Swallowing Errors**

**Location** : `lib/main.dart:43-54`

**Issue** :
```dart
// ❌ Silencieusement échoue
for (final item in list) {
  try {
    if (item is Map<String, dynamic>) {
      await _processInscriptionMap(db, item);
    }
  } catch (e) {
    debugPrint('[Malintic] Erreur: $e');
    // Continue silencieusement
  }
}
```

**Recommendation** :
```dart
// ✅ Log les erreurs
int processed = 0, failed = 0;
for (final item in list) {
  try {
    // ...
    processed++;
  } catch (e) {
    failed++;
    debugPrint('[CRITICAL] Failed to process: $e');
  }
}
if (failed > 0) {
  debugPrint('[WARNING] $failed/$processed inscriptions failed import');
}
```

**Impact** : 🟡 Medium (debugging)  
**Effort** : Low

---

### 4. **Optimize Polling Retry Logic**

**Location** : `lib/Services/polling_config.dart`

**Current** : Exponential backoff est implémenté mais pas partout

**Recommendation** :
```dart
// ✅ Utiliser PollingController partout
class PollingController {
  // Déjà implémenté, juste assurer utilisation cohérente
}
```

**Impact** : 🟢 Low (déjà implémenté)  
**Effort** : Low (vérifier cohérence)

---

### 5. **Session Cleanup - Already Implemented ✅**

**Location** : `server/server.js` (ligne 162-173)

**Status** : ✅ DONE  
```javascript
setInterval(() => {
  // Cleanup toutes les heures
}, 60 * 60 * 1000);
```

---

### 6. **Rate-Limiting Inscriptions - Already Implemented ✅**

**Location** : `server/server.js` (ligne 65-70)

**Status** : ✅ DONE  
```javascript
const INSCRIPTION_MAX_PER_HOUR = 10;
// Utilisé dans handleCollectionPut() pour inscriptions
```

---

## Summary Table

| Issue | Impact | Effort | Status |
|-------|--------|--------|--------|
| Strict type validation | 🟢 Low | Medium | Backlog |
| Platform imports consistency | 🟢 Low | Low | Backlog |
| Error logging | 🟡 Medium | Low | Backlog |
| Polling retry consistency | 🟢 Low | Low | Backlog |
| Session cleanup | ✅ | ✅ | DONE |
| Rate-limiting inscriptions | ✅ | ✅ | DONE |

---

## Priority for Next Sprint

1. **Error logging** (easy win, better debugging)
2. **Type validation** (defensive programming)
3. **Imports consistency** (code clarity)

---

**Reviewed**: 2026-08-29  
**Next Review**: 2026-09-29
