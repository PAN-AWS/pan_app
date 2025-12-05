import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

/// Widget standard per mostrare l'avatar di un utente recuperandolo
/// direttamente dallo storage pubblico.
class ProfileAvatar extends StatefulWidget {
  final String uid;
  final double radius;

  const ProfileAvatar({super.key, required this.uid, this.radius = 20});

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  static const _bucket = 'pan-nativa-progetto.firebasestorage.app';
  static const _pathRoot = 'public_profiles';
  static const _refreshInterval = Duration(seconds: 30);

  late Future<String?> _urlFuture;
  Timer? _refreshTimer;
  String _cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _urlFuture = _loadUrl();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _urlFuture = _loadUrl();
    }
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      setState(() {
        _cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
        _urlFuture = _loadUrl();
      });
    });
  }

  Future<String?> _loadUrl() async {
    try {
      final storage = FirebaseStorage.instanceFor(bucket: _bucket);
      final baseRef = storage.ref().child(_pathRoot).child(widget.uid);
      final avatarRef = baseRef.child('avatar.jpg');

      try {
        return await avatarRef.getDownloadURL();
      } on FirebaseException catch (e) {
        if (e.code == 'object-not-found') {
          final list = await baseRef.list(const ListOptions(maxResults: 1));
          if (list.items.isNotEmpty) {
            return await list.items.first.getDownloadURL();
          }
        }
        debugPrint('[PROFILE-AVATAR] download error: ${e.code} - ${e.message}');
        return null;
      }
    } catch (e) {
      debugPrint('[PROFILE-AVATAR] generic error: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _urlFuture,
      builder: (context, snap) {
        final baseUrl = snap.data;
        final effectiveUrl = (baseUrl != null && baseUrl.isNotEmpty)
            ? '$baseUrl?cb=$_cacheBuster'
            : null;

        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: Colors.grey.shade800,
          foregroundImage:
              effectiveUrl != null ? NetworkImage(effectiveUrl) : null,
        );
      },
    );
  }
}
