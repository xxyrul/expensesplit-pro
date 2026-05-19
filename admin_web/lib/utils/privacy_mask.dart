/// Shared email masking for admin views (privacy_settings.maskSensitiveData).
String maskEmailIfEnabled(String email, bool mask) {
  if (!mask || email.isEmpty || email == 'Unknown Email') return email;
  final parts = email.split('@');
  if (parts.length != 2) return email;
  final name = parts[0];
  final domain = parts[1];
  if (name.length <= 2) return '${name[0]}***@$domain';
  return '${name.substring(0, 2)}***@$domain';
}
