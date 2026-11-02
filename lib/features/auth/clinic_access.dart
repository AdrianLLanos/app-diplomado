import 'package:flutter/material.dart';

/// Permissions come from Supabase, never from a role selected by the user.
class ClinicAccess {
  ClinicAccess({required this.role, required Iterable<String> permissions})
    : permissions = Set<String>.unmodifiable(permissions);

  final String role;
  final Set<String> permissions;

  bool get isAdministrator => role == 'admin';
  bool get isDentist => role == 'doctor';
  bool get hasPanelAccess => isAdministrator || isDentist;

  bool can(String resource, String action) =>
      hasPanelAccess &&
      (isAdministrator ||
          permissions.contains('${_resource(resource)}.$action'));

  static String _resource(String resource) =>
      const {
        'doctores': 'medicos',
        'horarios_doctores': 'horarios',
      }[resource] ??
      resource;

  factory ClinicAccess.fromApi(Map<String, dynamic> user) {
    final roles = (user['roles'] as List? ?? []).whereType<String>();
    return ClinicAccess(
      role: roles.contains('Super Admin')
          ? 'admin'
          : roles.contains('Doctor')
          ? 'doctor'
          : '',
      permissions: (user['permissions'] as List? ?? []).whereType<String>(),
    );
  }

  bool canOpenArea(String area) =>
      isAdministrator || (isDentist && area == 'odontologo');

  factory ClinicAccess.fromMap(Map<String, dynamic> data) => ClinicAccess(
    role: data['rol'] as String? ?? '',
    permissions: (data['permisos'] as List<dynamic>? ?? const [])
        .whereType<String>(),
  );
}

class ClinicAccessSession {
  static final current = ValueNotifier<ClinicAccess?>(null);
}

/// Installed above the Navigator so every pushed route shares the same access.
class ClinicAccessScope extends InheritedWidget {
  const ClinicAccessScope({
    super.key,
    required this.access,
    required super.child,
  });

  final ClinicAccess? access;

  static ClinicAccess? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ClinicAccessScope>()?.access;

  @override
  bool updateShouldNotify(ClinicAccessScope oldWidget) =>
      oldWidget.access != access;
}
