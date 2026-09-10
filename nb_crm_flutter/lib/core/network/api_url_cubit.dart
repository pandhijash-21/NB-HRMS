import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_config.dart';
import 'dio_client.dart';

class ApiUrlCubit extends Cubit<String> {
  ApiUrlCubit({required DioClient dioClient})
      : _dio = dioClient,
        super(AppConfig.apiBaseUrl);

  final DioClient _dio;

  void setUrl(String url) {
    if (kReleaseMode) return;
    AppConfig.setApiBaseUrl(url);
    _dio.updateBaseUrl(url);
    emit(url);
  }

  void toggleLiveLocal() {
    if (kReleaseMode) return;
    final isLocal = state.contains('127.0.0.1') || state.contains('localhost');
    final next = isLocal ? AppConfig.liveApiBaseUrl : AppConfig.localApiBaseUrl;
    setUrl(next);
  }
}
