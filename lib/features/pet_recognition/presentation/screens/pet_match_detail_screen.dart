import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../pet_found/data/pet_found_repository.dart';
import '../../../pet_found/domain/pet_found_entity.dart';
import '../../../pet_lost/data/pet_lost_repository.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../../../pet_lost/presentation/widgets/pet_widgets.dart';
import '../../data/services/supabase_pet_recognition_service.dart';
import '../../domain/models/pet_match_candidate_entity.dart';
import '../../domain/utils/recognition_config.dart';
import '../widgets/similarity_badge.dart';

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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            tooltip: 'Voltar',
            onPressed: () => context.pop(),
          ),
          title: const Text('Correspondência'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_foundPet == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            tooltip: 'Voltar',
            onPressed: () => context.pop(),
          ),
          title: const Text('Correspondência'),
        ),
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Anúncio não encontrado',
          message:
              'O anúncio deste pet encontrado não está mais disponível ou foi encerrado pelo autor.',
          actionLabel: 'Voltar',
          onAction: () => context.pop(),
        ),
      );
    }

    final found = _foundPet!;
    final score = _score ?? RecognitionConfig.kSimilarityThreshold;
    final petTitle = found.breed != null && found.breed!.isNotEmpty
        ? found.breed!
        : switch (found.petType) {
            PetType.dog => 'Cachorro Encontrado',
            PetType.cat => 'Gato Encontrado',
            PetType.other => 'Pet Encontrado',
          };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Voltar',
          onPressed: () => context.pop(),
        ),
        title: const Text('Detalhes da correspondência'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    color: AppColors.primarySoft,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Correspondência detectada pela IA',
                            style: AppTextStyles.label(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        SimilarityBadge(
                          score: score,
                          method: MatchMethod.visual,
                        ),
                      ],
                    ),
                  ),
                  if (found.imageUrl.isNotEmpty)
                    SizedBox(
                      height: 240,
                      width: double.infinity,
                      child: PetImage(url: found.imageUrl),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(18),
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
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                switch (found.petType) {
                                  PetType.dog => 'Cachorro',
                                  PetType.cat => 'Gato',
                                  PetType.other => 'Outro',
                                },
                                style: AppTextStyles.label(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 18,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _formatLocationForDisplay(found.foundLocation),
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
                              Icons.calendar_month_outlined,
                              size: 17,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Encontrado em ${_formatDate(found.foundDate)}',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('Ver detalhes e contato'),
                          onPressed: () {
                            context.push(
                              '${AppRoutes.publicProfile(found.userId)}?foundId=${found.id}',
                              extra: found,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_lostPet != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seu pet perdido',
                      style: AppTextStyles.sectionHeader(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox.square(
                            dimension: 56,
                            child: PetImage(url: _lostPet!.imageUrl),
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
                                style: AppTextStyles.bodySmall(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Ver todas as correspondências',
                          icon: const Icon(
                            Icons.chevron_right_rounded,
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
