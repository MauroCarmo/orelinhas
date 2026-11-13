import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/app_button_styles.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../pet_lost/data/pet_lost_repository.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../../../pet_lost/presentation/controllers/pet_lost_controller.dart';
import '../../domain/models/pet_match_candidate_entity.dart';
import '../controllers/pet_match_controller.dart';
import '../widgets/similarity_badge.dart';

/// Tela de exibição das possíveis correspondências visuais e cadastrais de um pet.
class PetMatchResultsScreen extends ConsumerStatefulWidget {
  final String petId;
  final String? initialHighlightPetId;

  const PetMatchResultsScreen({
    super.key,
    required this.petId,
    this.initialHighlightPetId,
  });

  @override
  ConsumerState<PetMatchResultsScreen> createState() =>
      _PetMatchResultsScreenState();
}

class _PetMatchResultsScreenState extends ConsumerState<PetMatchResultsScreen> {
  PetLostAlertEntity? _targetPet;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMatches();
    });
  }

  Future<void> _loadMatches() async {
    PetLostAlertEntity? pet;

    final currentAlerts = ref.read(petLostControllerProvider).value;
    if (currentAlerts != null && currentAlerts.isNotEmpty) {
      pet = currentAlerts.where((e) => e.id == widget.petId).firstOrNull;
    }

    if (pet == null) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        try {
          final userAlerts = await ref
              .read(petLostRepositoryProvider)
              .getUserAlerts(user.id);
          pet = userAlerts.where((e) => e.id == widget.petId).firstOrNull;
        } catch (_) {}
      }
    }

    if (pet != null && mounted) {
      setState(() {
        _targetPet = pet;
      });
      ref.read(petMatchControllerProvider.notifier).loadPersistedMatches(pet);
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
    final matchState = ref.watch(petMatchControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldLight,
      appBar: AppBar(
        title: Text(
          'Possíveis Correspondências',
          style: AppTextStyles.heading2(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: matchState.isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Buscando e refinando correspondências com IA...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_targetPet != null) _buildQueryPetCard(_targetPet!),
                  const SizedBox(height: 16),

                  _buildNewSearchButton(matchState),
                  const SizedBox(height: 16),

                  _buildHumanVerificationNotice(),
                  const SizedBox(height: 20),

                  Text(
                    'Resultados Encontrados (${matchState.matches.length})',
                    style: AppTextStyles.heading3(),
                  ),
                  const SizedBox(height: 12),

                  if (matchState.matches.isEmpty)
                    _buildEmptyState()
                  else ...[
                    if (widget.initialHighlightPetId != null &&
                        matchState.matches.any(
                          (m) =>
                              m.matchedPet.id == widget.initialHighlightPetId,
                        ))
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.stars,
                              color: Colors.purple.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Exibindo em destaque a correspondência que gerou a notificação.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _getSortedMatches(matchState.matches).length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final candidate = _getSortedMatches(
                          matchState.matches,
                        )[index];
                        return _buildMatchCandidateCard(candidate);
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildQueryPetCard(PetLostAlertEntity pet) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: pet.imageUrl != null
                ? Image.network(
                    pet.imageUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.pets),
                    ),
                  )
                : Container(
                    width: 60,
                    height: 60,
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
                  'Buscando para: ${pet.petName}',
                  style: AppTextStyles.heading3(),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pet.petType == PetType.dog
                      ? 'Cachorro'
                      : pet.petType == PetType.cat
                      ? 'Gato'
                      : 'Outro'} • ${pet.breed ?? 'Sem raça'}',
                  style: AppTextStyles.bodySmall(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewSearchButton(PetMatchState state) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: AppButtonStyles.outlined(),
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Executar Nova Busca Ativa'),
        onPressed: state.isLoading || _targetPet == null
            ? null
            : () {
                ref
                    .read(petMatchControllerProvider.notifier)
                    .runNewSearch(pet: _targetPet!);
              },
      ),
    );
  }

  Widget _buildHumanVerificationNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'O reconhecimento visual aponta possíveis correspondências para análise humana. O sistema nunca confirma ou encerra alertas automaticamente.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'Nenhuma correspondência com a similaridade mínima.',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Aguarde novos cadastros na rede ou execute uma nova busca mais tarde.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<PetMatchCandidateEntity> _getSortedMatches(
    List<PetMatchCandidateEntity> matches,
  ) {
    if (widget.initialHighlightPetId == null ||
        widget.initialHighlightPetId!.isEmpty) {
      return matches;
    }
    final highlighted = matches
        .where((m) => m.matchedPet.id == widget.initialHighlightPetId)
        .toList();
    final others = matches
        .where((m) => m.matchedPet.id != widget.initialHighlightPetId)
        .toList();
    return [...highlighted, ...others];
  }

  Widget _buildMatchCandidateCard(PetMatchCandidateEntity candidate) {
    final pet = candidate.matchedPet;
    final isHighlighted =
        widget.initialHighlightPetId != null &&
        widget.initialHighlightPetId == pet.id;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? Colors.purple.shade600 : AppColors.border,
          width: isHighlighted ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? Colors.purple.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isHighlighted ? 10 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isHighlighted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(color: Colors.purple.shade700),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Correspondência desta notificação',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          Stack(
            children: [
              pet.imageUrl != null && pet.imageUrl!.isNotEmpty
                  ? Image.network(
                      pet.imageUrl!,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 190,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, size: 40),
                      ),
                    )
                  : Container(
                      height: 190,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.pets, size: 40),
                    ),
              Positioned(
                top: 10,
                right: 10,
                child: SimilarityBadge(
                  score: candidate.similarityScore,
                  method: candidate.matchMethod,
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pet.petName, style: AppTextStyles.heading3()),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Local: ${_formatLocationForDisplay(pet.lastLocation)}',
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Encontrado em: ${_formatDate(pet.lostDate)}',
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: AppButtonStyles.primary(),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Ver Detalhes'),
                    onPressed: () {
                      context.push(
                        '${AppRoutes.publicProfile(pet.userId)}?foundId=${pet.id}',
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
