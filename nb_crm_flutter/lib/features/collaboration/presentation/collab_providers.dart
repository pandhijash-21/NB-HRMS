import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/chat_repository.dart';
import '../data/collab_socket.dart';
import '../data/meet_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(dioClient: ref.watch(dioClientProvider));
});

final meetRepositoryProvider = Provider<MeetRepository>((ref) {
  return MeetRepository(dioClient: ref.watch(dioClientProvider));
});

final collabSocketProvider = Provider<CollabSocket>((ref) {
  final socket = CollabSocket();
  ref.onDispose(socket.dispose);
  return socket;
});
