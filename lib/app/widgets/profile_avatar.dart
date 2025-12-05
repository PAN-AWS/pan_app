import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

/// Widget standard per mostrare l'avatar di un utente recuperandolo
/// direttamente dallo storage pubblico.
class ProfileAvatar extends StatefulWidget {
  final String uid;
  final double radius;

  const ProfileAvatar({super.key, required this.uid, this.radius = 20});

  static void invalidate(String uid) {
    _ProfileAvatarState.invalidate(uid);
  }

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  static const _pathRoot = 'public_profiles';
  static const _refreshInterval = Duration(seconds: 30);
  static const _standardExtension = 'png';

  static final StreamController<String> _invalidationController =
      StreamController<String>.broadcast();

  late Future<String?> _urlFuture;
  Timer? _refreshTimer;
  StreamSubscription<String>? _invalidateSub;
  String _cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();

  static void invalidate(String uid) {
    if (!_invalidationController.isClosed) {
      _invalidationController.add(uid);
    }
  }

  @override
  void initState() {
    super.initState();
    _urlFuture = _loadUrl();
    _startTimer();
    _listenInvalidations();
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

  void _listenInvalidations() {
    _invalidateSub?.cancel();
    _invalidateSub = _invalidationController.stream.listen((uid) {
      if (uid != widget.uid) return;
      setState(() {
        _cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
        _urlFuture = _loadUrl();
      });
    });
  }

  Future<FirebaseStorage> _storageForConfiguredBucket() async {
    try {
      final bucket =
          Firebase.apps.isNotEmpty ? Firebase.app().options.storageBucket : null;
      if (bucket != null && bucket.isNotEmpty) {
        return FirebaseStorage.instanceFor(bucket: bucket);
      }
    } catch (_) {
      // Fallback handled below
    }
    return FirebaseStorage.instance;
  }

  Future<String?> _loadUrl() async {
    try {
      final storage = await _storageForConfiguredBucket();
      final baseRef = storage.ref().child(_pathRoot).child(widget.uid);

      final attempts = _buildAttemptList();
      for (final ext in attempts) {
        try {
          final url = await baseRef.child('avatar.$ext').getDownloadURL();
          return url;
        } on FirebaseException catch (e) {
          if (e.code != 'object-not-found') {
            debugPrint('[PROFILE-AVATAR] download error: ${e.code} - ${e.message}');
          }
        }
      }

      final list = await baseRef.listAll();
      for (final item in list.items) {
        if (_looksLikeImage(item.name)) {
          try {
            return await item.getDownloadURL();
          } on FirebaseException catch (e) {
            debugPrint('[PROFILE-AVATAR] list download error: ${e.code}');
          }
        }
      }
    } catch (e) {
      debugPrint('[PROFILE-AVATAR] generic error: $e');
      return null;
    }
    return null;
  }

  List<String> _buildAttemptList() {
    final seen = <String>{};
    final ordered = [_standardExtension, 'jpg', 'jpeg', 'png'];
    final result = <String>[];
    for (final ext in ordered) {
      if (seen.add(ext)) result.add(ext);
    }
    return result;
  }

  bool _looksLikeImage(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _invalidateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _urlFuture,
      builder: (context, snap) {
        final effectiveUrl = _buildEffectiveUrl(snap.data);

        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: Colors.grey.shade800,
          foregroundImage:
              effectiveUrl != null ? NetworkImage(effectiveUrl) : null,
          child: effectiveUrl == null
              ? Icon(
                  Icons.person,
                  size: widget.radius,
                  color: Colors.white,
                )
              : null,
        );
      },
    );
  }

  String? _buildEffectiveUrl(String? baseUrl) {
    if (baseUrl == null || baseUrl.isEmpty) return null;

    final uri = Uri.parse(baseUrl);
    final query = Map<String, String>.from(uri.queryParameters);
    query['cb'] = _cacheBuster;

    return uri.replace(queryParameters: query).toString();
  }
}
