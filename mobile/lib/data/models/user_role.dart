/// Roles del sistema. El servidor es quien dice qué rol tiene cada usuario
/// (RF-11 adm): la app nunca decide el rol por su cuenta.
enum UserRole {
  worker('COLABORADOR', 'Colaborador'),
  admin('ADMINISTRADOR', 'Administrador');

  const UserRole(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static UserRole fromApi(String value) => UserRole.values.firstWhere(
        (r) => r.apiValue == value.toUpperCase(),
        orElse: () => throw FormatException('Rol desconocido: $value'),
      );
}
