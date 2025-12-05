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
  static const _fileCandidates = ['avatar.jpg', 'avatar.jpeg', 'avatar.png'];
  static const _refreshInterval = Duration(seconds: 30);

  static final StreamController<String> _invalidationController =
      StreamController<String>.broadcast();

  late Future<String?> _urlFuture;
  Timer? _refreshTimer;
  StreamSubscription<String>? _invalidateSub;
  String _cacheBuster = _nowCacheBuster();

  static String _nowCacheBuster() =>
      DateTime.now().millisecondsSinceEpoch.toString();

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
        _cacheBuster = _nowCacheBuster();
        _urlFuture = _loadUrl();
      });
    });
  }

  void _listenInvalidations() {
    _invalidateSub?.cancel();
    _invalidateSub = _invalidationController.stream.listen((uid) {
      if (uid != widget.uid) return;
      setState(() {
        _cacheBuster = _nowCacheBuster();
        _urlFuture = _loadUrl();
      });
    });
  }

  Future<FirebaseStorage> _storageForConfiguredBucket() async {
    try {
      final bucket =
          Firebase.apps.isNotEmpty ? Firebase.app().options.storageBucket : null;
      if (bucket != null && bucket.isNotEmpty && !_isSuspiciousBucket(bucket)) {
        return FirebaseStorage.instanceFor(bucket: bucket);
      }

      if (bucket != null && bucket.isNotEmpty && _isSuspiciousBucket(bucket)) {
        debugPrint(
          '[PROFILE-AVATAR] Bucket configurato sospetto ($bucket), uso default instance',
        );
      }
    } catch (_) {
      // Fallback handled below
    }
    return FirebaseStorage.instance;
  }

  bool _isSuspiciousBucket(String bucket) {
    return bucket.contains('.web.app') ||
        bucket.contains('.firebaseapp.com') ||
        bucket.contains('firebasestorage.app');
  }

  Future<String?> _loadUrl() async {
    debugPrint('[PROFILE-AVATAR] _loadUrl start uid=${widget.uid}');
    final storage = await _storageForConfiguredBucket();
    for (final candidate in _fileCandidates) {
      try {
        final ref = storage
            .ref()
            .child(_pathRoot)
            .child(widget.uid)
            .child(candidate);
        final url = await ref.getDownloadURL();
        debugPrint('[PROFILE-AVATAR] found url for ${widget.uid}: $url');
        return url;
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') {
          debugPrint('[PROFILE-AVATAR] download error: ${e.code} - ${e.message}');
          break;
        }
      } catch (e) {
        debugPrint('[PROFILE-AVATAR] generic error: $e');
        break;
      }
    }
    debugPrint('[PROFILE-AVATAR] no avatar found for ${widget.uid}');
    return null;
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
        if (snap.hasError) {
          debugPrint('[PROFILE-AVATAR] load error: ${snap.error}');
        }

        final effectiveUrl = _buildEffectiveUrl(snap.data);

        return ClipOval(
          child: Container(
            width: widget.radius * 2,
            height: widget.radius * 2,
            color: Colors.grey.shade800,
            child: effectiveUrl == null
                ? _buildPlaceholder()
                : Image.network(
                    effectiveUrl,
                    key: ValueKey(effectiveUrl),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.person,
        size: widget.radius,
        color: Colors.white,
      ),
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
