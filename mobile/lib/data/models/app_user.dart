import 'user_role.dart';

/// Usuario con sesión iniciada.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.area,
    this.termsAccepted = false,
    this.isFirstLogin = false,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? area; // una de las 8 áreas organizacionales
  final bool termsAccepted; // RF-03
  final bool isFirstLogin; // RF-02: mostrar "cambiar o mantener contraseña"

  /// Convierte el JSON del backend en un objeto Dart.
  /// Los nombres de los campos se confirman con Moisés en la T3.
  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'].toString(),
        name: json['name'] as String,
        email: json['email'] as String,
        role: UserRole.fromApi(json['role'] as String),
        area: json['area'] as String?,
        termsAccepted: json['termsAccepted'] as bool? ?? false,
        isFirstLogin: json['isFirstLogin'] as bool? ?? false,
      );
}
