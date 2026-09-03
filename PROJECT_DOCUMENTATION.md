# M@LINTIC — Documentation complète du projet

## 1. Présentation

M@LINTIC est une plateforme de gestion de formations professionnelles. Elle couvre :

- le catalogue public des formations ;
- les inscriptions par formulaire et QR code ;
- la gestion des utilisateurs, apprenants, formateurs et administrateurs ;
- le suivi des formations, modules, séances et présences ;
- les paiements, remises, tranches et soldes ;
- les notifications et journaux d'audit ;
- la génération de reçus, cartes QR, attestations et exports comptables ;
- les sauvegardes PRA et le monitoring Prometheus/Grafana.

L'architecture actuelle est locale et conteneurisée. PostgreSQL est la source de
persistance principale. Supabase, Firebase, Vercel et Render ne sont plus utilisés
par l'application.

## 2. Architecture générale

```text
Utilisateur LAN ou Internet
          |
          v
  Nginx / Flutter Web
  (malintic_app:80)
          |
          | /api/*
          v
  API Node.js / Express
  (malintic_api:5001)
          |
          v
  PostgreSQL 16
  (malintic_postgres:5432)
```

Accès distant optionnel :

```text
Internet -> Ngrok HTTPS -> malintic_app:80 -> Nginx -> API locale
```

## 3. Technologies utilisées

### Frontend

- **Flutter Web**
- **Dart 3.11+**
- Interface responsive pour administrateurs, formateurs et apprenants
- Compilation de production dans `build/web`
- Bibliothèques principales :
  - `http` : appels à l'API ;
  - `qr_flutter` : QR codes ;
  - `pdf` et `printing` : documents PDF ;
  - `fl_chart` : graphiques ;
  - `file_picker`, `file_saver` et `path_provider` : fichiers ;
  - `share_plus` et `url_launcher` : partage et liens ;
  - `crypto` : fonctions cryptographiques applicatives.

### Backend

- **Node.js 22 Alpine**
- **Express 4**
- **pg 8** pour PostgreSQL
- API REST JSON
- Sessions par jeton
- Hachage des mots de passe avec le module cryptographique Node.js
- ETag et contrôle `304 Not Modified` pour réduire les transferts d'état
- Rate limiting pour les connexions et inscriptions publiques

### Serveur web

- **Nginx Alpine**
- Sert le bundle Flutter compilé
- Sert `web/formation.html` pour les inscriptions publiques
- Proxy `/api/` vers l'API Node.js
- Compression Gzip
- En-têtes de sécurité HTTP
- Stratégies de cache adaptées aux fichiers statiques et bundles JavaScript

### Données

- **PostgreSQL 16 Alpine**
- Volume Docker persistant `malintic_postgres_data`
- Table actuelle `app_state` contenant l'état JSONB compatible avec l'ancien
  modèle de données
- Sauvegarde JSON de compatibilité dans le volume API
- Sauvegardes SQL et snapshots PRA séparés

### Administration et supervision

- **pgAdmin 4** : administration PostgreSQL locale
- **Prometheus** : collecte de métriques
- **Grafana** : tableaux de bord
- **Ngrok** : tunnel HTTPS distant optionnel

## 4. Services Docker Compose

| Service | Rôle | Port local | Réseau principal |
|---|---|---:|---|
| `postgres` | Base PostgreSQL | `127.0.0.1:5432` | backend/admin |
| `api` | API métier Node.js | interne `5001` | frontend/backend |
| `app` | Flutter Web + Nginx | `80`, `8000` | frontend |
| `ngrok` | Tunnel HTTPS | `127.0.0.1:4040` | frontend |
| `pgadmin` | Administration DB | `127.0.0.1:5050` | admin |
| `prometheus` | Monitoring | `127.0.0.1:9090` | monitoring |
| `grafana` | Dashboards | `127.0.0.1:3000` | monitoring |

`pgadmin` et les services de monitoring utilisent des profils Compose. Ils
peuvent être démarrés avec `--profile admin` et `--profile monitoring`.

Configuration de gestion incluse :

- pgAdmin préconfigure le serveur `M@LINTIC PostgreSQL` sur `postgres:5432`.
- Prometheus conserve 15 jours de métriques et surveille ses cibles toutes les
  15 secondes.
- Une alerte `PrometheusTargetDown` est chargée lorsque cette cible devient
  indisponible pendant au moins deux minutes.
- Grafana provisionne automatiquement Prometheus comme source par défaut et
  charge le tableau de bord `M@LINTIC - Vue d'ensemble`.
- Grafana affiche également l'alerte `Cible Prometheus indisponible` dans son
  espace Alerting, sans notification externe tant qu'aucun canal n'est demandé.
- Le service `postgres_backup` crée un dump PostgreSQL compressé chaque jour
  dans le volume `malintic_postgres_backups` et conserve 14 jours de sauvegardes.
