/// Operational Help Request statuses. Independent of flood-forecast labels.
class HelpRequestStatus {
  static const submitted = 'submitted';
  static const helpOnTheWay = 'help_on_the_way';
  static const resolved = 'resolved';
  static const rejected = 'rejected';

  static String normalize(String? raw) {
    if (raw == helpOnTheWay) return helpOnTheWay;
    if (raw == resolved) return resolved;
    if (raw == rejected) return rejected;
    return submitted;
  }

  static String label(String? raw, {required bool isTaglish}) {
    switch (normalize(raw)) {
      case helpOnTheWay:
        return isTaglish ? 'Paparating ang tulong' : 'Help is on the way';
      case resolved:
        return isTaglish ? 'Naresolba' : 'Resolved';
      case rejected:
        return isTaglish ? 'Tinanggihan' : 'Rejected';
      default:
        return isTaglish ? 'Naisumite' : 'Submitted';
    }
  }
}
