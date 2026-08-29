# 🚀 Optimisation Polling & WebSocket — M@LI-NTIC

> Guide complet pour optimiser la synchronisation des données avec exponential backoff et WebSocket.

---

## 📊 État actuel (avant optimisations)

| Métrique | Valeur | Impact |
|---|---|---|
| **Polling interval** | 2 secondes | 43,200 requêtes/jour par client |
| **Timeout** | 15 secondes | Latence max sur erreurs |
| **Stratégie retry** | Aucune (redemarre toujours à 2s) | Charge serveur élevée |
| **Charge estimée** | ~1000 req/jour (50 users × 20 sync) | **Problème scalabilité** |

---

## ✅ Optimisation 1 : Polling avec Exponential Backoff

### Qu'est-ce que c'est ?

Quand le serveur est en erreur ou surchargé, au lieu de demander tous les 2 secondes, on augmente progressivement :

```
Normal: 2s → 2s → 2s → 2s → 2s → 2s
         ✅    ✅    ✅    ✅    ✅

Avec erreur:
         2s → 3s → 4.5s → 6.75s → 10s → 15s → 30s → 60s (max)
         ✅    ❌    ❌      ❌      ❌     ❌     ❌      ❌

Quand ça revient:
         60s → 2s (reset après 3 succès)
         ❌     ✅
```

### Avantages

- 📉 **-80% requêtes** en cas d'erreur serveur
- 🛡️ **Résilience** aux pannes réseau
- ⚡ **Scalabilité** : moins de charge serveur
- 🔄 **Fallback** automatique vers Supabase si API offline

### Configuration

```dart
// lib/Services/db_services.dart utilise automatiquement :
// - PollingConfig.development() en debug
// - PollingConfig.production() en release

// Pour customiser :
final pollingController = LocalDataService().getPollingController();
final status = pollingController.getStatus();

print('Intervalle actuel: ${status['currentInterval']}s');
print('Erreurs consec: ${status['consecutiveErrors']}');
```

### Presets disponibles

#### Development (Local dev, temps réel)
```dart
PollingConfig.development()
// min: 1s, max: 10s, backoff: 1.3x, reset: 2 succès
// → Debug logs activés
```

#### Production (Performance)
```dart
PollingConfig.production()
// min: 5s, max: 5min, backoff: 2.0x, reset: 5 succès  
// → Optimal pour scalabilité
```

#### HighLatency (Réseau lent)
```dart
PollingConfig.highLatency()
// min: 3s, max: 2min, backoff: 1.8x, reset: 4 succès
// → Pour liens lents (NGN, 3G)
```

### Utilisation custom

```dart
// Dans main.dart ou au démarrage
final customConfig = PollingConfig(
  minInterval: Duration(seconds: 3),       // 3s normal
  maxInterval: Duration(minutes: 2),       // Max 2min
  backoffMultiplier: 1.5,                  // Augmente de 1.5x
  successCountBeforeReset: 4,              // Reset après 4 succès
  requestTimeout: Duration(seconds: 20),   // Timeout 20s
  enableDebugLogs: true,                   // Affiche logs
);

// Passer au service (futur: ajouter méthode de config)
```

### Monitoring

```dart
// Afficher l'état du polling
final controller = LocalDataService().getPollingController();
final status = controller.getStatus();

print({
  'currentInterval': status['currentInterval'],
  'isAtMaxInterval': status['isAtMaxInterval'],
  'consecutiveErrors': status['consecutiveErrors'],
  'consecutiveSuccesses': status['consecutiveSuccesses'],
});

// Résultat (exemple):
// {
//   currentInterval: 15,
//   isAtMaxInterval: false,
//   consecutiveErrors: 3,
//   consecutiveSuccesses: 0,
// }
```

---

## ✨ Optimisation 2 : WebSocket (Temps réel)

### Qu'est-ce que c'est ?

Au lieu de polling (client demande régulièrement), le serveur **push** les mises à jour quand elles arrivent :

```
Polling:
Client:  "Y-a-t-il du nouveau?"
Server:  "Non" → "Non" → "Oui, voilà!" (attendre 2s)

WebSocket:
Client: [Écoute]
Server: → [Push data] (instantané)
```

### Avantages

- ⚡ **Temps réel** : mise à jour en < 100ms
- 📉 **-95% bande passante** (pas de requêtes vides)
- 🔄 **Bidirectionnel** (client ↔ server)
- 📱 **Meilleur pour mobile** (batterie, latence)

### Inconvénients

- 🔧 Plus complexe à implémenter
- 🔌 Demande stateful server (pas serverless)
- 🛡️ Gestion connexion + reconnexion

### Implémentation (Step-by-Step)

#### 1. Backend (Node.js + Express + WebSocket)

Installer `ws` :
```bash
npm install ws
```

Modifier `server/server.js` :
```javascript
const WebSocket = require('ws');
const http = require('http');
const express = require('express');

const app = express();
const httpServer = http.createServer(app);
const wss = new WebSocket.Server({ server: httpServer });

// Store active clients
const clients = new Set();

wss.on('connection', (ws) => {
  console.log('✅ Client WebSocket connecté');
  clients.add(ws);
  
  // Envoyer l'état initial
  ws.send(JSON.stringify({
    type: 'init',
    data: getCurrentState(), // Retourner état DB
  }));
  
  ws.on('message', (message) => {
    const msg = JSON.parse(message);
    // Gérer messages du client (create, update, delete)
  });
  
  ws.on('close', () => {
    clients.delete(ws);
    console.log('❌ Client WebSocket déconnecté');
  });
});

// Quand données changent, broadcast à tous les clients
app.post('/api/formations', (req, res) => {
  // Créer formation...
  
  // Notifier tous les clients
  const message = JSON.stringify({
    type: 'update',
    collection: 'formations',
    data: newFormation,
  });
  
  clients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
    }
  });
});
```

