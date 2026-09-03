# 🎓 M@LINTIC-APP — Plateforme Complète de Gestion Académique & Financière

> **Plateforme tout-en-un de gestion des formations professionnelles, inscriptions publiques, suivi pédagogique, comptabilité et émission de documents certifiés (Cartes QR & Attestations PDF).**

---

## 📑 Sommaire

1. [Vue d'Ensemble & Fonctionnalités](#-vue-densemble--fonctionnalités)
2. [Architecture Technique & Stack](#-architecture-technique--stack)
3. [Réseau & Modes d'Accès](#-réseau--modes-daccès)
4. [Déploiement Automatisé (deploy.bat)](#-déploiement-automatisé-deploybat)
5. [Base de Données & Persistance](#-base-de-données--persistance)
6. [Sécurité, CORS & En-têtes Proxy](#-sécurité-cors--en-têtes-proxy)
7. [Documentation de l'API REST](#-documentation-de-lapi-rest)
8. [Arborescence du Projet](#-arborescence-du-projet)
9. [Maintenance & Dépannage](#-maintenance--dépannage)

---

## 🌟 Vue d'Ensemble & Fonctionnalités

**M@LINTIC** est un système de gestion intégré développé pour piloter les activités académiques, administratives et financières des centres de formation :

- 📝 **Portail Public d'Inscription (`/formation.html`) :**
  - Catalogue interactif des filières et formations (ex: SFP5, Flutter, React & Node.js, Vidéosurveillance).
  - Sélection modulaire dynamique avec calcul instantané des tarifs et remises.
  - Génération de reçu d'inscription et QR Code d'identification.
  
- 💼 **Tableau de Bord Administrateur :**
  - Pilotage des KPIs en temps réel (Recettes Encaissées, Reste à Recouvrer, Taux de Recouvrement, Étudiants Actifs).
  - Validation et gestion des dossiers d'inscriptions.
  - Suivi des règlements par tranches, acomptes et historique financier.
  - Export comptable et statistiques analytiques.
  
- 🖨️ **Génération de Documents Officiels :**
  - **Cartes d'Étudiant Stagiaire :** Format badge avec QR Code infalsifiable et matricule unique.
  - **Attestations de Formation & Certificats :** Modèles PDF prêts pour impression avec signature et validation.
  - **Reçus de Paiement :** Téléchargeables et imprimables à chaque encaissement.

- 👨‍🏫 **Espace Formateur :**
  - Liste des modules assignés, planning des séances et liste des apprenants par filière.

- 🎓 **Espace Apprenant / Stagiaire :**
  - Consultation des cours, emploi du temps, statut des paiements et notifications.

---

## 🏛️ Architecture Technique & Stack

L'écosystème repose sur une architecture conteneurisée **Docker Compose** modulaire, résiliente et hautement optimisée :

```
                                  WAN (Internet)
                          https://...ngrok-free.dev
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       HÔTE WINDOWS / DOCKER ENGINE                          │
│                                                                             │
│  LAN (Wi-Fi 192.168.1.x) ──►  Port 80 / 8000 (Nginx Reverse Proxy)          │
│                                       │                                     │
│                     ┌─────────────────┴─────────────────┐                   │
│                     ▼                                   ▼                   │
│         [ Conteneur malintic_app ]          [ Conteneur malintic_api ]       │
│           • Nginx Alpine                      • Node.js Express             │
│           • Bundle Flutter Web Production     • Moteur de synchronisation   │
│           • Page HTML Inscription            • Volume: /data/database.json │
│                     │                                   │                   │
│                     └─────────────────┬─────────────────┘                   │
│                                       ▼                                     │
│                         [ Conteneur malintic_ngrok ]                        │
│                           • Tunnel sécurisé TLS HTTPS                       │
│                           • Redirection vers port 80                        │
└───────────────────────────────────────┬─────────────────────────────────────┘
                                        │ (Optionnel)
                                        ▼
                            [ PostgreSQL local ]
```

### 🛠️ Technologies Utilisées :
- **Frontend :** Flutter Web (Dart 3.x) compilé en mode Release haute performance avec rendu Canvas/HTML responsive.
- **Serveur Web & Reverse Proxy :** Nginx Alpine optimisé avec compression Gzip, gestion du cache et routage `/api/`.
- **Backend API :** Node.js 22 LTS (Express) avec synchronisation d'état atomique, validation et ETag caching.
- **Passerelle WAN :** Ngrok Container avec domaine fixe réservé.
- **Base de Données :** PostgreSQL 16 local, réseau backend privé et volume dédié.
- **Administration :** pgAdmin local uniquement (`--profile admin`).
- **Monitoring :** Grafana/Prometheus optionnels (`--profile monitoring`).

---

## 🌐 Réseau & Modes d'Accès

L'application offre 3 niveaux d'accès simultanés :

| Type d'Accès | URL / Adresse | Cible & Utilisation |
| :--- | :--- | :--- |
| **Local (PC Serveur)** | `http://localhost` ou `http://mntic_app.local` | Utilisation directe sur la machine hôte. |
| **LAN (Wi-Fi Bureau)** | `http://192.168.1.13` (ou port `:8000`) | Accès direct depuis smartphones et PC connectés au Wi-Fi. |
| **WAN (Universel / 4G)** | `https://reformist-pedicure-backfield.ngrok-free.dev` | Inscriptions WhatsApp, accès à distance hors bureau. |

---

## 🚀 Déploiement Automatisé (`deploy.bat`)

Le projet dispose d'un **script maître unique tout-en-un** : [deploy.bat](file:///c:/Users/M_TOURE/Desktop/G/gestion_malintic/deploy.bat).

### Comment lancer le déploiement :
Double-cliquez sur `deploy.bat` ou exécutez dans un terminal Windows :
```cmd
deploy.bat
```

### Ce que le script exécute automatiquement :
1. **Vérification Docker :** Contrôle que Docker Desktop et `.env` sont prêts.
2. **Compilation Flutter Web :** Génère les fichiers statiques de production dans `build/web/`.
3. **Sauvegarde PostgreSQL :** Crée un dump SQL avant le redémarrage.
4. **Construction Docker :** Reconstruit les services applicatifs sans supprimer les volumes.
5. **Démarrage sécurisé :** Lance PostgreSQL, API, frontend et Ngrok.
6. **Vérification de Santé :** Contrôle PostgreSQL et les endpoints applicatifs.

---

## 💾 Base de Données & Persistance

### 1. PostgreSQL local
Les données de production sont stockées dans PostgreSQL, dans le volume Docker persistant **`malintic_postgres_data`**.
- **Connexion interne :** `postgres:5432`
- **Administration graphique :** pgAdmin, disponible avec le profil Docker `admin`
- **Structure des collections :**
  - `users` : Comptes administrateurs, formateurs et apprenants.
  - `formations` : Catalogue des formations, modules, tarifs présentiels et en ligne.
  - `inscriptions` : Dossiers de candidatures et inscriptions validées.
  - `payments` : Historique complet des transactions, acomptes, remises et modes de règlement.
  - `notifications` : Messages internes, alertes de paiement et annonces.
  - `sessions` : Jetons d'authentification actifs.

> [!CAUTION]
> Ne lancez **JAMAIS** la commande `docker compose down -v` car l'option `-v` supprime les volumes persistants et les données réelles. Utilisez toujours `deploy.bat` ou `docker compose down`.

---

## 🔐 Sécurité, CORS & En-têtes Proxy

- **Préservation TLS / HTTPS :** Nginx transmet l'en-tête `X-Forwarded-Proto $http_x_forwarded_proto;` pour garantir que les requêtes venant de Ngrok sont reconnues comme sécurisées et n'entrent pas dans une boucle 301.
- **En-têtes CORS Autorisés :** `Content-Type`, `Authorization`, `x-session-token`, `ngrok-skip-browser-warning`, `If-None-Match`, `Accept`.
- **Bypass d'avertissement Ngrok :** L'en-tête `ngrok-skip-browser-warning: true` est automatiquement injecté par le client et les scripts frontaux.
- **Gestion des Droits :** Rôles stricts (`admin`, `formateur`, `apprenant`) vérifiés côté serveur lors de chaque mutation.

---

## 📡 Documentation de l'API REST

Tous les endpoints sont accessibles sous `/api/` (ou `/api/v1/`) :

| Méthode | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/health` | Vérification de santé du service API. |
| `GET` | `/api/system/network-info` | Renvoie l'IP LAN active, l'URL Ngrok et les ports configurés. |
| `GET` | `/api/state` | État complet synchronisé (Users, Formations, Inscriptions, Payments). |
| `GET` | `/api/formations` | Liste complète du catalogue des formations. |
| `POST` | `/api/formations` | Création ou mise à jour d'une formation. |
| `GET` | `/api/inscriptions` | Liste des inscriptions avec filtre par statut/formation. |
| `POST` | `/api/inscriptions` | Enregistrement d'une nouvelle inscription publique. |
| `GET` | `/api/payments` | Historique des paiements et règlements. |
| `POST` | `/api/payments` | Enregistrement d'un acompte ou règlement complet. |

---

## 📂 Arborescence du Projet

```
gestion_malintic/
├── lib/                             # Code source Flutter (Dart)
│   ├── Models/                      # Modèles de données (User, Formation, Inscription, Payment)
│   ├── Pages/                       # Écrans de l'application
│   │   ├── Admin/                   # Dashboard, Inscriptions, Apprenants, Paiements, Cartes/Attestations
│   │   ├── Formateur/               # Espace Formateur et emploi du temps
│   │   ├── Student/                 # Espace Apprenant et suivi des cours
│   │   └── Public/                  # Formulaires d'inscription et login
│   ├── Services/                    # db_services.dart, auth_service.dart, polling_config.dart
│   └── Widgets/                     # Dialogs (ShareFormation, ExportAccounting, Reçus PDF)
├── server/                          # Backend API Node.js
│   ├── server.js                    # Serveur Express, endpoints REST et logique de synchronisation
│   ├── package.json                 # Dépendances Node.js (express, cors, compression, ws)
│   └── initial_database.json        # Base de données template assainie pour initialisation
├── web/                             # Fichiers Web statiques
│   ├── index.html                   # Point d'entrée de la SPA Flutter Web
│   ├── formation.html               # Page publique d'inscription standalone
│   └── manifest.json                # PWA Configuration
├── backup/                          # Sauvegardes automatiques des bases de données JSON
├── deploy.bat                       # Script maître unifié de déploiement et maintenance
├── docker-compose.yml               # Définition des services (App, API, Ngrok)
├── nginx.conf                       # Configuration du Reverse Proxy Nginx
└── .env                             # Variables d'environnement de production
```

---

## 🔧 Maintenance & Dépannage

### 1. Forcer le rafraîchissement des données sur un navigateur :
Si vous avez ouvert l'application sur un appareil et souhaitez forcer la mise à jour immédiate du cache :
- Appuyez sur **`Ctrl + F5`** (ou `Shift + F5`).

### 2. Vérifier l'état des conteneurs en ligne de commande :
```cmd
docker ps
```

### 3. Consulter les logs en temps réel :
```cmd
docker compose -p malintic_app logs -f api
docker compose -p malintic_app logs -f app
```

---

**M@LINTIC-APP © 2026** — *Plateforme développée pour l'excellence académique et la gestion opérationnelle moderne.*