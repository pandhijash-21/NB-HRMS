import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_config.dart';
import 'dio_client.dart';

class ApiUrlCubit extends Cubit<String> {
  ApiUrlCubit({required DioClient dioClient})
      : _dio = dioClient,
        super(AppConfig.apiBaseUrl);

  final DioClient _dio;

  bool get isLocal => AppConfig.isLocalUrl(state);

  void setUrl(String url) {
    if (kReleaseMode) return;
    AppConfig.setApiBaseUrl(url);
    _dio.updateBaseUrl(url);
    emit(url);
    unawaited(AppConfig.persistApiBaseUrl(url));
  }

  void toggleLiveLocal() {
    if (kReleaseMode) return;
    final next = isLocal ? AppConfig.liveApiBaseUrl : AppConfig.localApiBaseUrl;
    setUrl(next);
  }
}
