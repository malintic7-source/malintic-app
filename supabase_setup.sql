-- ========================================================
-- M@LINTIC-APP - INITIALISATION SUPABASE (100% GRATUIT)
-- Exécutez ce script dans : Dashboard Supabase > SQL Editor > New query
-- ========================================================

-- 1. Table Utilisateurs
CREATE TABLE IF NOT EXISTS public.users (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    nom TEXT,
    prenom TEXT,
    phone TEXT,
    matricule TEXT,
    role TEXT NOT NULL DEFAULT 'apprenant',
    password_hash TEXT,
    photo_url TEXT,
    specialite TEXT,
    sexe TEXT DEFAULT 'Homme',
    est_actif BOOLEAN DEFAULT true,
    assigned_formations JSONB DEFAULT '[]'::jsonb,
    date_creation TIMESTAMPTZ DEFAULT NOW(),
    date_modification TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Table Formations
CREATE TABLE IF NOT EXISTS public.formations (
    id TEXT PRIMARY KEY,
    titre TEXT NOT NULL,
    description TEXT,
    prix NUMERIC DEFAULT 0,
    modules JSONB DEFAULT '[]'::jsonb,
    formateur_ids JSONB DEFAULT '[]'::jsonb,
    module_formateur_ids JSONB DEFAULT '{}'::jsonb,
    type TEXT DEFAULT 'presentielle',
    status TEXT DEFAULT 'programmee',
    duree_semaines INT DEFAULT 0,
    duree_heures TEXT,
    horaires JSONB DEFAULT '[]'::jsonb,
    photo_url TEXT,
    est_stage BOOLEAN DEFAULT false,
    max_modules_par_etudiant INT,
    nombre_inscrits INT DEFAULT 0,
    date_creation TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Table Inscriptions
CREATE TABLE IF NOT EXISTS public.inscriptions (
    id TEXT PRIMARY KEY,
    etudiant_id TEXT,
    formation_id TEXT REFERENCES public.formations(id) ON DELETE SET NULL,
    nom TEXT,
    prenom TEXT,
    email TEXT,
    telephone TEXT,
    sexe TEXT DEFAULT 'Homme',
    type_formation TEXT,
    description TEXT,
    modules JSONB DEFAULT '[]'::jsonb,
    status TEXT DEFAULT 'enAttente',
    paiement_effectue BOOLEAN DEFAULT false,
    paiement_id TEXT,
    motif_rejet TEXT,
    date_inscription TIMESTAMPTZ DEFAULT NOW(),
    date_acceptation TIMESTAMPTZ
);

-- 4. Table Paiements
CREATE TABLE IF NOT EXISTS public.payments (
    id TEXT PRIMARY KEY,
    inscription_id TEXT,
    etudiant_id TEXT,
    montant NUMERIC NOT NULL,
    remise NUMERIC DEFAULT 0,
    tranche_numero INT DEFAULT 1,
    nombre_tranches INT DEFAULT 1,
    status TEXT DEFAULT 'effectue',
    methode TEXT DEFAULT 'especes',
    reference TEXT,
    recu_par TEXT,
    date_paiement TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Table Séances
CREATE TABLE IF NOT EXISTS public.seances (
    id TEXT PRIMARY KEY,
    formation_id TEXT,
    formateur_id TEXT,
    titre TEXT,
    module_title TEXT,
    description TEXT,
    date_debut TIMESTAMPTZ,
    date_fin TIMESTAMPTZ,
    statut TEXT DEFAULT 'brouillon',
    contenu JSONB DEFAULT '[]'::jsonb,
    presences JSONB DEFAULT '[]'::jsonb,
    date_creation TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Table Logs d'Audit
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id TEXT PRIMARY KEY,
    user_nom TEXT,
    user_role TEXT,
    action TEXT,
    description TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    target_id TEXT,
    target_type TEXT,
    severity TEXT DEFAULT 'info'
);

-- 7. Activer RLS et autoriser l'accès public pour l'application
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN DEFAULT false;
ALTER TABLE public.formations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public Full Access Users') THEN
        CREATE POLICY "Public Full Access Users" ON public.users FOR ALL USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public Full Access Formations') THEN
        CREATE POLICY "Public Full Access Formations" ON public.formations FOR ALL USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public Full Access Inscriptions') THEN
        CREATE POLICY "Public Full Access Inscriptions" ON public.inscriptions FOR ALL USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public Full Access Payments') THEN
        CREATE POLICY "Public Full Access Payments" ON public.payments FOR ALL USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public Full Access Seances') THEN
        CREATE POLICY "Public Full Access Seances" ON public.seances FOR ALL USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public Full Access AuditLogs') THEN
        CREATE POLICY "Public Full Access AuditLogs" ON public.audit_logs FOR ALL USING (true) WITH CHECK (true);
    END IF;
END $$;

-- 8. Activer Realtime sur les tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.users, public.formations, public.inscriptions, public.payments, public.seances, public.audit_logs;

-- ========================================================
-- INSERTION DES DONNEES ACTUELLES
-- ========================================================
INSERT INTO public.users (id, email, nom, prenom, phone, matricule, role, password_hash, photo_url, specialite, sexe, est_actif, assigned_formations)
VALUES ('admin_mamadou', 'mamadou@mntic.ml', 'TOURE', 'Mamadou', '+223 70 00 00 01', 'ADM-2026-001', 'UserRole.admin', 'scrypt$c5e5f991ec9c516941fc42351de02fb4$da86b7f166a27b824166de2e815131131876a49d95dabb7e9953c90808370d96f6f3b7e6491f331e7e094f3d1025a5f531fff9d115d3c8cc587ba8199e61db99', NULL, NULL, 'Homme', true, '[]'::jsonb)
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, nom = EXCLUDED.nom, prenom = EXCLUDED.prenom, assigned_formations = EXCLUDED.assigned_formations;
INSERT INTO public.users (id, email, nom, prenom, phone, matricule, role, password_hash, photo_url, specialite, sexe, est_actif, assigned_formations)
VALUES ('dg_souleymane', 'soulbico@mntic.ml', 'TRAORE', 'SOULEYMANE', '+223 76 00 00 01', NULL, 'UserRole.admin', 'scrypt$ce1b2d9502ee0516f7a213f13c4f3058$3f965b5bc017a04fee551476b042da6993a4ea93b9cda031207c38f88a0267633e6140333434609c69737dad2e8b9bd6145c5c0b33461ea08fe430151db5459c', NULL, NULL, 'Homme', true, '[]'::jsonb)
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, nom = EXCLUDED.nom, prenom = EXCLUDED.prenom, assigned_formations = EXCLUDED.assigned_formations;
INSERT INTO public.users (id, email, nom, prenom, phone, matricule, role, password_hash, photo_url, specialite, sexe, est_actif, assigned_formations)
VALUES ('daf_amadou', 'amadou@mntic.ml', 'TALL', 'Amadou', '+223 76 00 00 02', NULL, 'UserRole.admin', 'scrypt$c8878f13e473b6a504d07ed616ea104e$258b37ed56181ccccd580635bfe8292d35a2f911d7f2e30c16c7c33be36389fc92ad37e693344514c36973cc4890b749be4b46825d81c5869b87fa2b753ae1d2', NULL, NULL, 'Homme', true, '[]'::jsonb)
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, nom = EXCLUDED.nom, prenom = EXCLUDED.prenom, assigned_formations = EXCLUDED.assigned_formations;
INSERT INTO public.users (id, email, nom, prenom, phone, matricule, role, password_hash, photo_url, specialite, sexe, est_actif, assigned_formations)
VALUES ('it_ibrahim', 'ibrahim@mntic.ml', 'GUITTEYE', 'Ibrahim', '+223 76 00 00 03', NULL, 'UserRole.admin', 'scrypt$9361fe8b7170005dbaed0336c60c0c20$f83181d22a7871af8c454431d1be9205fea4b1eddd7b7d6fa21919ffe50650973d2bfec47d8533ac026799b403efba4970e90b3f9c5b178b0bee2b4832970c38', NULL, NULL, 'Homme', true, '[]'::jsonb)
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, nom = EXCLUDED.nom, prenom = EXCLUDED.prenom, assigned_formations = EXCLUDED.assigned_formations;
INSERT INTO public.users (id, email, nom, prenom, phone, matricule, role, password_hash, photo_url, specialite, sexe, est_actif, assigned_formations)
VALUES ('assistant_oumou', 'mntictic@gmail.com', 'TRAORE', 'Oumou', '+223 76 00 00 04', NULL, 'UserRole.admin', 'scrypt$9f7db723253287a48c21d035d76d209e$59b6c77148c92d80ac21f1be81b2a64baf3ce9152e02d77f8158f455f09dfc6ba44bbbb345de219fa8676743eca62993343d93254cc23fbb6f48bbc6fc12e614', NULL, NULL, 'Homme', true, '[]'::jsonb)
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, nom = EXCLUDED.nom, prenom = EXCLUDED.prenom, assigned_formations = EXCLUDED.assigned_formations;
INSERT INTO public.users (id, email, nom, prenom, phone, matricule, role, password_hash, photo_url, specialite, sexe, est_actif, assigned_formations)
VALUES ('usr_1787449737315', 'amadou22@mntic.ml', 'berthe', 'Amadou', '76543465', NULL, 'UserRole.formateur', 'scrypt$75ebc6c45d31093d8eb6cf4d07b6c2de$ac6e3b0fbc34c680610446520310c543907bea130ae634583c594845e58d6e16821f80bf0f0ca226f36a066e07ba432c8725f0457b093d7a50c72a6d47da0595', NULL, NULL, 'Homme', true, '[{"formationId":"cYATeSYfngBQmK7gTcoB","title":"Système de Vidéosurveillance (SVS)","modules":[{"title":"svs · analogique","assignedHours":20,"doneHours":0},{"title":"svs · ip","assignedHours":20,"doneHours":0}],"dateAssigned":"2026-08-23T01:48:58.600"}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, nom = EXCLUDED.nom, prenom = EXCLUDED.prenom, assigned_formations = EXCLUDED.assigned_formations;
INSERT INTO public.users (id, email, nom, prenom, phone, matricule, role, password_hash, photo_url, specialite, sexe, est_actif, assigned_formations)
VALUES ('usr_1787505240623', 'oumou@mntic.ml', 'TRAORE', 'Oumou', '', NULL, 'UserRole.admin', 'scrypt$98267bfce5d41266959b8203a61fde80$886bb7b110d3cf3493e256f761780cbf810f0314ca10c053e8c9607f087a1720fdc00b2238cc658096af0d2392e208bdf5187b5fbb295a9e495f02fca5632188', NULL, NULL, 'Homme', true, '[]'::jsonb)
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, nom = EXCLUDED.nom, prenom = EXCLUDED.prenom, assigned_formations = EXCLUDED.assigned_formations;
INSERT INTO public.formations (id, titre, description, prix, modules, formateur_ids, module_formateur_ids, type, status, duree_semaines, duree_heures, horaires, photo_url, est_stage, max_modules_par_etudiant)
VALUES ('09cKUMEJm3UnRztD4Jm2', 'SFP 5', 'Session de Formation Professionnelle Pratique (SFP 5) — Parcours d''excellence multi-filières pour le renforcement des compétences opérationnelles.', 100000, '["Base de données + IA","Initiation en Windows Server","Initiation au Réseau téléphonique Voip","Initiation en Sécurité Informatique","Maintenance Informatique","Système de vidéosurveillance Analogique","Initiation au Réseau Informatique","Initiation au Système de Panneau Solaire (SPS)","Adobe Photoshop","Adobe Première Pro","CapCut / VN + IA (Vidéo)","Canva + IA (Affiches)","Sage 100 comptabilité Générale","IMITECH (Initiation en entrepreneuriat: Business Model Canvas...)","Word et Excel","Community Management","Intelligence Artificielle (IA)","Internet des Objets (IOT)","Création d''applications (Flutter – Dart – Firebase...)"]'::jsonb, '[]'::jsonb, '{}'::jsonb, 'FormationType.mixte', 'FormationStatus.enCours', 8, '120h', '[{"jour":"Samedi","heureDebut":"09:00","heureFin":"13:00","module":null,"groupe":"SFP 5 • Tous modules","modalite":"Présentiel","lieuOuLien":null}]'::jsonb, NULL, true, 3)
ON CONFLICT (id) DO UPDATE SET titre = EXCLUDED.titre, photo_url = EXCLUDED.photo_url, modules = EXCLUDED.modules;
INSERT INTO public.formations (id, titre, description, prix, modules, formateur_ids, module_formateur_ids, type, status, duree_semaines, duree_heures, horaires, photo_url, est_stage, max_modules_par_etudiant)
VALUES ('cYATeSYfngBQmK7gTcoB', 'Système de Vidéosurveillance (SVS)', 'Formation pratique et approfondie à l''installation, au paramétrage et à la maintenance des systèmes de vidéosurveillance moderne.', 80000, '["svs · analogique","svs · ip"]'::jsonb, '["usr_1787449737315"]'::jsonb, '{"svs · analogique":"usr_1787449737315","svs · ip":"usr_1787449737315"}'::jsonb, 'FormationType.mixte', 'FormationStatus.enCours', 4, '40h', '[{"jour":"Samedi & Dimanche","heureDebut":"10:00","heureFin":"14:00","module":null,"groupe":null,"modalite":null,"lieuOuLien":null}]'::jsonb, NULL, false, NULL)
ON CONFLICT (id) DO UPDATE SET titre = EXCLUDED.titre, photo_url = EXCLUDED.photo_url, modules = EXCLUDED.modules;
INSERT INTO public.formations (id, titre, description, prix, modules, formateur_ids, module_formateur_ids, type, status, duree_semaines, duree_heures, horaires, photo_url, est_stage, max_modules_par_etudiant)
VALUES ('form_1', 'Développement Mobile Flutter', 'Conception et publication d''applications mobiles performantes multiplateformes (Android & iOS) avec Flutter, Dart et backend REST/Firebase.', 150000, '["Bases de Dart","Widgets et UI Material 3","Gestion d''état","Intégration API REST"]'::jsonb, '[]'::jsonb, '{}'::jsonb, 'FormationType.mixte', 'FormationStatus.programmee', 12, '80h', '[{"jour":"Mardi & Jeudi","heureDebut":"16:00","heureFin":"18:30","module":null,"groupe":null,"modalite":null,"lieuOuLien":null}]'::jsonb, NULL, false, NULL)
ON CONFLICT (id) DO UPDATE SET titre = EXCLUDED.titre, photo_url = EXCLUDED.photo_url, modules = EXCLUDED.modules;
INSERT INTO public.formations (id, titre, description, prix, modules, formateur_ids, module_formateur_ids, type, status, duree_semaines, duree_heures, horaires, photo_url, est_stage, max_modules_par_etudiant)
VALUES ('form_2', 'Développement Web Fullstack React & Node.js', 'Formation complète aux technologies Web modernes : Frontend React.js, Backend Node.js/Express, API RESTful et bases de données SQL & NoSQL.', 180000, '["HTML5/CSS3/JavaScript ES6","React.js & Hooks","Node.js & Express","Bases de données SQL & NoSQL"]'::jsonb, '[]'::jsonb, '{}'::jsonb, 'FormationType.enligne', 'FormationStatus.programmee', 10, '60h', '[{"jour":"Lundi & Mercredi","heureDebut":"18:00","heureFin":"20:30","module":null,"groupe":null,"modalite":null,"lieuOuLien":null}]'::jsonb, NULL, false, NULL)
ON CONFLICT (id) DO UPDATE SET titre = EXCLUDED.titre, photo_url = EXCLUDED.photo_url, modules = EXCLUDED.modules;

-- ========================================================
-- MIGRATIONS v2 — colonnes étendues, notifications, normalisation
-- Exécutez cette section sur une base Supabase déjà initialisée.
-- ========================================================

ALTER TABLE public.formations ADD COLUMN IF NOT EXISTS module_prices JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.formations ADD COLUMN IF NOT EXISTS modules_bonus JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.formations ADD COLUMN IF NOT EXISTS prix_en_ligne NUMERIC;
ALTER TABLE public.formations ADD COLUMN IF NOT EXISTS capacite_max INT;
ALTER TABLE public.formations ADD COLUMN IF NOT EXISTS date_debut TIMESTAMPTZ;
ALTER TABLE public.formations ADD COLUMN IF NOT EXISTS date_fin TIMESTAMPTZ;
ALTER TABLE public.formations ADD COLUMN IF NOT EXISTS image_format TEXT;

ALTER TABLE public.inscriptions ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'web';

ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS formation_id TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS date_creation TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS date_effectuation TIMESTAMPTZ;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS motif TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS module_id TEXT;

CREATE TABLE IF NOT EXISTS public.notifications (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    sender_id TEXT,
    sender_email TEXT,
    target_roles JSONB DEFAULT '[]'::jsonb,
    target_user_ids JSONB DEFAULT '[]'::jsonb,
    audience JSONB DEFAULT '[]'::jsonb,
    read_by JSONB DEFAULT '[]'::jsonb,
    reminder_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public Full Access Notifications') THEN
        CREATE POLICY "Public Full Access Notifications" ON public.notifications FOR ALL USING (true) WITH CHECK (true);
    END IF;
END $$;

CREATE OR REPLACE VIEW public.users_public AS
SELECT id, email, nom, prenom, phone, matricule, role, photo_url, specialite, sexe,
       est_actif, assigned_formations, date_creation, date_modification
FROM public.users;

GRANT SELECT ON public.users_public TO anon, authenticated;

UPDATE public.users SET role = 'admin' WHERE role ILIKE '%admin%' AND role <> 'admin';
UPDATE public.users SET role = 'formateur' WHERE role ILIKE '%formateur%' AND role <> 'formateur';
UPDATE public.users SET role = 'apprenant' WHERE role ILIKE '%apprenant%' AND role <> 'apprenant';
UPDATE public.formations SET type = 'mixte' WHERE type ILIKE '%mixte%';
UPDATE public.formations SET type = 'enligne' WHERE type ILIKE '%enligne%';
UPDATE public.formations SET type = 'presentielle' WHERE type ILIKE '%presentiel%';
UPDATE public.formations SET status = 'enCours' WHERE status ILIKE '%encours%';
UPDATE public.formations SET status = 'terminee' WHERE status ILIKE '%terminee%';
UPDATE public.formations SET status = 'programmee' WHERE status ILIKE '%programmee%';

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ⚠️ SÉCURITÉ PRODUCTION : remplacer les policies "Public Full Access" par Supabase Auth
-- avant mise en production publique. L'app Flutter exclut déjà password_hash des SELECT.
