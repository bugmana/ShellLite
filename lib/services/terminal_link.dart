/// Resolves an explicitly selected web address without changing its query.
Uri? terminalLink(String text) {
  final value = text.trim();
  if (RegExp(r'\s').hasMatch(value)) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !const ['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    return null;
  }
  return uri;
}
