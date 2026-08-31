import 'package:flutter/material.dart';

/// Meet-wide icon set. Rounded glyphs + a keep-alive list so Flutter web
/// does not tree-shake these out of MaterialIcons.
abstract final class MeetIcons {
  static const back = Icons.arrow_back_rounded;
  static const videocam = Icons.videocam_rounded;
  static const videocamOff = Icons.videocam_off_rounded;
  static const mic = Icons.mic_rounded;
  static const micOff = Icons.mic_off_rounded;
  static const screenShare = Icons.screen_share_rounded;
  static const stopScreenShare = Icons.stop_screen_share_rounded;
  static const chat = Icons.chat_bubble_rounded;
  static const record = Icons.radio_button_checked_rounded;
  static const callEnd = Icons.call_end_rounded;
  static const link = Icons.link_rounded;
  static const send = Icons.send_rounded;
  static const close = Icons.close_rounded;
  static const waiting = Icons.hourglass_top_rounded;
  static const pin = Icons.pin_rounded;
  static const login = Icons.login_rounded;
  static const schedule = Icons.event_available_rounded;
  static const calendar = Icons.calendar_month_rounded;
  static const history = Icons.history_rounded;
  static const notes = Icons.notes_rounded;
  static const title = Icons.title_rounded;
  static const event = Icons.event_rounded;
  static const time = Icons.schedule_rounded;
  static const people = Icons.people_rounded;
  static const personAdd = Icons.group_add_rounded;
  static const chevron = Icons.chevron_right_rounded;
  static const search = Icons.search_rounded;
  static const refresh = Icons.refresh_rounded;
  static const copy = Icons.copy_rounded;
  static const play = Icons.play_circle_rounded;
  static const info = Icons.info_outline_rounded;
  static const delete = Icons.delete_outline_rounded;
  static const open = Icons.open_in_new_rounded;
  static const check = Icons.check_rounded;
  static const deny = Icons.close_rounded;
  static const admit = Icons.check_circle_rounded;
  static const person = Icons.person_rounded;
  static const flag = Icons.flag_rounded;
  static const timer = Icons.timer_rounded;
  static const radioOn = Icons.radio_button_checked_rounded;
  static const radioOff = Icons.radio_button_unchecked_rounded;
  static const expandMore = Icons.expand_more_rounded;
  static const expandLess = Icons.expand_less_rounded;
  static const done = Icons.check_circle_rounded;
  static const skip = Icons.remove_circle_outline_rounded;
  static const error = Icons.error_rounded;
  static const forward = Icons.arrow_forward_rounded;

  static const keepAlive = <IconData>[
    back,
    videocam,
    videocamOff,
    mic,
    micOff,
    screenShare,
    stopScreenShare,
    chat,
    record,
    callEnd,
    link,
    send,
    close,
    waiting,
    pin,
    login,
    schedule,
    calendar,
    history,
    notes,
    title,
    event,
    time,
    people,
    personAdd,
    chevron,
    search,
    refresh,
    copy,
    play,
    info,
    delete,
    open,
    check,
    deny,
    admit,
    person,
    flag,
    timer,
    radioOn,
    radioOff,
    expandMore,
    expandLess,
    done,
    skip,
    error,
    forward,
  ];
}

/// Zero-size icons so the Material font retains every Meet glyph on web.
class MeetIconKeepAlive extends StatelessWidget {
  const MeetIconKeepAlive({super.key});

  @override
  Widget build(BuildContext context) {
    return Offstage(
      child: Row(
        children: [
          for (final icon in MeetIcons.keepAlive) Icon(icon, size: 0.01),
        ],
      ),
    );
  }
}