#### 2. Frontend (Flutter + WebSocket)

Créer `lib/Services/websocket_service.dart` :

```dart
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  final _maxReconnectAttempts = 10;
  
  factory WebSocketService() => _instance;
  
  WebSocketService._internal();
  
  /// Connecter au serveur WebSocket
  Future<void> connect(String url) async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;
      _reconnectAttempts = 0;
      
      print('✅ WebSocket connecté à $url');
      
      // Écouter les messages
      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message) as Map<String, dynamic>;
          _messageController.add(data);
        },
        onError: (error) {
          print('❌ WebSocket erreur: $error');
          _isConnected = false;
          _attemptReconnect(url);
        },
        onDone: () {
          print('❌ WebSocket fermé');
          _isConnected = false;
          _attemptReconnect(url);
        },
      );
    } catch (e) {
      print('❌ Erreur connexion WebSocket: $e');
      _attemptReconnect(url);
    }
  }
  
  /// Reconnecter avec exponential backoff
  Future<void> _attemptReconnect(String url) async {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('🚫 Max reconnexions atteintes');
      return;
    }
    
    _reconnectAttempts++;
    final delaySeconds = min(pow(2, _reconnectAttempts).toInt(), 60);
    
    print('🔄 Reconnexion dans ${delaySeconds}s (tentative $_reconnectAttempts/$_maxReconnectAttempts)');
    
    await Future.delayed(Duration(seconds: delaySeconds));
    await connect(url);
  }
  
  /// Envoyer message au serveur
  void send(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }
  
  /// Stream de messages
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  
  /// Est connecté ?
  bool get isConnected => _isConnected;
  
  /// Déconnecter
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _isConnected = false;
  }
}
```

#### 3. Utiliser dans l'app

```dart
// Dans main.dart ou au démarrage
final wsService = WebSocketService();
await wsService.connect('ws://localhost:5001/ws');

// Écouter les mises à jour
wsService.messages.listen((message) {
  print('📨 Message reçu: $message');
  
  if (message['type'] == 'update') {
    // Mettre à jour l'UI
    final collection = message['collection'];
    final data = message['data'];
    
    LocalDataService().updateFromWebSocket(collection, data);
  }
});

// Envoyer des données
wsService.send({
  'type': 'create_formation',
  'data': formationMap,
});
```

### Migration du polling vers WebSocket

**Stratégie progressive (recommandée)** :

1. **Phase 1** : WebSocket + polling fallback
   - Connecter WebSocket
   - Si erreur ou timeout, utiliser polling
   - Économise bande passante mais reste robuste

2. **Phase 2** : WebSocket uniquement
   - Désactiver polling
   - Implémenter reconnexion automatique
   - Meilleure performance

3. **Phase 3** : Optimisations
   - Delta sync (envoyer juste les changements)
   - Compression (MessagePack)
   - Batching (grouper mises à jour)

**Exemple Phase 1** :

```dart
class LocalDataService {
  WebSocketService? _wsService;
  Timer? _fallbackPollingTimer;
  
  void _initSync() {
    // Essayer WebSocket d'abord
    _wsService = WebSocketService();
    _wsService!.connect(wsUrl);
    
    // Fallback polling si WebSocket échoue
    _fallbackPollingTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (!_wsService!.isConnected) {
        _syncFromLocalApi();  // Polling fallback
      }
    });
  }
}
```

---

## 📊 Comparaison de performance

| Métrique | Polling 2s | Polling + Backoff | WebSocket |
|---|---|---|---|
| **Requêtes/jour** | 43,200 | 2,400-8,000 | ~100 |
| **Latence** | 1-2s | 1-60s | 50-100ms |
| **Bande passante** | 2-5 MB | 200KB-2MB | 50-200KB |
| **Charge serveur** | Élevée | Moyenne | Faible |
| **Temps réel** | Non | Non | ✅ Oui |
| **Fiabilité** | Moyenne | Excellente | Bonne (+ fallback) |

---

## 📋 Checklist implémentation

- [ ] Polling configurable déployé
  - [ ] Dev mode (1s min, 10s max)
  - [ ] Prod mode (5s min, 5min max)
  - [ ] HighLatency preset disponible

- [ ] Exponential backoff testé
  - [ ] Erreurs → augmente interval
  - [ ] Succès → reset après N fois
  - [ ] Monitoring via `getPollingController()`

- [ ] WebSocket préparé (optionnel)
  - [ ] Dépendance `web_socket_channel` ajoutée
  - [ ] Service WebSocket créé
  - [ ] Backend prêt pour WS

- [ ] Documentation
  - [ ] Devs savent comment configurer
  - [ ] Guide migration vers WS

---

## 🔧 Configuration recommandée par environnement

### Local (dev)
```dart
PollingConfig.development()  // 1-10s, debug logs
```

### Staging
```dart
PollingConfig.highLatency()  // 3-120s, pour test réaliste
```

### Production
```dart
PollingConfig.production()   // 5s-5min, scalable
```

---

## 📚 Références

- [WebSocket spec](https://tools.ietf.org/html/rfc6455)
- [ws (Node.js library)](https://github.com/websockets/ws)
- [web_socket_channel (Flutter)](https://pub.dev/packages/web_socket_channel)
- [Exponential backoff pattern](https://en.wikipedia.org/wiki/Exponential_backoff)

---

Dernière mise à jour : 2026-08-29
