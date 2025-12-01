/// Utilities for working with user role strings stored in Firestore.
///
/// Some existing documents contain additional notes appended to the role value
/// (e.g. "company이게 관리자 계정 정보"). The helpers below normalize such
/// values so that permission checks continue to work even when the stored role
/// string includes extra characters.
String normalizeRole(String? role) {
  final value = role?.toString().trim().toLowerCase();
  if (value == null || value.isEmpty) {
    return 'user';
  }

  if (value.startsWith('admin')) {
    return 'admin';
  }
  if (value.startsWith('corporate')) {
    return 'corporate';
  }
  if (value.startsWith('company')) {
    return 'company';
  }

  return value;
}

bool isCompanyRole(String? role) {
  final normalized = normalizeRole(role);
  return normalized == 'company' ||
      normalized == 'corporate' ||
      normalized == 'admin';
}
