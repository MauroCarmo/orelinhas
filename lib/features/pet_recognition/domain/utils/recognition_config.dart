/// Configuração centralizada dos parâmetros de reconhecimento visual.
///
/// Para alterar o limiar de similaridade, modifique apenas este arquivo.
/// O servidor impõe o mesmo valor via `v_threshold` em `save_match`.
abstract class RecognitionConfig {
  /// Limiar mínimo de similaridade para correspondências (manual e automática).
  /// Valor imposto também no servidor — o cliente não pode reduzi-lo.
  static const double kSimilarityThreshold = 0.70;
}
