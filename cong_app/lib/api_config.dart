import 'package:flutter/foundation.dart' show kIsWeb;

const String _productionApiUrl = String.fromEnvironment('API_BASE_URL');

String get apiBaseUrl {
  if (_productionApiUrl.isNotEmpty) {
    return _productionApiUrl;
  }
  if (kIsWeb) {
    return Uri.base.origin;
  }
  return 'https://congressional-app-theta.vercel.app';
}

Uri apiUri(String path) => Uri.parse('$apiBaseUrl$path');
