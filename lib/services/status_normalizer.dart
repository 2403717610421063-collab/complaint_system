String normalizeStatus(String value) {
  final normalized = value.trim().toLowerCase().replaceAll('-', '_');
  switch (normalized) {
    case 'assigned':
      return 'assigned';
    case 'in progress':
    case 'in_progress':
      return 'in_progress';
    case 'resolved':
      return 'resolved';
    default:
      return normalized.replaceAll(' ', '_');
  }
}
