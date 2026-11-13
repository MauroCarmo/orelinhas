import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validation/sanitizers.dart';
import '../../../pet_lost/data/pet_lost_repository.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../../../pet_recognition/data/services/supabase_pet_recognition_service.dart';
import '../controllers/public_profile_controller.dart';
import '../../domain/profile_entity.dart';

class PublicProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final PetLostAlertEntity? lostAlert;
  final String? lostAlertId;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.lostAlert,
    this.lostAlertId,
  });

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  PetLostAlertEntity? _resolvedAlert;
  List<String> _galleryUrls = [];
  int _currentPhotoIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _resolvedAlert = widget.lostAlert;
    if (_resolvedAlert != null) {
      _galleryUrls = List<String>.from(_resolvedAlert!.effectiveImageUrls);
      _loadExtraPhotos(_resolvedAlert!.id);
    } else if (widget.lostAlertId != null && widget.lostAlertId!.isNotEmpty) {
      _loadAlertById(widget.lostAlertId!);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAlertById(String alertId) async {
    final alert = await ref
        .read(petLostRepositoryProvider)
        .getAlertById(alertId);
    if (!mounted || alert == null) return;
    setState(() {
      _resolvedAlert = alert;
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
    final alert = _resolvedAlert;

    return Scaffold(
      backgroundColor: AppColors.scaffoldLight,
      appBar: AppBar(
        title: Text(
          alert != null ? 'Detalhes do Alerta' : 'Responsável pelo Anúncio',
          style: AppTextStyles.heading2(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: profileAsync.when(
        data: (profile) => _buildContent(context, profile, alert),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) {
          if (alert != null) {
            return _buildContent(context, null, alert);
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
                    Icons.error_outline,
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

  Widget _buildContent(
    BuildContext context,
    ProfileEntity? profile,
    PetLostAlertEntity? alert,
  ) {
    // Prioriza sempre o telefone consentido no anúncio (LGPD), nunca o telefone privado da conta
    final rawContact = (alert != null && alert.contact.trim().isNotEmpty)
        ? alert.contact.trim()
        : '';
    final phoneDigits = _cleanDigitsWithoutCountryCode(rawContact);
    final formattedPhone = _formatPhoneDisplay(rawContact);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- 1. Galeria de Fotos do Pet (até 3) ---
          if (_galleryUrls.isNotEmpty) ...[
            Container(
              height: 270,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
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
                                  ? AppColors.accent
                                  : Colors.white.withAlpha(180),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // --- 2. Informações Detalhadas do Pet ---
          if (alert != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          alert.petName,
                          style: AppTextStyles.heading1(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: alert.petType == PetType.dog
                              ? Colors.blue.withAlpha(35)
                              : alert.petType == PetType.cat
                              ? Colors.orange.withAlpha(35)
                              : Colors.purple.withAlpha(35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          alert.petType == PetType.dog
                              ? 'Cachorro'
                              : alert.petType == PetType.cat
                              ? 'Gato'
                              : 'Outro',
                          style: AppTextStyles.label(
                            color: alert.petType == PetType.dog
                                ? Colors.blue.shade800
                                : alert.petType == PetType.cat
                                ? Colors.orange.shade800
                                : Colors.purple.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if ((alert.breed != null && alert.breed!.isNotEmpty) ||
                      (alert.age != null && alert.age!.isNotEmpty)) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        if (alert.breed != null && alert.breed!.isNotEmpty)
                          _infoChip(
                            Icons.cruelty_free_outlined,
                            'Raça: ${alert.breed}',
                          ),
                        if (alert.age != null && alert.age!.isNotEmpty)
                          _infoChip(
                            Icons.hourglass_empty_outlined,
                            'Idade: ${alert.age}',
                          ),
                      ],
                    ),
                  ],
                  if (alert.description.trim().isNotEmpty &&
                      alert.description.trim() !=
                          'Sem descrição adicional.') ...[
                    const SizedBox(height: 14),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 14),
                    Text('DESCRIÇÃO', style: AppTextStyles.sectionHeader()),
                    const SizedBox(height: 6),
                    Text(
                      alert.description,
                      style: AppTextStyles.body(color: AppColors.textPrimary),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Local do desaparecimento',
                              style: AppTextStyles.label(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatLocationForDisplay(alert.lastLocation),
                              style: AppTextStyles.body(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Desapareceu em: ${_formatDate(alert.lostDate)}',
                        style: AppTextStyles.body(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // --- 3. Card do Responsável & Contato (Protegido pela LGPD) ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'RESPONSÁVEL PELO ANÚNCIO',
                  style: AppTextStyles.sectionHeader(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primary.withAlpha(25),
                      backgroundImage:
                          profile?.avatarUrl != null &&
                              profile!.avatarUrl!.isNotEmpty
                          ? NetworkImage(profile.avatarUrl!)
                          : null,
                      child:
                          profile?.avatarUrl == null ||
                              profile!.avatarUrl!.isEmpty
                          ? const Icon(
                              Icons.person,
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
                                : 'Tutor Responsável',
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
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.phone, size: 20),
                          label: const Text('Ligar'),
                          onPressed: () =>
                              _launchUri(Uri.parse('tel:$phoneDigits')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.chat, size: 20),
                          label: const Text('WhatsApp'),
                          onPressed: () {
                            final petName = alert?.petName ?? 'seu pet';
                            final text = Uri.encodeComponent(
                              'Olá! Vi o alerta de $petName no Orelinhas e gostaria de ajudar.',
                            );
                            _launchUri(
                              Uri.parse(
                                'https://wa.me/55$phoneDigits?text=$text',
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
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
                            'Proteção de Dados (LGPD): Este contato foi informado exclusivamente para ajudar na localização deste pet. Dados pessoais da conta do tutor permanecem protegidos.',
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
                  Text(
                    'Nenhum telefone público disponível neste perfil.',
                    style: AppTextStyles.bodySmall(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.scaffoldLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
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
