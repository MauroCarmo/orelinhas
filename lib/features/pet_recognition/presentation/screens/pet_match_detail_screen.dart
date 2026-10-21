import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../pet_found/data/pet_found_repository.dart';
import '../../../pet_found/domain/pet_found_entity.dart';
import '../../../pet_lost/data/pet_lost_repository.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../../data/services/supabase_pet_recognition_service.dart';
import '../../domain/models/pet_match_candidate_entity.dart';
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

    // 1. Carrega dados do pet encontrado
    final found = await foundRepo.getAlertById(widget.foundPetId);

    // 2. Carrega contexto do pet perdido do usuário (se fornecido)
    PetLostAlertEntity? lost;
    if (widget.lostPetId != null && widget.lostPetId!.isNotEmpty) {
      lost = await lostRepo.getAlertById(widget.lostPetId!);
    }

    // 3. Obtém pontuação da correspondência persistida no banco ou usa fallback
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

  Future<void> _contactTutor(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/55$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      final telUri = Uri.parse('tel:$cleanPhone');
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      }
    }
  }

  void _showManualComparisonDialog() {
    final lost = _lostPet;
    final found = _foundPet;
    if (found == null) return;

    final scorePct =
        _score != null ? (_score! * 100).toStringAsFixed(1) : '--';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.compare, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Comparação Visual',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Similaridade calculada por IA: $scorePct%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Seu Pet Perdido',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: lost?.imageUrl != null
                              ? Image.network(
                                  lost!.imageUrl!,
                                  height: 110,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  height: 110,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.pets),
                                ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lost?.petName ?? 'Seu Pet',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Pet Encontrado',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: found.imageUrl.isNotEmpty
                              ? Image.network(
                                  found.imageUrl,
                                  height: 110,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  height: 110,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.pets),
                                ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          found.breed ?? 'Pet Avistado',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Local de avistamento: ${found.foundLocation}',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
          if (found.contact != null && found.contact!.isNotEmpty)
            ElevatedButton.icon(
              icon: const Icon(Icons.chat, size: 14),
              label: const Text('Contatar'),
              onPressed: () {
                Navigator.of(ctx).pop();
                _contactTutor(found.contact!);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carregando Correspondência...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_foundPet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Correspondência')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Anúncio Não Encontrado',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'O anúncio deste pet encontrado não está mais disponível ou foi encerrado pelo autor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
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
    final score = _score ?? 0.70;
    final petTitle = found.breed != null && found.breed!.isNotEmpty
        ? found.breed!
        : (found.petType == PetType.dog
            ? 'Cachorro Encontrado'
            : found.petType == PetType.cat
                ? 'Gato Encontrado'
                : 'Pet Encontrado');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Correspondência'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Principal do Pet Encontrado
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selo de Correspondência
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade700,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Correspondência Encontrada pela IA',
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

                  // Foto do Pet Encontrado
                  if (found.imageUrl.isNotEmpty)
                    Image.network(
                      found.imageUrl,
                      height: 240,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, size: 48),
                      ),
                    ),

                  // Dados do Pet Encontrado
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          petTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 16, color: Colors.grey.shade700),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Visto em: ${found.foundLocation}',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (found.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Descrição do Avistamento:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            found.description,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black87),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Ações de Contato
                        Row(
                          children: [
                            if (found.contact != null &&
                                found.contact!.isNotEmpty)
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.chat, size: 16),
                                  label: const Text('Contatar Quem Encontrou'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                  onPressed: () => _contactTutor(found.contact!),
                                ),
                              ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.person_outline, size: 16),
                              label: const Text('Ver Perfil'),
                              onPressed: () {
                                context.push(
                                  AppRoutes.publicProfile(found.userId),
                                );
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
            const SizedBox(height: 20),

            // Card do Pet Perdido do Tutor (Contexto)
            if (_lostPet != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seu Pet Perdido',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_lostPet!.breed ?? 'Sem raça'} • Desaparecido em ${_lostPet!.lastLocation}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
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
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.compare_arrows, size: 16),
                            label: const Text('Comparar Fotos Lado a Lado'),
                            onPressed: _showManualComparisonDialog,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Ver todas as correspondências',
                          icon: const Icon(Icons.open_in_new),
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
          ],
        ),
      ),
    );
  }
}
