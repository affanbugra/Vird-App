String nameInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  if (name.isEmpty) return '?';
  return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
}
