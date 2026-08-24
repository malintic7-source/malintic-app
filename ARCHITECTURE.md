# 📱 Architecture Technique - Malintic (Gestion des Formations)

Plateforme complète de gestion de formations professionnelles, multi-rôles et ultra-responsive avec synchronisation temps réel, persistance locale et conteneurisation Docker.

---

## 🎯 Vue d'Ensemble du Système

L'application **Malintic** permet la gestion de bout en bout du cycle de formation :
1. **Inscriptions publiques en ligne** (Web) avec sélection des filières, modules et calcul des tarifs.
2. **Administration & Gestion** : Validation des candidatures, suivi financier, génération de reçus PDF, cartes de stagiaires et attestations de formation.
3. **Espace Formateur** : Suivi des étudiants assignés par module, planification et emploi du temps.
4. **Espace Apprenant / Stagiaire** : Consultation des cours, emploi du temps, historique des paiements et notifications.

---

## 🔐 Matrice des Rôles et Permissions

Le système gère 8 profils regroupés sous 3 grandes familles d'accès (`UserRole`) :

```
                               ┌─────────────────────────────────────────────────────────────┐
                               │                     Système de Rôles                        │
                               └─────────────────────────────────────────────────────────────┘
                                                              │
            ┌─────────────────────────────────────────────────┼──────────────────────────────┐
            ▼                                                 ▼                              ▼
┌───────────────────────┐                         ┌───────────────────────┐      ┌───────────────────────┐
│ Administration & DAF  │                         │       Pédagogie       │      │       Apprenant       │
│ • Admin               │                         │ • Formateur           │      │ • Apprenant           │
│ • DG (Direction Gén.) │                         └───────────────────────┘      │   (Étudiant/Stagiaire)│
│ • DAF                 │                                                        └───────────────────────┘
│ • Comptable           │
│ • Assistant           │
│ • IT / Support        │
└───────────────────────┘
```

| Famille | Rôles (`UserRole`) | Accès & Fonctionnalités Clés |
| :--- | :--- | :--- |
| **Administration** | `admin`, `dg`, `daf`, `comptable`, `assistant`, `it` | Dashboard complet, gestion des formations, validation des inscriptions, encaissement & tranches de paiement, génération de cartes & attestations PDF, journal d'audit, planification des séances. |
| **Formateurs** | `formateur` | Dashboard personnel, liste des apprenants inscrits à ses modules, planning & séances de cours, profil et notifications. |
| **Apprenants** | `apprenant` | Dashboard de progression, catalogue des formations, emploi du temps, historique des paiements et reçus PDF, profil et notifications. |

---

## 📁 Structure du Projet

```
gestion_malintic/
├── lib/
│   ├── config/
│   │   └── theme.dart                 # Thème centralisé (Material 3, palette Malintic)
│   ├── Models/
│   │   ├── audit_log.dart             # Journal d'audit et traçabilité des actions
│   │   ├── formation.dart             # Formations, modules, tarifs, formateurs assignés, horaires
│   │   ├── inscription.dart           # Inscriptions (en attente, acceptée, rejetée, modules)
│   │   ├── notification.dart          # Notifications ciblées par rôle / utilisateur
│   │   ├── payment.dart               # Paiements, tranches, remises, moyens de paiement
│   │   ├── seance.dart                # Séances de cours, dates, heures, salles/liens, statuts
│   │   └── user.dart                  # Utilisateurs et énumération UserRole
│   ├── Services/
│   │   ├── auth_provider.dart         # Gestion des sessions, rôles, login/logout
│   │   ├── db_services.dart           # LocalDataService (synchronisation API, persistance, streams)
│   │   ├── imagekit_service.dart      # Upload et gestion d'images (web & natif)
│   │   ├── invoice_service.dart       # Génération de factures & reçus de caisse PDF
│   │   ├── local_storage.dart         # Wrapper multi-plateforme localStorage & sessionStorage
│   │   ├── notifications_services.dart# Gestion et filtrage des notifications
│   │   ├── payment_report_service.dart# Rapports financiers et exports de paiements
│   │   ├── pdf_helper.dart            # Utilitaires de rendu et téléchargement PDF
│   │   ├── pdf_service.dart           # Générateur de cartes d'étudiant & attestations PDF
│   │   ├── poles_d_services.dart      # Dialogues d'assistance (Appel / WhatsApp)
│   │   └── tab_session_lifecycle.dart # Cycle de vie des onglets et sessions
│   ├── Pages/
│   │   ├── Admin/
│   │   │   ├── apprenants.dart        # Gestion détaillée des apprenants & stagiaires
│   │   │   ├── attestations_cartes.dart# Génération & impression cartes / attestations
│   │   │   ├── audit_logs.dart        # Visualisation des logs d'activité système
│   │   │   ├── dashboard.dart         # Tableau de bord administratif interactif
│   │   │   ├── formateurs.dart        # Gestion des formateurs et affectations
│   │   │   ├── formations.dart        # Gestion des filières, modules et tarifs
│   │   │   ├── inscriptions.dart      # Traitement des demandes d'inscription
│   │   │   ├── paiements.dart         # Gestion des encaissements, tranches et reçus
│   │   │   ├── planning.dart          # Planification et publication des séances
│   │   │   └── users.dart             # Administration des utilisateurs et accès
│   │   ├── Formateur/
│   │   │   ├── apprenants.dart        # Apprenants par module
│   │   │   ├── dashboard.dart         # Vue formateur
│   │   │   └── schedule.dart          # Emploi du temps du formateur
│   │   ├── Student/
│   │   │   ├── dashboard.dart         # Vue d'accueil apprenant
│   │   │   ├── discover_formations.dart# Exploration du catalogue
│   │   │   ├── formations.dart        # Formations souscrites
│   │   │   └── schedule.dart          # Emploi du temps apprenant
│   │   ├── INSCRIPTIONS/
│   │   │   └── formulaire.dart        # Formulaire public d'inscription multi-étapes
│   │   ├── Login/
│   │   │   ├── sign_in.dart           # Formulaire de connexion
│   │   │   └── welcome_page.dart      # Écran d'accueil / portail de connexion
│   │   ├── Common/
│   │   │   └── profile.dart           # Profil utilisateur et changement de mot de passe
│   │   ├── Screens/
│   │   │   ├── notifications.dart     # Centre de notifications
│   │   │   └── payments.dart          # Historique des règlements
│   │   └── home_screen.dart           # Routeur principal dynamique selon le rôle
│   ├── Widgets/
│   │   ├── chart_widgets.dart         # Graphiques et métriques visuelles
│   │   ├── formation_image_widget.dart# Affichage optimisé des visuels de formation
│   │   ├── main_layout.dart           # Layout responsive (Sidebar desktop / Drawer mobile)
│   │   ├── pro_data_table.dart        # Tableaux de données enrichis (recherche, tri, pagination)
│   │   └── pro_form.dart              # Formulaires standardisés
│   ├── utils/
│   │   ├── file_saver.dart            # Téléchargement de fichiers multi-plateforme
│   │   ├── responsive.dart            # Breakpoints et helpers adaptatifs
│   │   └── share_helper.dart          # Partage de documents
│   └── main.dart                      # Point d'entrée de l'application Flutter
├── server/
│   ├── Dockerfile                     # Image du backend Node.js
│   ├── package.json                   # Dépendances Node.js / Express
│   └── server.js                      # API REST, persistance JSON, sessions et validation
├── docker-compose.yml                 # Orchestration (Flutter Web Nginx + Node API + Ngrok)
├── nginx.conf                         # Reverse proxy Nginx et routage /api/
└── ARCHITECTURE.md                    # Documentation d'architecture technique
```