- pgAdmin exige un mot de passe maître et expire les sessions après une heure.
  Grafana désactive l'accès anonyme, l'inscription libre et l'intégration dans
  des pages externes. Les interfaces d'administration restent liées à
  `127.0.0.1`.

## 5. Réseaux Docker

- `malintic_frontend_net` : frontend, API et Ngrok ;
- `malintic_backend_net` : réseau interne entre API, PostgreSQL et superviseur ;
- `malintic_admin_net` : PostgreSQL et pgAdmin ;
- `malintic_monitoring_net` : superviseur, Prometheus et Grafana.

Le réseau backend est déclaré `internal: true`, ce qui limite son exposition
directe vers l'extérieur.

## 6. Volumes persistants

| Volume | Contenu |
|---|---|
| `malintic_postgres_data` | Données PostgreSQL principales |
| `malintic_api_data` | JSON de compatibilité, sessions et backups API |
| `malintic_pgadmin_data` | Configuration pgAdmin |
| `malintic_prometheus_data` | Données Prometheus |
| `malintic_grafana_data` | Dashboards et configuration Grafana |

Ne jamais utiliser `docker compose down -v` sur un environnement contenant des
données utiles : cette commande supprime les volumes.

## 7. Modèle de données applicatif

L'état JSONB contient actuellement les collections suivantes :

- `users` : utilisateurs et rôles ;
- `formations` : formations, modules, prix, formateurs et calendrier ;
- `inscriptions` : candidatures et inscriptions publiques ;
- `payments` : paiements, remises, échéances et références ;
- `seances` : séances et présence ;
- `notifications` : messages et alertes ;
- `audit_logs` : traçabilité des actions ;
- `sessions` : sessions persistées côté serveur.

La table PostgreSQL `app_state` conserve un état complet. Cette stratégie
maintient la compatibilité avec le code existant tout en offrant une persistance
locale fiable. Une normalisation en tables relationnelles pourra être réalisée
progressivement.

## 8. Suppression définitive

Les suppressions passent par :

```text
Flutter -> DELETE /api/{collection}/{id}
       -> validation des droits
       -> cascade métier
       -> écriture PostgreSQL
       -> réponse de succès
```

La suppression d'un utilisateur :

1. supprime son compte ;
2. supprime ses inscriptions liées par identifiant ou email ;
3. supprime ses paiements liés ;
4. enregistre l'action dans `audit_logs` ;
5. sauvegarde l'état dans PostgreSQL ;
6. marque les identifiants supprimés côté cache frontend.

Le frontend accepte aussi les collections vides reçues de l'API. Un élément
supprimé ne doit donc pas revenir après synchronisation ou redémarrage.

## 9. Inscriptions publiques et QR code

La page publique est :

```text
/formation.html?id=IDENTIFIANT_FORMATION
```

Flux :

1. la page charge la formation depuis l'API locale ;
2. le candidat remplit le formulaire ;
3. le navigateur envoie `PUT /api/inscriptions/{id}` ;
4. le champ `source` doit être `web` ;
5. l'API valide et sauvegarde l'inscription dans PostgreSQL ;
6. l'interface n'affiche le succès qu'après confirmation API.

Les URL QR doivent utiliser l'adresse réellement accessible par les utilisateurs :

- LAN actuel : `http://192.168.1.6/formation.html?id=...`
- port alternatif : `http://192.168.1.6:8000/formation.html?id=...`
- WAN : domaine Ngrok configuré dans `.env`

Comme l'adresse LAN est fournie par DHCP, elle doit être vérifiée avant de
regénérer ou distribuer les QR codes.

## 10. Authentification et rôles

L'API expose notamment :

- `POST /api/auth/login`
- `POST /api/auth/logout`
- endpoints d'état et de collections protégés par session

Le compte `mamadou@mntic.ml` est reconnu comme administrateur global par l'API.
Il dispose des droits d'administration sur les collections applicatives.

Les mots de passe et jetons ne doivent jamais être écrits dans ce fichier ou
commités dans Git. Les valeurs actives doivent rester dans `.env`, qui doit être
protégé et ignoré par Git.

## 11. Variables d'environnement

Le modèle est disponible dans `.env.example`. Les catégories principales sont :

- paramètres PostgreSQL : `POSTGRES_DB`, `POSTGRES_USER`,
  `POSTGRES_PASSWORD`, `DATABASE_URL` ;
- bootstrap administrateur ;
- `NGROK_AUTHTOKEN` et `NGROK_DOMAIN` ;
- `PUBLIC_URL` et `CORS_ALLOWED_ORIGINS` ;
- identifiants pgAdmin et Grafana.

Ne pas copier les secrets réels dans la documentation, les logs ou les commits.

## 12. Déploiement normal

Depuis la racine du projet :

```powershell
flutter pub get
flutter build web
docker compose config
docker compose up -d --build
docker compose ps
```

