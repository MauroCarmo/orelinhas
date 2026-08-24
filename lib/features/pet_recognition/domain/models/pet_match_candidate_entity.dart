import '../../../pet_lost/domain/pet_lost_entity.dart';
import 'pet_visual_profile_entity.dart';

/// Método utilizado para encontrar a correspondência.
enum MatchMethod {
  /// Baseado em busca visual híbrida (SigLIP embeddings + características).
  visual,

  /// Baseado puramente em atributos cadastrais estruturados (outras espécies ou sem foto válida).
  cadastral;

  String get name => toString().split('.').last;
}

/// Nível de confiança qualitativo para apresentação amigável ao usuário.
enum MatchConfidenceLevel {
  high,
  medium,
  low;

  String get label {
    switch (this) {
      case MatchConfidenceLevel.high:
        return 'Alta Similaridade';
      case MatchConfidenceLevel.medium:
        return 'Média Similaridade';
      case MatchConfidenceLevel.low:
        return 'Possível Similaridade';
    }
  }
}

/// Representa um candidato a match entre um pet desaparecido e outro pet registrado.
class PetMatchCandidateEntity {
  final PetLostAlertEntity matchedPet;
  final PetVisualProfileEntity? visualProfile;
  final double similarityScore; // 0.0 a 1.0 (ou 0% a 100%)
  final MatchMethod matchMethod;
  final List<double> individualImageScores; // Scores detalhados de cada foto comparada
  final String? matchingDetails;

  const PetMatchCandidateEntity({
    required this.matchedPet,
    this.visualProfile,
    required this.similarityScore,
    required this.matchMethod,
    this.individualImageScores = const [],
    this.matchingDetails,
  });

  /// Retorna o nível de confiança visual ou cadastral.
  MatchConfidenceLevel get confidenceLevel {
    if (similarityScore >= 0.82) {
      return MatchConfidenceLevel.high;
    } else if (similarityScore >= 0.70) {
      return MatchConfidenceLevel.medium;
    } else {
      return MatchConfidenceLevel.low;
    }
  }

  /// Porcentagem formatada (ex: "87.4%").
  String get scorePercentageText =>
      '${(similarityScore * 100).toStringAsFixed(1)}%';
}
