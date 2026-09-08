/// FloodGuard Human Name Validator
/// Supports Unicode letters (including Ñ/ñ), spaces, hyphens, periods, and apostrophes.
class NameValidator {
  static final RegExp _nameRegex =
      RegExp(r"^[\p{L}][\p{L}\s.'-]*[\p{L}.]$", unicode: true);

  /// Trims leading/trailing whitespace and collapses repeated internal spaces.
  static String normalize(String? raw) {
    if (raw == null) return '';
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Validates a first name or last name.
  static String? validate(
    String? raw, {
    bool isTaglish = false,
    String? fieldName,
  }) {
    final normalized = normalize(raw);
    final field = fieldName ?? (isTaglish ? 'Pangalan' : 'Name');

    if (normalized.isEmpty) {
      return isTaglish ? 'Kailangan ang $field.' : '$field is required.';
    }

    if (normalized.length < 2 || normalized.length > 60) {
      return isTaglish
          ? 'Dapat 2 hanggang 60 titik ang $field.'
          : '$field must be between 2 and 60 characters.';
    }

    if (!_nameRegex.hasMatch(normalized)) {
      return isTaglish
          ? 'May hindi wastong character ang $field. Mga titik, espasyo, tuldok, kudlit, at gitling lamang ang pinapayagan.'
          : '$field contains invalid characters. Only letters, spaces, hyphens, periods, and apostrophes are allowed.';
    }

    return null;
  }
}
