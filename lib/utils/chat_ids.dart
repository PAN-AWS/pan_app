import 'dart:convert';

String dmChatIdFor(String a, String b) {
  final sorted = [a, b]..sort();
  return 'dm_${_safeId(sorted[0])}_${_safeId(sorted[1])}';
}

String _safeId(String raw) {
  if (!raw.contains('/')) {
    return raw;
  }
  return base64Url.encode(utf8.encode(raw));
}