---

## 🏗️ Architecture & Flux de Données

### 1. Backend & API Locale (`server/server.js`)
- **Serveur Express** hébergé sur le port interne 5001.
- **Persistance des données** : Stockage transactionnel dans un volume partagé Docker (`/data/database.json`).
- **Collections gérées** :
  - `users` : Comptes utilisateurs, formateurs, stagiaires, personnel administratif.
  - `formations` : Catalogue, modules, tarifs présentiel/en ligne, formateurs responsables.
  - `inscriptions` : Demandes d'inscription, statut, pièces et modules sélectionnés.
  - `payments` : Historique des encaissements, échéances, tranches, reçus.
  - `notifications` : Alertes et messages ciblés par rôle ou individu.
  - `audit_logs` : Journalisation horodatée des actions administratives.
  - `seances` : Planification des cours et séances publiées.
- **Sécurité des sessions** : Cookie HttpOnly `malintic_session` avec cycle de vie lié au navigateur et protection des routes réservées au personnel.

### 2. Couche Client & Synchronisation (`LocalDataService`)
- **Fonctionnement hors-ligne et réactif** : Les données sont disponibles immédiatement grâce au cache local (`LocalStorage`) et diffusées via des `StreamController` Flutter.
- **Synchronisation automatique** : Sondage périodique et écriture asynchrone vers l'API REST (`/api/...`).
- **Migration & Fusion (Merge)** : Synchronisation bidirectionnelle intelligente préservant les données existantes.

### 3. Génération de Documents PDF
- **Reçus de paiement & Factures** : Générés à la volée avec référence unique, décomposition des montants, tranches payées/restantes et signature (`InvoiceService`).
- **Cartes de Stagiaire** : Format badge avec photo, code matricule, filière et QR code (`PdfService`).
- **Attestations de Formation** : Format officiel certifiant la réussite du stagiaire (`PdfService`).

---

## 🎨 Design System & Palette de Couleurs

| Élément | Couleur Hex | Usage |
| :--- | :--- | :--- |
| **Primary Blue** | `#0066CC` | Marque, boutons principaux, en-têtes |
| **Dark Primary** | `#0052A3` | États survolés, barres de titre |
| **Accent Orange** | `#FF6B35` | Badges, alertes, graphiques, points forts |
| **Success Green** | `#00B341` | Validations, inscriptions acceptées, paiements soldés |
| **Warning Orange** | `#FFA500` | Inscriptions en attente, tranches à venir |
| **Error / Red** | `#E53935` | Annulations, rejets, soldes impayés |
| **Background** | `#F8F9FA` | Fond général de l'application |
| **Surface** | `#FFFFFF` | Cartes, modals, conteneurs de formulaire |

---

## 🚀 Déploiement & Environnement Docker

Le projet s'exécute via `docker-compose` avec une stack complète :
- **Service Web (Nginx)** : Sert le bundle Flutter Web compilé et route les appels `/api/*` vers le backend.
- **Service API (Node.js)** : Traite les requêtes métiers et persiste dans `/data/database.json`.
- **Tunnel distant optionnel (Ngrok)** : Permet l'accès sécurisé depuis l'extérieur.

```bash
# Lancement des conteneurs
docker compose up -d --build
```
