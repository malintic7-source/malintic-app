import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/config/theme.dart';

class QuickFormationPresetDialog extends StatefulWidget {
  const QuickFormationPresetDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const QuickFormationPresetDialog(),
    );
  }

  @override
  State<QuickFormationPresetDialog> createState() =>
      _QuickFormationPresetDialogState();
}

class _QuickFormationPresetDialogState
    extends State<QuickFormationPresetDialog> {
  final LocalDataService _db = LocalDataService();
  int? _selectedPresetIndex;
  bool _isCreating = false;

  final List<Map<String, dynamic>> _presets = [
    {
      'title': 'Stage Pratique SFP (Systèmes, Réseaux & Sécurité)',
      'description':
          'Stage intensif de 2 mois axé sur la pratique : maintenance PC, réseaux Cisco, virtualisation Linux & Windows Server, câblage et cybersécurité.',
      'badge': 'STAGE SFP 2026',
      'badgeColor': const Color(0xFFE53935),
      'icon': Icons.router_rounded,
      'prix': 50000.0,
      'prixEnLigne': 35000.0,
      'dureeSemaines': 8,
      'dureeHeures': '80 Heures',
      'type': FormationType.mixte,
      'estStage': true,
      'capaciteMax': 25,
      'maxModules': 3,
      'modules': [
        'Architecture matérielle, Diagnostic & Maintenance avancée',
        'Réseaux informatiques, Routage Cisco & Adressage IP',
        'Administration Système Linux Debian/Ubuntu & Windows Server',
        'Virtualisation (Proxmox / VMware ESXi) & Cloud Fondamentaux',
        'Sécurité des infrastructures, Pare-feu pfSense & Sauvegardes 3-2-1',
      ],
      'modulesBonus': [
        'Atelier CV, Profil LinkedIn Pro & Préparation aux Entretiens IT',
        'Gestion de projet informatique & Outils collaboratifs (Git, Notion)',
      ],
      'modulePrices': {
        'Architecture matérielle, Diagnostic & Maintenance avancée': 15000.0,
        'Réseaux informatiques, Routage Cisco & Adressage IP': 20000.0,
        'Administration Système Linux Debian/Ubuntu & Windows Server': 20000.0,
        'Virtualisation (Proxmox / VMware ESXi) & Cloud Fondamentaux': 15000.0,
        'Sécurité des infrastructures, Pare-feu pfSense & Sauvegardes 3-2-1':
            20000.0,
      },
    },
    {
      'title': 'Data Science, Machine Learning & IA Générative',
      'description':
          'Maîtrisez Python, l\'analyse de données Pandas/NumPy, la visualisation PowerBI, le Machine Learning et le prompting LLM professionnel.',
      'badge': 'IA & DATA',
      'badgeColor': const Color(0xFF7C3AED),
      'icon': Icons.psychology_rounded,
      'prix': 90000.0,
      'prixEnLigne': 60000.0,
      'dureeSemaines': 10,
      'dureeHeures': '100 Heures',
      'type': FormationType.mixte,
      'estStage': false,
      'capaciteMax': 20,
      'maxModules': 4,
      'modules': [
        'Programmation Python pour la Data & Algorithmique',
        'Analyse exploratoire de données (Pandas, NumPy, Matplotlib, Seaborn)',
        'Tableaux de bord interactifs PowerBI & SQL avancé pour l\'analytique',
        'Machine Learning appliqué : Scikit-Learn, Régression & Classification',
        'Introduction au Deep Learning, NLP & API LLM (Gemini / OpenAI)',
      ],
      'modulesBonus': [
        'Déploiement d\'applications Data avec Streamlit et FastAPI',
        'Portfolio GitHub Data Analyst & Certification Malintic',
      ],
      'modulePrices': {
        'Programmation Python pour la Data & Algorithmique': 25000.0,
        'Analyse exploratoire de données (Pandas, NumPy, Matplotlib, Seaborn)':
            25000.0,
        'Tableaux de bord interactifs PowerBI & SQL avancé pour l\'analytique':
            30000.0,
        'Machine Learning appliqué : Scikit-Learn, Régression & Classification':
            35000.0,
        'Introduction au Deep Learning, NLP & API LLM (Gemini / OpenAI)':
            30000.0,
      },
    },
    {
      'title': 'Développement Web Fullstack & Apps Mobiles',
      'description':
          'Devenez développeur complet : HTML/CSS/JS Moderne, React.js / Flutter, Node.js / Supabase, API REST & déploiement Cloud Vercel.',
      'badge': 'DEV FULLSTACK',
      'badgeColor': const Color(0xFF0284C7),
      'icon': Icons.code_rounded,
      'prix': 75000.0,
      'prixEnLigne': 45000.0,
      'dureeSemaines': 8,
      'dureeHeures': '80 Heures',
      'type': FormationType.mixte,
      'estStage': false,
      'capaciteMax': 25,
      'maxModules': 3,
      'modules': [
        'Frontend moderne : HTML5, CSS3, Flexbox/Grid & JavaScript ES6+',
        'Développement UI interactif avec React.js & TailwindCSS',
        'Applications mobiles multiplateformes iOS & Android avec Flutter',
        'Backend & Base de données : Node.js, Express & PostgreSQL / Supabase',
        'Architecture API REST, Authentification JWT et Déploiement CI/CD',
      ],
      'modulesBonus': [
        'Bonnes pratiques Git / GitHub & Gestion de projet Agile / Scrum',
        'Hébergement Cloud (Vercel, Render) & Nom de domaine professionnel',
      ],
      'modulePrices': {
        'Frontend moderne : HTML5, CSS3, Flexbox/Grid & JavaScript ES6+':
            20000.0,
        'Développement UI interactif avec React.js & TailwindCSS': 25000.0,
        'Applications mobiles multiplateformes iOS & Android avec Flutter':
            30000.0,
        'Backend & Base de données : Node.js, Express & PostgreSQL / Supabase':
            25000.0,
        'Architecture API REST, Authentification JWT et Déploiement CI/CD':
            20000.0,
      },
    },
    {
      'title': 'Cybersécurité Défensive & Pentesting Éthique',
      'description':
          'Sécurité des SI : Analyse de vulnérabilités, tests d\'intrusion avec Kali Linux, durcissement système, sécurité Wi-Fi & sensibilisation.',
      'badge': 'CYBERSÉCURITÉ',
      'badgeColor': const Color(0xFF059669),
      'icon': Icons.security_rounded,
      'prix': 85000.0,
      'prixEnLigne': 55000.0,
      'dureeSemaines': 8,
      'dureeHeures': '75 Heures',
      'type': FormationType.presentielle,
      'estStage': false,
      'capaciteMax': 18,
      'maxModules': 3,
      'modules': [
        'Fondamentaux de la sécurité informatique, Cryptographie & Normes ISO 27001',
        'Reconnaissance et scan de vulnérabilités (Nmap, Wireshark, Nessus)',
        'Techniques de Pentesting réseau et Web (Kali Linux, Burp Suite, Metasploit)',
        'Sécurisation active : Pare-feu, IDS/IPS (Suricata, Snort) et VPN IPsec',
        'Gestion des incidents de sécurité (SOC), Forensics & Analyse de logs',
      ],
      'modulesBonus': [
        'Sensibilisation anti-phishing & Ingénierie sociale',
        'Préparation aux certifications CompTIA Security+ / CEH',
      ],
      'modulePrices': {
        'Fondamentaux de la sécurité informatique, Cryptographie & Normes ISO 27001':
            20000.0,
        'Reconnaissance et scan de vulnérabilités (Nmap, Wireshark, Nessus)':
            25000.0,
        'Techniques de Pentesting réseau et Web (Kali Linux, Burp Suite, Metasploit)':
            30000.0,
        'Sécurisation active : Pare-feu, IDS/IPS (Suricata, Snort) et VPN IPsec':
            25000.0,
        'Gestion des incidents de sécurité (SOC), Forensics & Analyse de logs':
            25000.0,
      },
    },
    {
      'title': 'Comptabilité Informatisée, Sage Saari & Excel Expert',
      'description':
          'Tenue de comptabilité pratique, gestion commerciale et paie sur progiciels Sage Saari (Compta, Paie, Gescom) et modélisation financière Excel.',
      'badge': 'GESTION & COMPTA',
      'badgeColor': const Color(0xFFD97706),
      'icon': Icons.calculate_rounded,
      'prix': 45000.0,
      'prixEnLigne': 30000.0,
      'dureeSemaines': 6,
      'dureeHeures': '60 Heures',
      'type': FormationType.presentielle,
      'estStage': false,
      'capaciteMax': 20,
      'maxModules': 2,
      'modules': [
        'Principes comptables généraux SYSCOHADA révisé & Organisation des pièces',
        'Pratique sur Sage Compta 100 : Plan comptable, Saisie des écritures, Rapprochement bancaire',
        'Sage Paie & RH : Paramétrage des bulletins, Cotisations INPS/ITS et Déclarations',
        'Sage Gestion Commerciale : Devis, Facturation, Stocks et Règlements clients/fournisseurs',
        'Excel Avancé pour la finance : Formules complexes (RECHERCHEX), TCD, Tableaux de bord dynamiques',
      ],
      'modulesBonus': [
        'Clôture d\'exercice comptable & Édition des états financiers (Bilan, Compte de résultat)',
        'Fiscalité pratique des entreprises maliennes (TVA, IS, Retenues à la source)',
      ],
      'modulePrices': {
        'Principes comptables généraux SYSCOHADA révisé & Organisation des pièces':
            15000.0,
        'Pratique sur Sage Compta 100 : Plan comptable, Saisie des écritures, Rapprochement bancaire':
            20000.0,
        'Sage Paie & RH : Paramétrage des bulletins, Cotisations INPS/ITS et Déclarations':
            15000.0,
        'Sage Gestion Commerciale : Devis, Facturation, Stocks et Règlements clients/fournisseurs':
            15000.0,
        'Excel Avancé pour la finance : Formules complexes (RECHERCHEX), TCD, Tableaux de bord dynamiques':
            20000.0,
      },
    },
  ];

  Future<void> _createFromSelectedPreset() async {
    if (_selectedPresetIndex == null) return;
    setState(() => _isCreating = true);

    try {
      final preset = _presets[_selectedPresetIndex!];
      final now = DateTime.now();
      final formateurs = _db
          .getUsers()
          .where((u) => u.role.toString().toLowerCase().contains('formateur'))
          .toList();
      final defaultFormateurId = formateurs.isNotEmpty
          ? formateurs.first.id
          : null;

      final Map<String, String> moduleFormateurs = {};
      final List<String> modules = List<String>.from(preset['modules'] as List);
      if (defaultFormateurId != null) {
        for (final m in modules) {
          moduleFormateurs[m] = defaultFormateurId;
        }
      }

      final newFormation = Formation(
        id: '',
        titre: preset['title'] as String,
        description: preset['description'] as String,
        modules: modules,
        modulesBonus: List<String>.from(preset['modulesBonus'] as List),
        modulePrices: Map<String, double>.from(preset['modulePrices'] as Map),
        moduleFormateurIds: moduleFormateurs,
        formateurIds: defaultFormateurId != null ? [defaultFormateurId] : [],
        prix: preset['prix'] as double,
        prixEnLigne: preset['prixEnLigne'] as double?,
        type: preset['type'] as FormationType,
        status: FormationStatus.programmee,
        dureeSemaines: preset['dureeSemaines'] as int,
        dureeHeures: preset['dureeHeures'] as String,
        horaires: const [],
        dateDebut: now.add(const Duration(days: 14)),
        dateFin: now.add(
          Duration(days: 14 + ((preset['dureeSemaines'] as int) * 7)),
        ),
        dateCreation: now,
        capaciteMax: preset['capaciteMax'] as int,
        nombreInscrits: 0,
        estStage: preset['estStage'] as bool,
        maxModulesParEtudiant: preset['maxModules'] as int?,
      );

      await _db.addFormation(newFormation);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Formation « ${preset['title']} » créée avec succès au catalogue.',
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur création: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? width * 0.95 : 700,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Entête
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Modèles de Formations (1-Clic)',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Choisissez un cursus complet prédéfini pour l\'ajouter instantanément',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Liste des presets
              Expanded(
                child: ListView.separated(
                  itemCount: _presets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final preset = _presets[index];
                    final isSelected = _selectedPresetIndex == index;
                    final badgeColor = preset['badgeColor'] as Color;

                    return InkWell(
                      onTap: () => setState(() => _selectedPresetIndex = index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withValues(alpha: 0.05)
                              : Colors.white,
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                preset['icon'] as IconData,
                                color: badgeColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          preset['title'] as String,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? AppTheme.primary
                                                : AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          preset['badge'] as String,
                                          style: GoogleFonts.poppins(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: badgeColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    preset['description'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      _buildInfoPill(
                                        Icons.monetization_on_outlined,
                                        '${(preset['prix'] as double).toStringAsFixed(0)} FCFA',
                                      ),
                                      _buildInfoPill(
                                        Icons.timer_outlined,
                                        '${preset['dureeSemaines']} sem. (${preset['dureeHeures']})',
                                      ),
                                      _buildInfoPill(
                                        Icons.menu_book_outlined,
                                        '${(preset['modules'] as List).length} modules',
                                      ),
                                      _buildInfoPill(
                                        Icons.people_outline,
                                        'Max ${preset['capaciteMax']} places',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // ignore: deprecated_member_use
                            Radio<int>(
                              value: index,
                              // ignore: deprecated_member_use
                              groupValue: _selectedPresetIndex,
                              activeColor: AppTheme.primary,
                              // ignore: deprecated_member_use
                              onChanged: (val) =>
                                  setState(() => _selectedPresetIndex = val),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isCreating
                        ? null
                        : () => Navigator.pop(context),
                    child: Text(
                      'Annuler',
                      style: GoogleFonts.poppins(color: Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _selectedPresetIndex == null || _isCreating
                        ? null
                        : _createFromSelectedPreset,
                    icon: _isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.add_task_rounded, size: 18),
                    label: Text(
                      _isCreating
                          ? 'Création en cours...'
                          : 'Créer cette formation',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
