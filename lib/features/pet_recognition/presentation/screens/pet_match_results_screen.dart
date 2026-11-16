import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../pet_lost/data/pet_lost_repository.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../../../pet_lost/presentation/controllers/pet_lost_controller.dart';
import '../../../pet_lost/presentation/widgets/pet_widgets.dart';
import '../../domain/models/pet_match_candidate_entity.dart';
import '../controllers/pet_match_controller.dart';
import '../widgets/similarity_badge.dart';

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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Voltar',
          onPressed: () => context.pop(),
        ),
        title: const Text('Possíveis correspondências'),
      ),
      body: matchState.isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Buscando correspondências com IA...'),
                ],
              ),
            )
          : _buildBody(context, matchState),
    );
  }

  Widget _buildBody(BuildContext context, PetMatchState matchState) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final matches = matchState.matches;
    final sorted = _getSortedMatches(matches);

    // Pet buscado, nova busca e aviso de análise humana
    final searchPanel = <Widget>[
      if (_targetPet != null) _buildQueryPetCard(_targetPet!),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Executar nova busca ativa'),
        onPressed: matchState.isLoading || _targetPet == null
            ? null
            : () {
                ref
                    .read(petMatchControllerProvider.notifier)
                    .runNewSearch(pet: _targetPet!);
              },
      ),
      const SizedBox(height: 14),
      _buildHumanVerificationNotice(),
    ];

    final highlightBanner =
        widget.initialHighlightPetId != null &&
            matches.any((m) => m.matchedPet.id == widget.initialHighlightPetId)
        ? Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
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
                    'Exibindo em destaque a correspondência que gerou a notificação.',
                    style: AppTextStyles.bodySmall(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          )
        : null;

    final results = <Widget>[
      Text(
        'Resultados encontrados (${matches.length})',
        style: AppTextStyles.sectionHeader().copyWith(fontSize: 18),
      ),
      const SizedBox(height: 12),
      if (matches.isEmpty)
        const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Nenhuma correspondência encontrada',
          message:
              'Aguarde novos cadastros na rede ou execute uma nova busca mais tarde.',
        )
      else ...[
        ?highlightBanner,
        LayoutBuilder(
          builder: (context, constraints) {
            // 2 colunas quando há espaço (PC), 1 no celular
            final columns = constraints.maxWidth >= 640 ? 2 : 1;
            const gap = 14.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final c in sorted)
                  SizedBox(width: width, child: _buildMatchCandidateCard(c)),
              ],
            );
          },
        ),
      ],
    ];

    if (isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 8, 40, 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 340,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: searchPanel,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: results,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [...searchPanel, const SizedBox(height: 22), ...results],
      ),
    );
  }

  Widget _buildQueryPetCard(PetLostAlertEntity pet) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox.square(
              dimension: 60,
              child: PetImage(url: pet.imageUrl),
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
                  '${switch (pet.petType) {
                    PetType.dog => 'Cachorro',
                    PetType.cat => 'Gato',
                    PetType.other => 'Outro',
                  }} • ${pet.breed ?? 'Sem raça'}',
                  style: AppTextStyles.bodySmall(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHumanVerificationNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'O reconhecimento visual aponta possíveis correspondências para análise humana. O sistema nunca confirma ou encerra alertas automaticamente.',
              style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
            ),
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
        borderRadius: BorderRadius.circular(20),
        border: isHighlighted
            ? Border.all(color: AppColors.primary, width: 1.8)
            : Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isHighlighted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              color: AppColors.primarySoft,
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Correspondência desta notificação',
                    style: AppTextStyles.label(color: AppColors.primary),
                  ),
                ],
              ),
            ),
          Stack(
            children: [
              SizedBox(
                height: 195,
                width: double.infinity,
                child: PetImage(url: pet.imageUrl),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pet.petName, style: AppTextStyles.heading3()),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatLocationForDisplay(pet.lastLocation),
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
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Encontrado em ${_formatDate(pet.lostDate)}',
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Ver detalhes'),
                  onPressed: () {
                    context.push(
                      '${AppRoutes.publicProfile(pet.userId)}?foundId=${pet.id}',
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
