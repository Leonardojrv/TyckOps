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
  /// Campos confirmados con la API de Moisés (backend/README.md).
  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'].toString(),
        name: json['name'] as String,
        email: json['email'] as String,
        role: UserRole.fromApi(json['role'] as String),
        area: json['area'] as String?,
        termsAccepted: json['termsAccepted'] as bool? ?? false,
        isFirstLogin: json['isFirstLogin'] as bool? ?? false,
      );

  /// Copia el usuario cambiando solo algunos campos (los objetos son
  /// inmutables: en vez de modificarlos, se crea uno nuevo).
  AppUser copyWith({bool? termsAccepted, bool? isFirstLogin}) => AppUser(
        id: id,
        name: name,
        email: email,
        role: role,
        area: area,
        termsAccepted: termsAccepted ?? this.termsAccepted,
        isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      );
}
