class Doctor {
  const Doctor({
    required this.id,
    required this.fullName,
    this.specialty,
    this.phone,
    this.email,
  });

  final String id;
  final String fullName;
  final String? specialty;
  final String? phone;
  final String? email;

  factory Doctor.fromApi(Map<String, dynamic> row) => Doctor(
    id: row['id'].toString(),
    fullName: row['nombre'] as String? ?? '',
    specialty: row['especialidad'] as String?,
    phone: row['telefono'] as String?,
    email: row['correo'] as String?,
  );

  Map<String, dynamic> toApi() => {
    'nombre': fullName.trim(),
    'correo': email?.trim(),
    'especialidad': _nullIfBlank(specialty),
    'telefono': _nullIfBlank(phone),
    if (id.isEmpty) 'estado': '1',
  };

  factory Doctor.fromMap(Map<String, dynamic> map) => Doctor(
    id: map['id'] as String,
    fullName: map['nombre_completo'] as String,
    specialty: map['especialidad'] as String?,
    phone: map['telefono'] as String?,
    email: map['email'] as String?,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'nombre_completo': fullName.trim(),
    'especialidad': _nullIfBlank(specialty),
    'telefono': _nullIfBlank(phone),
    'email': _nullIfBlank(email),
  };

  static String? _nullIfBlank(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
