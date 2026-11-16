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
import '../../domain/utils/recognition_config.dart';

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

    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final lost = _lostPet;

    final foundCard = _PetCompareCard(
      label: 'Pet encontrado',
      labelIcon: Icons.check_circle_outline,
      labelColor: AppColors.success,
      imageUrl: found.imageUrl,
      imageHeight: isDesktop ? 300 : 230,
      fillHeight: isDesktop && _lostPet != null,
      title: petTitle,
      tag: switch (found.petType) {
        PetType.dog => 'Cachorro',
        PetType.cat => 'Gato',
        PetType.other => 'Outro',
      },
      infos: [
        (Icons.place_outlined, _formatLocationForDisplay(found.foundLocation)),
        (
          Icons.calendar_month_outlined,
          'Encontrado em ${_formatDate(found.foundDate)}',
        ),
      ],
      action: ElevatedButton.icon(
        icon: const Icon(Icons.visibility_outlined, size: 18),
        label: const Text('Ver detalhes e contato'),
        onPressed: () {
          context.push(
            '${AppRoutes.publicProfile(found.userId)}?foundId=${found.id}',
            extra: found,
          );
        },
      ),
    );

    final lostCard = lost == null
        ? null
        : _PetCompareCard(
            label: 'Seu pet perdido',
            labelIcon: Icons.campaign_outlined,
            labelColor: const Color(0xFFC75A47),
            imageUrl: lost.imageUrl,
            imageHeight: isDesktop ? 300 : 0,
            compact: !isDesktop,
            fillHeight: isDesktop,
            title: lost.petName,
            tag: null,
            infos: [
              (Icons.pets_rounded, lost.breed ?? 'Sem raça'),
              (
                Icons.place_outlined,
                _formatLocationForDisplay(lost.lastLocation),
              ),
            ],
            action: OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('Ver todas as correspondências'),
              onPressed: () {
                context.push(AppRoutes.petMatches(lost.id));
              },
            ),
          );

    final banner = _ScoreBanner(score: score, wide: isDesktop);

    final Widget content;
    if (isDesktop) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          banner,
          const SizedBox(height: 20),
          if (lostCard != null)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: lostCard),
                  const SizedBox(width: 20),
                  Expanded(child: foundCard),
                ],
              ),
            )
          else
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: foundCard,
              ),
            ),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          banner,
          const SizedBox(height: 16),
          foundCard,
          if (lostCard != null) ...[const SizedBox(height: 16), lostCard],
        ],
      );
    }

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
        padding: isDesktop
            ? const EdgeInsets.fromLTRB(40, 8, 40, 36)
            : const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Faixa verde com o percentual de similaridade calculado pela IA.
class _ScoreBanner extends StatelessWidget {
  final double score;
  final bool wide;

  const _ScoreBanner({required this.score, required this.wide});

  @override
  Widget build(BuildContext context) {
    final percentage = (score * 100).toStringAsFixed(1).replaceAll('.', ',');
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.accent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Correspondência detectada pela IA',
                style: AppTextStyles.label(color: AppColors.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Compare as fotos e confira os detalhes antes de entrar em contato.',
          style: AppTextStyles.body(
            color: Colors.white,
          ).copyWith(fontSize: wide ? 16 : 14, height: 1.4),
        ),
      ],
    );

    final scoreBox = Container(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 22 : 14,
        vertical: wide ? 14 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(28),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            '$percentage%',
            style: AppTextStyles.heading1(
              color: Colors.white,
            ).copyWith(fontSize: wide ? 34 : 26, height: 1.1),
          ),
          Text(
            'de similaridade',
            style: AppTextStyles.bodySmall(color: AppColors.accent),
          ),
        ],
      ),
    );

    return Container(
      padding: EdgeInsets.all(wide ? 26 : 18),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(child: texts),
          SizedBox(width: wide ? 24 : 12),
          scoreBox,
        ],
      ),
    );
  }
}

/// Cartão de um dos pets da comparação (perdido ou encontrado).
class _PetCompareCard extends StatelessWidget {
  final String label;
  final IconData labelIcon;
  final Color labelColor;
  final String? imageUrl;
  final double imageHeight;
  final bool compact;
  final bool fillHeight;
  final String title;
  final String? tag;
  final List<(IconData, String)> infos;
  final Widget action;

  const _PetCompareCard({
    required this.label,
    required this.labelIcon,
    required this.labelColor,
    required this.imageUrl,
    required this.imageHeight,
    required this.title,
    required this.tag,
    required this.infos,
    required this.action,
    this.compact = false,
    this.fillHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        Icon(labelIcon, size: 17, color: labelColor),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.label(color: labelColor)),
      ],
    );

    final titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: compact
                ? AppTextStyles.heading3()
                : AppTextStyles.heading2(),
          ),
        ),
        if (tag != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tag!,
              style: AppTextStyles.label(color: AppColors.primary),
            ),
          ),
      ],
    );

    final infoRows = [
      for (final (icon, text) in infos)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 17, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
    ];

    final decoration = BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.border),
    );

    if (compact) {
      // Celular: versão em linha, com foto pequena
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 12),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox.square(
                    dimension: 72,
                    child: PetImage(url: imageUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [titleRow, ...infoRows],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            action,
          ],
        ),
      );
    }

    return Container(
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: header,
          ),
          // Lado a lado as fotos sempre aparecem, para manter o alinhamento
          if (fillHeight || (imageUrl ?? '').isNotEmpty)
            SizedBox(
              height: imageHeight,
              child: PetImage(url: imageUrl),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titleRow, const SizedBox(height: 4), ...infoRows],
            ),
          ),
          // Lado a lado: botão alinhado no fim do cartão
          if (fillHeight) const Spacer(),
          Padding(padding: const EdgeInsets.all(18), child: action),
        ],
      ),
    );
  }
}
