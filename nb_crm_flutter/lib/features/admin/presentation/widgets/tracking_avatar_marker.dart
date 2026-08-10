import 'package:flutter/material.dart';

/// Map pin: profile photo when available, otherwise a person icon.
class TrackingAvatarMarker extends StatelessWidget {
  const TrackingAvatarMarker({
    super.key,
    this.photoUrl,
    this.size = 40,
    this.borderColor = Colors.blue,
    this.fallbackIcon = Icons.person_rounded,
  });

  final String? photoUrl;
  final double size;
  final Color borderColor;
  final IconData fallbackIcon;

  bool get _hasPhoto =>
      photoUrl != null && photoUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: borderColor,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _hasPhoto
          ? Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _fallback();
              },
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: borderColor,
      child: Icon(
        fallbackIcon,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}
