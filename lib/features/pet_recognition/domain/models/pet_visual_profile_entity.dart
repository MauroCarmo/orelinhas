import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../utils/vector_math.dart';
import 'pet_image_analysis_entity.dart';

/// Representa o perfil visual consolidado do pet, incluindo todas as imagens enviadas,
/// seus respectivos estados de análise e o embedding agregado resultante.
class PetVisualProfileEntity {
  final String petId;
  final PetType petType;
  final List<PetImageAnalysisEntity> images;
  final List<double>? aggregatedEmbedding;
  final DateTime? lastAnalyzedAt;

  const PetVisualProfileEntity({
    required this.petId,
    required this.petType,
    this.images = const [],
    this.aggregatedEmbedding,
    this.lastAnalyzedAt,
  });

  /// Retorna se o perfil possui pelo menos uma imagem processada com sucesso.
  bool get hasValidImages => images.any((img) => img.hasValidEmbedding);

  /// Retorna a lista de análises de imagem que possuem embeddings válidos.
  List<PetImageAnalysisEntity> get validImageAnalyses =>
      images.where((img) => img.hasValidEmbedding).toList();

  /// Total de imagens válidas para comparação visual.
  int get validEmbeddingsCount => validImageAnalyses.length;

  /// Retorna se o perfil possui um embedding agregado válido de 768 dimensões.
  bool get hasVisualEmbedding =>
      aggregatedEmbedding != null && aggregatedEmbedding!.length == 768;

  /// Retorna se a espécie do pet é elegível para IA visual (somente cães e gatos).
  bool get isEligibleForVisualAi =>
      petType == PetType.dog || petType == PetType.cat;

  factory PetVisualProfileEntity.fromJson(Map<String, dynamic> json) {
    final petTypeStr = json['pet_type'] as String? ?? 'other';
    final parsedPetType = PetType.values.firstWhere(
      (e) => e.name == petTypeStr,
      orElse: () => PetType.other,
    );

    final imagesJson = json['images'] as List<dynamic>?;

    return PetVisualProfileEntity(
      petId: json['pet_id'] as String? ?? '',
      petType: parsedPetType,
      images: imagesJson != null
          ? imagesJson
              .map((e) =>
                  PetImageAnalysisEntity.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      aggregatedEmbedding: VectorMath.parseEmbedding(json['aggregated_embedding']),
      lastAnalyzedAt: json['last_analyzed_at'] != null
          ? DateTime.parse(json['last_analyzed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pet_id': petId,
      'pet_type': petType.name,
      'images': images.map((e) => e.toJson()).toList(),
      'aggregated_embedding': aggregatedEmbedding,
      'last_analyzed_at': lastAnalyzedAt?.toIso8601String(),
    };
  }

  PetVisualProfileEntity copyWith({
    String? petId,
    PetType? petType,
    List<PetImageAnalysisEntity>? images,
    List<double>? aggregatedEmbedding,
    DateTime? lastAnalyzedAt,
  }) {
    return PetVisualProfileEntity(
      petId: petId ?? this.petId,
      petType: petType ?? this.petType,
      images: images ?? this.images,
      aggregatedEmbedding: aggregatedEmbedding ?? this.aggregatedEmbedding,
      lastAnalyzedAt: lastAnalyzedAt ?? this.lastAnalyzedAt,
    );
  }
}
