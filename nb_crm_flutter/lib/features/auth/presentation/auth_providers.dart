import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/auth_repository.dart';
import 'auth_notifier.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final unauthorizedGateProvider = Provider<UnauthorizedGate>((ref) {
  return UnauthorizedGate();
});

class ApiBaseUrlNotifier extends Notifier<String> {
  @override
  String build() => AppConfig.apiBaseUrl;

  void setUrl(String url) {
    AppConfig.setApiBaseUrl(url);
    state = url;
  }
}

final apiBaseUrlProvider =
    NotifierProvider<ApiBaseUrlNotifier, String>(ApiBaseUrlNotifier.new);

final dioClientProvider = Provider<DioClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final gate = ref.watch(unauthorizedGateProvider);
  final baseUrl = ref.watch(apiBaseUrlProvider);
  return DioClient(
    readToken: storage.readToken,
    unauthorizedGate: gate,
    baseUrl: baseUrl,
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dioClient: ref.watch(dioClientProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
