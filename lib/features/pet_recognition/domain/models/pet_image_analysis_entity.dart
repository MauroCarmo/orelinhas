import '../utils/vector_math.dart';
import 'analysis_status.dart';
import 'bounding_box_entity.dart';

/// Representa a análise visual individual de uma das fotos de um pet.
class PetImageAnalysisEntity {
  final String id;
  final String imageUrl;
  final AnalysisStatus status;
  final List<BoundingBoxEntity> detectedAnimals;
  final BoundingBoxEntity? selectedAnimal;
  final List<double>? embedding; // Vetor de 768 dimensões gerado pelo SigLIP
  final String? errorReason;
  final DateTime? processedAt;

  const PetImageAnalysisEntity({
    required this.id,
    required this.imageUrl,
    this.status = AnalysisStatus.pending,
    this.detectedAnimals = const [],
    this.selectedAnimal,
    this.embedding,
    this.errorReason,
    this.processedAt,
  });

  /// Indica se a imagem foi processada com sucesso e possui embedding válido.
  bool get hasValidEmbedding =>
      status == AnalysisStatus.processed &&
      embedding != null &&
      embedding!.length == 768;

  /// Indica se a imagem detectou mais de um animal e requer seleção de foco.
  bool get hasMultipleAnimals => detectedAnimals.length > 1;

  factory PetImageAnalysisEntity.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String?;
    final detectedJson = json['detected_animals'] as List<dynamic>?;

    return PetImageAnalysisEntity(
      id: json['id'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      status: AnalysisStatus.fromString(statusStr),
      detectedAnimals: detectedJson != null
          ? detectedJson
              .map((e) => BoundingBoxEntity.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      selectedAnimal: json['selected_animal'] != null
          ? BoundingBoxEntity.fromJson(
              json['selected_animal'] as Map<String, dynamic>,
            )
          : null,
      embedding: VectorMath.parseEmbedding(json['embedding']),
      errorReason: json['error_reason'] as String?,
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'status': status.toSnakeCase(),
      'detected_animals': detectedAnimals.map((e) => e.toJson()).toList(),
      'selected_animal': selectedAnimal?.toJson(),
      'embedding': embedding,
      'error_reason': errorReason,
      'processed_at': processedAt?.toIso8601String(),
    };
  }

  PetImageAnalysisEntity copyWith({
    String? id,
    String? imageUrl,
    AnalysisStatus? status,
    List<BoundingBoxEntity>? detectedAnimals,
    BoundingBoxEntity? selectedAnimal,
    List<double>? embedding,
    String? errorReason,
    DateTime? processedAt,
  }) {
    return PetImageAnalysisEntity(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      detectedAnimals: detectedAnimals ?? this.detectedAnimals,
      selectedAnimal: selectedAnimal ?? this.selectedAnimal,
      embedding: embedding ?? this.embedding,
      errorReason: errorReason ?? this.errorReason,
      processedAt: processedAt ?? this.processedAt,
    );
  }
}
