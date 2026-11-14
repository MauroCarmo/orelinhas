import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../../../../core/validation/sanitizers.dart';
import '../../../pet_adoption/domain/pet_adoption_entity.dart';
import '../../../pet_found/data/pet_found_repository.dart';
import '../../../pet_found/domain/pet_found_entity.dart';
import '../../../pet_lost/data/pet_lost_repository.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../../../pet_recognition/data/services/supabase_pet_recognition_service.dart';
import '../controllers/public_profile_controller.dart';
import '../../domain/profile_entity.dart';

class PublicProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final PetLostAlertEntity? lostAlert;
  final String? lostAlertId;
  final PetFoundAlertEntity? foundAlert;
  final String? foundAlertId;
  final PetAdoptionAlertEntity? adoptionAlert;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.lostAlert,
    this.lostAlertId,
    this.foundAlert,
    this.foundAlertId,
    this.adoptionAlert,
  });

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  PetLostAlertEntity? _resolvedLostAlert;
  PetFoundAlertEntity? _resolvedFoundAlert;
  PetAdoptionAlertEntity? _resolvedAdoptionAlert;
  List<String> _galleryUrls = [];
  int _currentPhotoIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _resolvedLostAlert = widget.lostAlert;
    _resolvedFoundAlert = widget.foundAlert;
    _resolvedAdoptionAlert = widget.adoptionAlert;

    if (_resolvedLostAlert != null) {
      _galleryUrls = List<String>.from(_resolvedLostAlert!.effectiveImageUrls);
      _loadExtraPhotos(_resolvedLostAlert!.id);
    } else if (_resolvedFoundAlert != null) {
      _galleryUrls = List<String>.from(_resolvedFoundAlert!.effectiveImageUrls);
      _loadExtraPhotos(_resolvedFoundAlert!.id);
    } else if (_resolvedAdoptionAlert != null) {
      if (_resolvedAdoptionAlert!.imageUrl.isNotEmpty) {
        _galleryUrls = [_resolvedAdoptionAlert!.imageUrl];
      }
    } else if (widget.lostAlertId != null && widget.lostAlertId!.isNotEmpty) {
      _loadLostAlertById(widget.lostAlertId!);
    } else if (widget.foundAlertId != null && widget.foundAlertId!.isNotEmpty) {
      _loadFoundAlertById(widget.foundAlertId!);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadLostAlertById(String alertId) async {
    final alert = await ref
        .read(petLostRepositoryProvider)
        .getAlertById(alertId);
    if (!mounted || alert == null) return;
    setState(() {
      _resolvedLostAlert = alert;
      _galleryUrls = List<String>.from(alert.effectiveImageUrls);
    });
    _loadExtraPhotos(alert.id);
  }

  Future<void> _loadFoundAlertById(String alertId) async {
    final alert = await ref
        .read(petFoundRepositoryProvider)
        .getAlertById(alertId);
    if (!mounted || alert == null) return;
    setState(() {
      _resolvedFoundAlert = alert;
      _galleryUrls = List<String>.from(alert.effectiveImageUrls);
    });
    _loadExtraPhotos(alert.id);
  }

  Future<void> _loadExtraPhotos(String alertId) async {
    if (alertId.isEmpty) return;
    final persisted = await ref
        .read(supabasePetRecognitionServiceProvider)
        .getPetImageUrls(alertId);
    if (!mounted || persisted.isEmpty) return;

    final merged = <String>[
      ..._galleryUrls,
      for (final u in persisted)
        if (!_galleryUrls.contains(u)) u,
    ].take(3).toList();

    if (merged.length != _galleryUrls.length) {
      setState(() {
        _galleryUrls = merged;
      });
    }
  }

  String _cleanDigitsWithoutCountryCode(String raw) {
    var digits = AppSanitizers.digitsOnly(raw);
    if (digits.startsWith('55') &&
        (digits.length == 12 || digits.length == 13)) {
      digits = digits.substring(2);
    }
    return digits;
  }

  String _formatPhoneDisplay(String raw) {
    final digits = _cleanDigitsWithoutCountryCode(raw);
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    return raw.trim();
  }

  String _formatLocationForDisplay(String rawLocation) {
    final trimmed = rawLocation.trim();
    if (!trimmed.contains('Cidade/UF:') && !trimmed.contains(' | ')) {
      return trimmed;
    }

    String street = '';
    String district = '';
    String cityUf = '';
    String cep = '';
    String ref = '';

    for (final part in trimmed.split(' | ')) {
      final item = part.trim();
      if (item.startsWith('Rua:')) {
        street = item.substring(4).trim();
      } else if (item.startsWith('Bairro:')) {
        district = item.substring(7).trim();
      } else if (item.startsWith('Cidade/UF:')) {
        cityUf = item.substring(10).trim();
      } else if (item.startsWith('CEP:')) {
        cep = item.substring(4).trim();
      } else if (item.startsWith('Ref:')) {
        ref = item.substring(4).trim();
      }
    }

    final lines = <String>[
      if (street.isNotEmpty) street,
      if (district.isNotEmpty) 'Bairro: $district',
      if (cityUf.isNotEmpty) cityUf,
      if (cep.isNotEmpty) 'CEP: $cep',
      if (ref.isNotEmpty) 'Referência: $ref',
    ];

    return lines.isNotEmpty ? lines.join('\n') : trimmed;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }

  Future<void> _launchUri(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o aplicativo externo.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(publicProfileProvider(widget.userId));
    final hasAlert = _resolvedLostAlert != null || _resolvedFoundAlert != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Voltar',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        title: Text(hasAlert ? 'Detalhes do alerta' : 'Falar com o tutor'),
      ),
      body: profileAsync.when(
        data: (profile) => _buildContent(context, profile),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          if (hasAlert) {
            return _buildContent(context, null);
          }

          final msg = err is AppException
              ? err.message
              : 'Erro ao carregar informações.';
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    msg,
                    style: AppTextStyles.body(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () =>
                        ref.invalidate(publicProfileProvider(widget.userId)),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProfileEntity? profile) {
    final lost = _resolvedLostAlert;
    final found = _resolvedFoundAlert;
    final adoption = _resolvedAdoptionAlert;

    final String rawContact = lost != null
        ? lost.contact.trim()
        : (found != null && found.contact != null && found.contact!.trim().isNotEmpty
            ? found.contact!.trim()
            : (profile?.phone.trim() ?? ''));
    final phoneDigits = _cleanDigitsWithoutCountryCode(rawContact);
    final formattedPhone = _formatPhoneDisplay(rawContact);

    final PetType? petType = lost?.petType ?? found?.petType ?? adoption?.species;
    final String? breed = lost?.breed ?? found?.breed;
    final String? age = lost?.age ?? found?.apparentAge;
    final String description = lost?.description ?? found?.description ?? adoption?.characteristics ?? '';
    final String location = lost?.lastLocation ?? found?.foundLocation ?? adoption?.region ?? '';
    final DateTime? eventDate = lost?.lostDate ?? found?.foundDate ?? adoption?.createdAt;

    final String title = lost != null
        ? lost.petName
        : (found != null
              ? (found.breed != null && found.breed!.isNotEmpty
                    ? found.breed!
                    : (found.petType == PetType.dog
                          ? 'Cachorro Encontrado'
                          : found.petType == PetType.cat
                          ? 'Gato Encontrado'
                          : 'Pet Encontrado'))
              : (adoption != null ? adoption.name : ''));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- 1. Galeria de Fotos do Pet (até 3) ---
          if (_galleryUrls.isNotEmpty) ...[
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: _galleryUrls.length,
                      onPageChanged: (idx) {
                        setState(() => _currentPhotoIndex = idx);
                      },
                      itemBuilder: (context, index) {
                        return Image.network(
                          _galleryUrls[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 56,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                        );
                      },
                    ),
                    if (_galleryUrls.length > 1)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(160),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_currentPhotoIndex + 1}/${_galleryUrls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (_galleryUrls.length > 1 && _currentPhotoIndex > 0)
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.black45,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.chevron_left,
                                color: Colors.white,
                                size: 22,
                              ),
                              onPressed: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    if (_galleryUrls.length > 1 &&
                        _currentPhotoIndex < _galleryUrls.length - 1)
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.black45,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                                size: 22,
                              ),
                              onPressed: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    if (_galleryUrls.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_galleryUrls.length, (i) {
                            final active = i == _currentPhotoIndex;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: active ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.primary
                                    : Colors.white.withAlpha(200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // --- 2. Informações Detalhadas do Pet ---
          if (lost != null || found != null || adoption != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(title, style: AppTextStyles.heading1()),
                      ),
                      const SizedBox(width: 8),
                      if (petType != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            petType == PetType.dog
                                ? 'Cachorro'
                                : petType == PetType.cat
                                ? 'Gato'
                                : 'Outro',
                            style: AppTextStyles.label(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      if (adoption != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: adoption.isVaccinated
                                ? AppColors.success.withAlpha(25)
                                : AppColors.surfaceLight,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            adoption.isVaccinated ? 'Vacinado' : 'Sem vacina',
                            style: AppTextStyles.label(
                              color: adoption.isVaccinated
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if ((breed != null && breed.isNotEmpty) ||
                      (age != null && age.isNotEmpty)) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        if (breed != null && breed.isNotEmpty)
                          _infoChip(Icons.pets_outlined, 'Raça: $breed'),
                        if (age != null && age.isNotEmpty)
                          _infoChip(
                            Icons.hourglass_empty_outlined,
                            lost != null
                                ? 'Idade: $age'
                                : 'Idade aparente: $age',
                          ),
                      ],
                    ),
                  ],
                  if (description.trim().isNotEmpty &&
                      description.trim() != 'Sem descrição adicional.') ...[
                    const SizedBox(height: 14),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 14),
                    Text(
                      adoption != null ? 'Características' : 'Sobre o pet',
                      style: AppTextStyles.sectionHeader(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: AppTextStyles.body(color: AppColors.textPrimary),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 20,
                        color: lost != null
                            ? AppColors.error
                            : (found != null ? AppColors.success : AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lost != null
                                  ? 'Último local visto'
                                  : (found != null
                                      ? 'Local onde foi encontrado'
                                      : 'Região / Cidade'),
                              style: AppTextStyles.label(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatLocationForDisplay(location),
                              style: AppTextStyles.body(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (eventDate != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lost != null
                              ? 'Desapareceu em ${_formatDate(eventDate)}'
                              : (found != null
                                  ? 'Encontrado em ${_formatDate(eventDate)}'
                                  : 'Publicado em ${_formatDate(eventDate)}'),
                          style: AppTextStyles.body(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // --- 3. Card do Responsável & Contato (Protegido pela LGPD) ---
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Responsável pelo anúncio',
                  style: AppTextStyles.sectionHeader(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primarySoft,
                      backgroundImage:
                          profile?.avatarUrl != null &&
                              profile!.avatarUrl!.isNotEmpty
                          ? NetworkImage(profile.avatarUrl!)
                          : null,
                      child:
                          profile?.avatarUrl == null ||
                              profile!.avatarUrl!.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              size: 28,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (profile?.name != null && profile!.name.isNotEmpty)
                                ? profile.name
                                : 'Responsável pelo Anúncio',
                            style: AppTextStyles.heading3(),
                          ),
                          if (formattedPhone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  formattedPhone,
                                  style: AppTextStyles.body(
                                    color: AppColors.textPrimary,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: formattedPhone),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Telefone copiado!'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.copy_outlined,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (phoneDigits.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: AppButtonStyles.primary(
                      backgroundColor: const Color(0xFF1FAF5A),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 20),
                    label: const Text('Conversar no WhatsApp'),
                    onPressed: () {
                      final msg = lost != null
                          ? 'Olá! Vi o alerta de ${lost.petName} no Orelinhas e gostaria de ajudar.'
                          : (found != null
                              ? 'Olá! Vi o registro do pet encontrado no Orelinhas e acredito que seja meu.'
                              : 'Olá! Vi o anúncio de adoção de ${adoption?.name ?? "seu pet"} no Orelinhas e tenho interesse!');
                      final text = Uri.encodeComponent(msg);
                      _launchUri(
                        Uri.parse('https://wa.me/55$phoneDigits?text=$text'),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.phone_outlined, size: 20),
                    label: const Text('Ligar'),
                    onPressed: () => _launchUri(Uri.parse('tel:$phoneDigits')),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.privacy_tip_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Proteção de Dados (LGPD): Este contato foi informado exclusivamente para ajudar na localização deste pet. Dados pessoais da conta permanecem protegidos.',
                            style: AppTextStyles.bodySmall(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            found != null
                                ? 'O autor deste registro optou por não divulgar telefone de contato (avistamento registrado apenas com foto e localização).'
                                : 'Nenhum telefone público disponível neste perfil.',
                            style: AppTextStyles.bodySmall(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.scaffoldLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.bodySmall(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
