// lib/utils/web_open_web.dart
// Solo Web: apertura URL affidabile (stessa scheda o nuova scheda)
import 'dart:html' as html;

void openUrlSameTab(String url) {
  // Navigazione nella stessa scheda: meno soggetta a popup blocker
  html.window.location.assign(url);
}

void openUrlNewTab(String url) {
  // Apertura in nuova scheda. Creiamo un <a> e simuliamo il click.
  final a = html.AnchorElement(href: url)
    ..target = '_blank'
    ..rel = 'noopener';
  html.document.body?.append(a);
  a.click();
  a.remove();
}
