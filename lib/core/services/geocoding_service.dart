import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../logger/app_logger.dart';
import '../validation/sanitizers.dart';

final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService();
});

class GeocodingAddressResult {
  final String? cep;
  final String? street;
  final String? district;
  final String? city;
  final String? stateUf;
  final LatLng? coordinates;

  const GeocodingAddressResult({
    this.cep,
    this.street,
    this.district,
    this.city,
    this.stateUf,
    this.coordinates,
  });
}

class GeocodingService {
  final _logger = AppLogger.category('GeocodingService');
  final http.Client _httpClient;

  static const Map<String, String> _stateNameToUf = {
    'acre': 'AC',
    'alagoas': 'AL',
    'amapa': 'AP',
    'amazonas': 'AM',
    'bahia': 'BA',
    'ceara': 'CE',
    'distrito federal': 'DF',
    'espirito santo': 'ES',
    'goias': 'GO',
    'maranhao': 'MA',
    'mato grosso': 'MT',
    'mato grosso do sul': 'MS',
    'minas gerais': 'MG',
    'para': 'PA',
    'paraiba': 'PB',
    'parana': 'PR',
    'pernambuco': 'PE',
    'piaui': 'PI',
    'rio de janeiro': 'RJ',
    'rio grande do norte': 'RN',
    'rio grande do sul': 'RS',
    'rondonia': 'RO',
    'roraima': 'RR',
    'santa catarina': 'SC',
    'sao paulo': 'SP',
    'sergipe': 'SE',
    'tocantins': 'TO',
  };

  GeocodingService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  Map<String, String> get _headers => const {
    'User-Agent': 'OrelinhasPetFinderApp/1.0 (tcc-academic-project)',
    'Accept-Language': 'pt-BR,pt;q=0.9',
  };

  String? _normalizeStateToUf(String? rawState) {
    if (rawState == null || rawState.trim().isEmpty) return null;
    final trimmed = rawState.trim();
    if (trimmed.length == 2) return trimmed.toUpperCase();

    final normalized = trimmed
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');

    return _stateNameToUf[normalized];
  }

  /// Geocodificação direta: converte endereço/CEP em coordenadas (LatLng).
  Future<LatLng?> forwardGeocode({
    String? street,
    String? district,
    String? city,
    String? stateUf,
    String? cep,
  }) async {
    final queries = <String>[];

    final fullParts = [
      if (street != null && street.trim().isNotEmpty) street.trim(),
      if (district != null && district.trim().isNotEmpty) district.trim(),
      if (city != null && city.trim().isNotEmpty) city.trim(),
      if (stateUf != null && stateUf.trim().isNotEmpty) stateUf.trim(),
      'Brasil',
    ];
    if (fullParts.length > 2) {
      queries.add(fullParts.join(', '));
    }

    final cleanCep = cep != null ? AppSanitizers.digitsOnly(cep) : '';
    if (cleanCep.length == 8) {
      queries.add(
        '${cleanCep.substring(0, 5)}-${cleanCep.substring(5)}, Brasil',
      );
    }

    final cityStateParts = [
      if (city != null && city.trim().isNotEmpty) city.trim(),
      if (stateUf != null && stateUf.trim().isNotEmpty) stateUf.trim(),
      'Brasil',
    ];
    if (cityStateParts.length >= 2) {
      final fallback = cityStateParts.join(', ');
      if (!queries.contains(fallback)) queries.add(fallback);
    }

    for (final q in queries) {
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': q,
          'format': 'json',
          'limit': '1',
          'countrycodes': 'br',
        });

        final response = await _httpClient
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final list = json.decode(response.body) as List<dynamic>;
          if (list.isNotEmpty) {
            final first = list.first as Map<String, dynamic>;
            final lat = double.tryParse(first['lat']?.toString() ?? '');
            final lon = double.tryParse(first['lon']?.toString() ?? '');
            if (lat != null && lon != null) {
              return LatLng(lat, lon);
            }
          }
        }
      } catch (e) {
        _logger.w(
          'Falha pontual na geocodificação direta para "$q".',
          error: e,
        );
      }
    }

    return null;
  }

  /// Geocodificação reversa: converte coordenadas (LatLng) em campos de endereço.
  Future<GeocodingAddressResult?> reverseGeocode(LatLng point) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'format': 'json',
        'addressdetails': '1',
      });

      final response = await _httpClient
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>?;
      if (addr == null) return null;

      final rawPostcode = addr['postcode'] as String?;
      final cleanCep = rawPostcode != null
          ? AppSanitizers.digitsOnly(rawPostcode)
          : '';
      final formattedCep = cleanCep.length == 8
          ? '${cleanCep.substring(0, 5)}-${cleanCep.substring(5)}'
          : null;

      final street =
          (addr['road'] ??
                  addr['pedestrian'] ??
                  addr['footway'] ??
                  addr['residential'])
              ?.toString();

      final district =
          (addr['suburb'] ??
                  addr['neighbourhood'] ??
                  addr['quarter'] ??
                  addr['city_district'])
              ?.toString();

      final city =
          (addr['city'] ??
                  addr['town'] ??
                  addr['village'] ??
                  addr['municipality'])
              ?.toString();

      final uf = _normalizeStateToUf(
        (addr['state_code'] ?? addr['state'])?.toString(),
      );

      return GeocodingAddressResult(
        cep: formattedCep,
        street: street,
        district: district,
        city: city,
        stateUf: uf,
        coordinates: point,
      );
    } catch (e) {
      _logger.w('Falha na geocodificação reversa.', error: e);
      return null;
    }
  }
}
