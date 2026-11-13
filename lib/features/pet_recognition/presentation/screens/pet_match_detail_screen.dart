import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../../../pet_found/data/pet_found_repository.dart';
import '../../../pet_found/domain/pet_found_entity.dart';
import '../../../pet_lost/data/pet_lost_repository.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../../data/services/supabase_pet_recognition_service.dart';
import '../../domain/models/pet_match_candidate_entity.dart';
import '../../domain/utils/recognition_config.dart';
import '../widgets/similarity_badge.dart';

/// Tela de visualização direta da correspondência entre um pet perdido e um pet encontrado.
/// Exibe os dados do pet avistado e a pontuação persistida sem disparar nova inferência por IA.
class PetMatchDetailScreen extends ConsumerStatefulWidget {
  final String foundPetId;
  final String? lostPetId;
  final double? initialScore;

  const PetMatchDetailScreen({
    super.key,
    required this.foundPetId,
    this.lostPetId,
    this.initialScore,
  });

  @override
  ConsumerState<PetMatchDetailScreen> createState() =>
      _PetMatchDetailScreenState();
}

class _PetMatchDetailScreenState extends ConsumerState<PetMatchDetailScreen> {
  bool _isLoading = true;
  PetFoundAlertEntity? _foundPet;
  PetLostAlertEntity? _lostPet;
  double? _score;

  @override
  void initState() {
    super.initState();
    _loadMatchDetails();
  }

  Future<void> _loadMatchDetails() async {
    setState(() {
      _isLoading = true;
    });

    final foundRepo = ref.read(petFoundRepositoryProvider);
    final lostRepo = ref.read(petLostRepositoryProvider);
    final recognitionService = ref.read(supabasePetRecognitionServiceProvider);

    final found = await foundRepo.getAlertById(widget.foundPetId);

    PetLostAlertEntity? lost;
    if (widget.lostPetId != null && widget.lostPetId!.isNotEmpty) {
      lost = await lostRepo.getAlertById(widget.lostPetId!);
    }

    double? resolvedScore;
    if (widget.lostPetId != null && widget.lostPetId!.isNotEmpty) {
      resolvedScore = await recognitionService.getMatchScore(
        widget.lostPetId!,
        widget.foundPetId,
      );
    }
    resolvedScore ??= widget.initialScore;

    if (mounted) {
      setState(() {
        _foundPet = found;
        _lostPet = lost;
        _score = resolvedScore;
        _isLoading = false;
      });
    }
  }

  String _formatLocationForDisplay(String rawLocation) {
    final trimmed = rawLocation.trim();
    if (!trimmed.contains('Cidade/UF:') && !trimmed.contains(' | ')) {
      return trimmed;
    }

    String district = '';
    String cityUf = '';

    for (final part in trimmed.split(' | ')) {
      final item = part.trim();
      if (item.startsWith('Bairro:')) {
        district = item.substring(7).trim();
      } else if (item.startsWith('Cidade/UF:')) {
        cityUf = item.substring(10).trim();
      }
    }

    final parts = <String>[
      if (district.isNotEmpty) district,
      if (cityUf.isNotEmpty) cityUf,
    ];
    return parts.isNotEmpty ? parts.join(', ') : trimmed;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldLight,
        appBar: AppBar(
          title: Text(
            'Carregando Correspondência...',
            style: AppTextStyles.heading2(color: Colors.white),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_foundPet == null) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldLight,
        appBar: AppBar(
          title: Text(
            'Correspondência',
            style: AppTextStyles.heading2(color: Colors.white),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('Anúncio Não Encontrado', style: AppTextStyles.heading2()),
                const SizedBox(height: 8),
                Text(
                  'O anúncio deste pet encontrado não está mais disponível ou foi encerrado pelo autor.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: AppButtonStyles.primary(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Voltar às Notificações'),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final found = _foundPet!;
    final score = _score ?? RecognitionConfig.kSimilarityThreshold;
    final petTitle = found.breed != null && found.breed!.isNotEmpty
        ? found.breed!
        : (found.petType == PetType.dog
              ? 'Cachorro Encontrado'
              : found.petType == PetType.cat
              ? 'Gato Encontrado'
              : 'Pet Encontrado');

    return Scaffold(
      backgroundColor: AppColors.scaffoldLight,
      appBar: AppBar(
        title: Text(
          'Detalhes da Correspondência',
          style: AppTextStyles.heading2(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Principal do Pet Encontrado
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.shade200, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selo de Correspondência
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(color: Colors.purple.shade700),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Correspondência Detectada pela IA',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        SimilarityBadge(
                          score: score,
                          method: MatchMethod.visual,
                        ),
                      ],
                    ),
                  ),

                  // Foto Principal do Pet Encontrado
                  if (found.imageUrl.isNotEmpty)
                    Image.network(
                      found.imageUrl,
                      height: 230,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 180,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, size: 48),
                      ),
                    ),

                  // Resumo do Pet Encontrado + Botão Único Ver Detalhes
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                petTitle,
                                style: AppTextStyles.heading2(),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: found.petType == PetType.dog
                                    ? Colors.blue.withAlpha(35)
                                    : found.petType == PetType.cat
                                    ? Colors.orange.withAlpha(35)
                                    : Colors.purple.withAlpha(35),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                found.petType == PetType.dog
                                    ? 'Cachorro'
                                    : found.petType == PetType.cat
                                    ? 'Gato'
                                    : 'Outro',
                                style: AppTextStyles.label(
                                  color: found.petType == PetType.dog
                                      ? Colors.blue.shade800
                                      : found.petType == PetType.cat
                                      ? Colors.orange.shade800
                                      : Colors.purple.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Local: ${_formatLocationForDisplay(found.foundLocation)}',
                                style: AppTextStyles.body(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Encontrado em: ${_formatDate(found.foundDate)}',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Botão principal: abre todas as fotos, descrição completa e contato LGPD
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: AppButtonStyles.primary(),
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 18,
                            ),
                            label: const Text('Ver Detalhes'),
                            onPressed: () {
                              context.push(
                                '${AppRoutes.publicProfile(found.userId)}?foundId=${found.id}',
                                extra: found,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card de Referência do Seu Pet Perdido
            if (_lostPet != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SEU PET PERDIDO',
                      style: AppTextStyles.sectionHeader(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _lostPet!.imageUrl != null
                              ? Image.network(
                                  _lostPet!.imageUrl!,
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 54,
                                  height: 54,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.pets),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _lostPet!.petName,
                                style: AppTextStyles.heading3(),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_lostPet!.breed ?? 'Sem raça'} • ${_formatLocationForDisplay(_lostPet!.lastLocation)}',
                                style: AppTextStyles.bodySmall(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Ver todas as correspondências',
                          icon: const Icon(
                            Icons.open_in_new,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            context.push(AppRoutes.petMatches(_lostPet!.id));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
