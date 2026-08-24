import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
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

  const PetMatchResultsScreen({super.key, required this.petId});

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

    // 1. Tenta obter do estado local do controller
    final currentAlerts = ref.read(petLostControllerProvider).value;
    if (currentAlerts != null && currentAlerts.isNotEmpty) {
      pet = currentAlerts.where((e) => e.id == widget.petId).firstOrNull;
    }

    // 2. Se não estiver no cache em memória, busca diretamente no repositório
    if (pet == null) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        try {
          final userAlerts =
              await ref.read(petLostRepositoryProvider).getUserAlerts(user.id);
          pet = userAlerts.where((e) => e.id == widget.petId).firstOrNull;
        } catch (_) {}
      }
    }

    if (pet != null && mounted) {
      setState(() {
        _targetPet = pet;
      });
      ref.read(petMatchControllerProvider.notifier).findMatchesForPet(pet: pet);
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

  @override
  Widget build(BuildContext context) {
    final matchState = ref.watch(petMatchControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Possíveis Correspondências'),
      ),
      body: matchState.isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
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
                  // Cabeçalho com o pet pesquisado
                  if (_targetPet != null) _buildQueryPetCard(_targetPet!),
                  const SizedBox(height: 16),

                  // Controle de limiar experimental de similaridade
                  _buildThresholdFilter(matchState),
                  const SizedBox(height: 16),

                  // Aviso de responsabilidade humana
                  _buildHumanVerificationNotice(),
                  const SizedBox(height: 20),

                  // Lista de correspondências
                  Text(
                    'Resultados Encontrados (${matchState.matches.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (matchState.matches.isEmpty)
                    _buildEmptyState()
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: matchState.matches.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final candidate = matchState.matches[index];
                        return _buildMatchCandidateCard(candidate);
                      },
                    ),
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
        borderRadius: BorderRadius.circular(12),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pet.petType == PetType.dog ? 'Cachorro' : pet.petType == PetType.cat ? 'Gato' : 'Outro'} • ${pet.breed ?? 'Sem raça'}',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdFilter(PetMatchState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sensibilidade da Busca',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Text(
                'Mínimo: ${(state.minSimilarityThreshold * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: state.minSimilarityThreshold.clamp(0.50, 0.90),
            min: 0.50,
            max: 0.90,
            divisions: 8,
            activeColor: AppColors.primary,
            label: '${(state.minSimilarityThreshold.clamp(0.50, 0.90) * 100).toStringAsFixed(0)}%',
            onChangeEnd: (val) {
              if (_targetPet != null) {
                ref
                    .read(petMatchControllerProvider.notifier)
                    .updateThreshold(_targetPet!, val);
              }
            },
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }

  Widget _buildHumanVerificationNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
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
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
            'Tente diminuir a sensibilidade no controle acima ou aguarde novos cadastros na rede.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCandidateCard(PetMatchCandidateEntity candidate) {
    final pet = candidate.matchedPet;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagem do pet candidato com badge de similaridade
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                child: pet.imageUrl != null
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
                Text(
                  pet.petName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${pet.breed ?? 'Sem raça'} • Visto em: ${pet.lastLocation}',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                if (pet.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    pet.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chat, size: 16),
                        label: const Text('Contatar Tutor'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => _contactTutor(pet.contact),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person, size: 16),
                      label: const Text('Ver Perfil'),
                      onPressed: () {
                        context.push(AppRoutes.publicProfile(pet.userId));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