Pour démarrer aussi l'administration et le monitoring :

```powershell
docker compose --profile admin --profile monitoring up -d
```

Le script Windows `deploy.bat` automatise les étapes principales du déploiement
local, y compris la compilation, les vérifications et le démarrage Docker.

## 13. Nettoyage Docker sans perte de données

Nettoyage recommandé :

```powershell
docker compose down --remove-orphans
docker image prune -af
docker builder prune -af
docker network prune -f
docker compose up -d --build
```

Cette procédure conserve les volumes si `-v` n'est pas utilisé.

Avant toute opération risquée :

```powershell
docker volume ls
docker compose ps
```

## 14. Sauvegardes et restauration

Types de sauvegardes :

- volume PostgreSQL ;
- sauvegarde SQL PostgreSQL dans `backups/` ;
- snapshots PRA JSON générés par l'API ;
- fichier JSON de compatibilité dans le volume API.

Sauvegarde PostgreSQL indicative :

```powershell
docker exec malintic_postgres pg_dump `
  -U malintic -d malintic -Fc `
  -f /tmp/malintic.dump
```

La restauration doit être réalisée après vérification du fichier, avec arrêt
contrôlé de l'application et conservation d'une sauvegarde préalable.

## 15. API métier principale

Exemples de routes :

| Méthode | Route | Usage |
|---|---|---|
| `GET` | `/api/health` | Santé de l'API |
| `POST` | `/api/auth/login` | Connexion |
| `POST` | `/api/auth/logout` | Déconnexion |
| `GET` | `/api/state` | État applicatif administrateur |
| `GET` | `/api/formations` | Catalogue public |
| `PUT` | `/api/inscriptions/:id` | Inscription publique ou modification autorisée |
| `DELETE` | `/api/:collection/:id` | Suppression protégée |
| `GET` | `/api/pca/status` | État PCA/PRA |
| `POST` | `/api/pra/snapshot` | Créer un snapshot |
| `GET` | `/api/pra/snapshots` | Lister les snapshots |
| `POST` | `/api/pra/restore` | Restaurer un snapshot |

Les routes d'administration exigent une session et vérifient les rôles.

## 16. Sécurité

- PostgreSQL n'est publié que sur `127.0.0.1:5432` ;
- pgAdmin, Grafana et Prometheus sont locaux ;
- le réseau backend Docker est interne ;
- Nginx ajoute des en-têtes de sécurité ;
- les sessions utilisent des jetons aléatoires ;
- les mots de passe legacy sont migrés vers des hash ;
- les connexions et inscriptions publiques sont limitées par IP ;
- les suppressions exigent des droits ;
- les événements sensibles sont inscrits dans `audit_logs` ;
- les secrets sont fournis par `.env`, jamais par le code versionné.

## 17. Monitoring et diagnostic

Vérifications rapides :

```powershell
docker compose ps
curl.exe http://127.0.0.1:8000/api/health
docker compose logs --tail=100 api
docker compose logs --tail=100 postgres
```

Interfaces locales :

- application : `http://127.0.0.1` ou `http://127.0.0.1:8000` ;
- pgAdmin : `http://127.0.0.1:5050` ;
- Grafana : `http://127.0.0.1:3000` ;
- Prometheus : `http://127.0.0.1:9090` ;
- Ngrok inspection : `http://127.0.0.1:4040`.

## 18. Tests et qualité

Commandes utilisées :

```powershell
flutter analyze
flutter test
node --check server\server.js
node --check server\postgres.js
docker compose config
```

Les tests couvrent notamment les modèles, l'authentification, les inscriptions,
les paiements, les exports, la supervision et les flux E2E.

## 19. Arborescence importante

```text
lib/                         Code Flutter
lib/Services/db_services.dart Synchronisation et persistance frontend
lib/Services/auth_provider.dart Authentification Flutter
server/server.js             API Express principale
server/postgres.js           Adaptateur PostgreSQL
server/Dockerfile            Image API
web/formation.html           Portail public QR
build/web/                   Bundle Flutter compilé
docker-compose.yml           Orchestration Docker
docker/postgres/init.sql     Initialisation PostgreSQL
docker/monitoring/           Configuration Prometheus
Dockerfile.fast              Image Nginx/frontend
nginx.conf                   Proxy et sécurité HTTP
deploy.bat                   Déploiement Windows
.env.example                 Modèle de configuration
backups/                     Sauvegardes hors runtime
```

## 20. Limites et évolutions prévues

- normaliser progressivement `app_state` en tables relationnelles ;
- ajouter et enrichir les métriques Prometheus de l'API ;
- automatiser la rotation et l'archivage des sauvegardes ;
- documenter les procédures de restauration testées ;
- stabiliser une stratégie d'adresse LAN malgré le DHCP ;
- maintenir une séparation stricte entre secrets locaux et fichiers versionnés.
