import 'recording_player_io.dart' if (dart.library.html) 'recording_player_web.dart' as impl;

import 'package:flutter/material.dart';

Widget meetingRecordingPlayer(String url) => impl.meetingRecordingPlayer(url);
