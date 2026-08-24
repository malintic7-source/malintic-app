import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/utils/formatters.dart';
import 'package:gestion_formations/utils/ui_feedback.dart';

class InscriptionPage extends StatefulWidget {
  final String? formationId;

  const InscriptionPage({super.key, this.formationId});

  @override
  State<InscriptionPage> createState() => _InscriptionPageState();
}

class _InscriptionPageState extends State<InscriptionPage> {
  final LocalDataService _db = LocalDataService();
  Formation? _formation;
  int currentStep = 0;
  bool _isSubmitting = false;
  bool _isLoadingFormation = false;
  String? _formationLoadError;
  final Set<String> _selectedModules = {};

  bool get _hasValidSfpSelection {
    if (_formation?.estStage != true) return true;
    return _selectedModules.length == (_formation!.maxModulesParEtudiant ?? 3);
  }

  bool _continueFromModuleSelection() {
    if (!_hasValidSfpSelection) {
      final required = _formation?.maxModulesParEtudiant ?? 3;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pour ce stage SFP, sélectionnez exactement $required modules.')),
      );
      return false;
    }
    return true;
  }

  double get _selectedModulesPrice {
    if (_formation == null) return 0;
    if (_formation!.modulePrices.isNotEmpty) {
      if (_selectedModules.isEmpty) return 0;
      return _db.getFormationModulesTotal(_formation!.id, moduleIds: _selectedModules.toList());
    }
    return _formation!.type == FormationType.enligne
        ? _formation!.prixEnLigne ?? _formation!.prix
        : _formation!.prix;
  }

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedSexe;

  final List<String> _stepTitles = [
    'Sélectionner',
    'Informations',
    'Récapitulatif',
    'Confirmation',
  ];

  final List<String> _stepSubtitles = [
    'Choisissez une formation',
    'Vos coordonnées',
    'Vérifiez votre demande',
    'Validation finale',
  ];

  @override
  void initState() {
    super.initState();
    _loadFormation();
  }

  Future<void> _loadFormation() async {
    final id = widget.formationId?.trim();
    if (id == null || id.isEmpty) return;

    _formation = _db.getFormationById(id);
    if (_formation != null) {
      if (mounted) setState(() {});
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingFormation = true;
      _formationLoadError = null;
    });

    final loaded = await _db.fetchPublicFormationById(id);
    if (!mounted) return;
    setState(() {
      _formation = loaded;
      _isLoadingFormation = false;
      _formationLoadError =
          loaded == null ? 'Formation introuvable ou indisponible.' : null;
    });
  }

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingFormation) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    if (_formationLoadError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  _formationLoadError!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadFormation,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final maxContentWidth = width > 1200 ? 1100.0 : width * 0.95;

    final formationTitle = _formation?.titre ?? 'Formation';

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), AppTheme.primaryDark, AppTheme.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppTheme.heroShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.app_registration_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Formulaire d\'inscription',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (Navigator.canPop(context))
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Colors.white70),
                            tooltip: 'Fermer',
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Inscription à $formationTitle',
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 22 : 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complétez les 4 étapes rapides pour réserver votre place. Sauvegarde automatique.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              if (isMobile)
                _buildMobileStepper(context)
              else
                _buildDesktopStepper(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileStepper(BuildContext context) {
    return Stepper(
      currentStep: currentStep,
      onStepContinue: () {
        if (currentStep == 0 && !_continueFromModuleSelection()) {
          return;
        }
        if (currentStep == 1 && !_formKey.currentState!.validate()) {
          return;
        }
        if (currentStep < 2) {
          setState(() => currentStep += 1);
          return;
        }
        _submitInscription();
      },
      onStepCancel: () {
        if (currentStep > 0) {
          setState(() => currentStep -= 1);
        }
      },
      controlsBuilder: (context, details) {
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (currentStep > 0 && currentStep < 3)
                OutlinedButton.icon(
                  onPressed: details.onStepCancel,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Retour'),
                )
              else
                const SizedBox(),
              if (currentStep < 3)
                FilledButton.icon(
                  onPressed: details.onStepContinue,
                  icon: Icon(currentStep == 2 ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded, size: 18),
                  label: Text(currentStep == 2 ? 'Confirmer' : 'Suivant'),
                ),
            ],
          ),
        );
      },
      steps: _getSteps(),
    );
  }

  Widget _buildDesktopStepper(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: List.generate(
                _stepTitles.length,
                (index) {
                  final isActive = currentStep == index;
                  final isComplete = currentStep > index;
                  return Padding(
                    padding: EdgeInsets.only(bottom: index == _stepTitles.length - 1 ? 0 : 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: isComplete || isActive ? AppTheme.primaryGradient : null,
                            color: isComplete || isActive ? null : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            boxShadow: isActive ? AppTheme.heroShadow : null,
                          ),
                          child: Center(
                            child: isComplete
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                                : Text(
                                    '${index + 1}',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: isActive ? Colors.white : AppTheme.textSecondary,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _stepTitles[index],
                                style: GoogleFonts.poppins(
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                                  fontSize: 15,
                                  color: isActive ? AppTheme.primary : AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _stepSubtitles[index],
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isComplete
                                      ? AppTheme.success
                                      : isActive
                                          ? AppTheme.primary
                                          : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
              boxShadow: AppTheme.cardShadow,
            ),
            child: _buildStepContent(context),
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent(BuildContext context) {
    switch (currentStep) {
      case 0:
        return _buildSelectFormation(context);
      case 1:
        return _buildPersonalInfo(context);
      case 2:
        return _buildPayment(context);
      case 3:
        return _buildConfirmation(context);
      default:
        return const SizedBox();
    }
  }

  Widget _buildSelectFormation(BuildContext context) {
    if (_formation != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Formation sélectionnée',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppDecorations.activeSelectionCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _formation!.titre,
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formation!.type == FormationType.enligne ? 'En Ligne' : 'Présentiel',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_formation!.description, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
                if (_formation!.modules.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Sélectionnez les modules souhaités :', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  ..._formation!.modules.map((m) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: _selectedModules.contains(m) ? AppTheme.primary.withValues(alpha: 0.06) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedModules.contains(m) ? AppTheme.primary : const Color(0xFFE2E8F0),
                        width: _selectedModules.contains(m) ? 1.5 : 1,
                      ),
                    ),
                    child: CheckboxListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      title: Text(m, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: _formation!.modulePrices.containsKey(m)
                          ? Text(AppFormat.fcfa(_formation!.modulePrices[m]!), style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w700))
                          : null,
                      value: _selectedModules.contains(m),
                      activeColor: AppTheme.primary,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            if (_formation!.maxModulesParEtudiant != null && _selectedModules.length >= _formation!.maxModulesParEtudiant!) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Vous avez atteint le maximum de ${_formation!.maxModulesParEtudiant} modules.'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            _selectedModules.add(m);
                          } else {
                            _selectedModules.remove(m);
                          }
                        });
                      },
                    ),
                  )),
                ],
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total estimé', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    Text(
                      AppFormat.fcfa(_selectedModulesPrice),
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.logoRed),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                if (_continueFromModuleSelection()) {
                  setState(() => currentStep = 1);
                }
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Continuer'),
            ),
          ),
        ],
      );
    }

    final formations = _db.getFormations();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sélectionnez une formation',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          itemCount: formations.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final f = formations[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: AppDecorations.inactiveSelectionCard,
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(f.titre, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                subtitle: Text(f.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                trailing: Text(
                  AppFormat.fcfa(f.type == FormationType.enligne ? f.prixEnLigne ?? f.prix : f.prix),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: AppTheme.primary, fontSize: 14),
                ),
                onTap: () {
                  setState(() {
                    _formation = f;
                    // The SFP learner must select modules before supplying
                    // personal information; this also avoids bypassing its
                    // exactly-three-modules validation.
                    currentStep = 0;
                  });
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPersonalInfo(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations Personnelles',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _prenomController,
            decoration: const InputDecoration(
              labelText: 'Prénom',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Veuillez saisir votre prénom' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nomController,
            decoration: const InputDecoration(
              labelText: 'Nom',
              prefixIcon: Icon(Icons.badge_outlined, size: 20),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Veuillez saisir votre nom' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Adresse Email',
              prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Veuillez saisir votre adresse email';
              }
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+').hasMatch(value.trim())) {
                return 'Entrez une adresse email valide';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          FormField<String>(
            initialValue: _selectedSexe,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Le sexe est obligatoire';
              }
              return null;
            },
            builder: (field) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sexe *',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  RadioGroup<String>(
                    groupValue: _selectedSexe,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedSexe = val);
                        field.didChange(val);
                      }
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedSexe = 'Homme');
                              field.didChange('Homme');
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedSexe == 'Homme' ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedSexe == 'Homme' ? AppTheme.primary : const Color(0xFFCBD5E1),
                                  width: _selectedSexe == 'Homme' ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Radio<String>(
                                    value: 'Homme',
                                    activeColor: AppTheme.primary,
                                  ),
                                  Text('Homme', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedSexe = 'Femme');
                              field.didChange('Femme');
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedSexe == 'Femme' ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedSexe == 'Femme' ? AppTheme.primary : const Color(0xFFCBD5E1),
                                  width: _selectedSexe == 'Femme' ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Radio<String>(
                                    value: 'Femme',
                                    activeColor: AppTheme.primary,
                                  ),
                                  Text('Femme', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0, top: 6.0),
                      child: Text(
                        field.errorText!,
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.logoRed, fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _telephoneController,
            decoration: const InputDecoration(
              labelText: 'Numéro de téléphone',
              prefixIcon: Icon(Icons.phone_outlined, size: 20),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) => value == null || value.trim().isEmpty ? 'Veuillez saisir votre numéro de téléphone' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Message ou remarque (optionnel)',
              prefixIcon: Icon(Icons.chat_bubble_outline_rounded, size: 20),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: currentStep > 0 ? () => setState(() => currentStep -= 1) : null,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Retour'),
              ),
              FilledButton.icon(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    setState(() => currentStep += 1);
                  }
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Suivant'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayment(BuildContext context) {
    final selectedFormation = _formation;
    final amount = selectedFormation == null ? 0 : _selectedModulesPrice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Récapitulatif de l\'inscription',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppDecorations.sectionBox,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Formation sélectionnée', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Formation', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
                  Text(selectedFormation?.titre ?? '-', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tarif indicatif', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  Text(AppFormat.fcfa(amount), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.sectionBox,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aucun paiement n\'est demandé à cette étape. Après validation de votre dossier, les versements seront enregistrés par le service Paiements.',
                  style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => currentStep -= 1),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Retour'),
            ),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitInscription,
              icon: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(_isSubmitting ? 'Traitement...' : 'Confirmer l\'inscription'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmation(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.check_circle_rounded, size: 48, color: AppTheme.success),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Inscription confirmée !',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Votre demande d\'inscription a été enregistrée avec succès.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.sectionBox,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.warningDark, size: 20),
              const SizedBox(width: 8),
              Text(
                'En attente de validation administrative.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warningDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              setState(() {
                currentStep = 0;
                _selectedModules.clear();
                _prenomController.clear();
                _nomController.clear();
                _emailController.clear();
                _telephoneController.clear();
              });
            }
          },
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Retour aux formations'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Future<void> _submitInscription() async {
    if (_formation == null) {
      context.showSnack('Veuillez sélectionner une formation.');
      return;
    }

    final prenom = _prenomController.text.trim();
    final nom = _nomController.text.trim();
    final email = _emailController.text.trim();
    final phone = _telephoneController.text.trim();

    if (prenom.isEmpty || nom.isEmpty || email.isEmpty || phone.isEmpty) {
      context.showSnack('Veuillez compléter toutes les informations personnelles.');
      return;
    }
    final emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+');
    if (!emailRegExp.hasMatch(email)) {
      context.showSnack('Veuillez fournir une adresse email valide.');
      return;
    }
    if (!_hasValidSfpSelection) {
      final required = _formation!.maxModulesParEtudiant ?? 3;
      context.showSnack('Veuillez sélectionner exactement $required modules pour le stage SFP.');
      return;
    }
    if (_formation != null && _formation!.modulePrices.isNotEmpty && _selectedModules.isEmpty) {
      context.showSnack('Veuillez sélectionner au moins un module pour cette formation.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _db.createInscription(
        etudiantId: 'web_${DateTime.now().millisecondsSinceEpoch}',
        formationId: _formation!.id,
        prenom: prenom,
        nom: nom,
        email: email,
        telephone: phone,
        description: _descriptionController.text.trim(),
        modules: _selectedModules.isNotEmpty ? _selectedModules.toList() : _formation!.modules,
        typeFormation: _formation!.type.toString().split('.').last,
        sexe: _selectedSexe ?? 'Homme',
      );
      setState(() {
        currentStep = 3;
      });
    } catch (e) {
      if (!mounted) return;
      context.showSnack('Erreur lors de l\'inscription : $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildStepperStepContent(int index) {
    switch (index) {
      case 0:
        return _buildSelectFormation(context);
      case 1:
        return _buildPersonalInfo(context);
      case 2:
        return _buildPayment(context);
      case 3:
        return _buildConfirmation(context);
      default:
        return const SizedBox();
    }
  }

  List<Step> _getSteps() {
    return List.generate(_stepTitles.length, (index) {
      final isComplete = currentStep > index;
      final isActive = currentStep == index;
      return Step(
        title: Text(_stepTitles[index]),
        subtitle: Text(_stepSubtitles[index]),
        content: _buildStepperStepContent(index),
        isActive: isActive,
        state: isComplete
            ? StepState.complete
            : isActive
                ? StepState.editing
                : StepState.indexed,
      );
    });
  }
}
