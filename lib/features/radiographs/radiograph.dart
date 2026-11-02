class RadiographStudy {
  const RadiographStudy({
    required this.id,
    required this.patientName,
    required this.studyType,
    required this.status,
    this.fileName,
    this.mimeType,
    this.storagePath,
    this.fileId,
  });

  final String id;
  final String patientName;
  final String studyType;
  final String status;
  final String? fileName;
  final String? mimeType;
  final String? storagePath;
  final String? fileId;

  bool get hasFile => fileId != null || storagePath?.isNotEmpty == true;
  bool get isPdf => mimeType == 'application/pdf';

  factory RadiographStudy.fromApi(Map<String, dynamic> row) => RadiographStudy(
    id: row['id'].toString(),
    patientName: row['paciente'] as String? ?? 'Paciente',
    studyType: row['tipo'] as String,
    status: row['estado'] as String,
    fileId: row['archivo_id']?.toString(),
    fileName: row['archivo_nombre'] as String?,
  );

  factory RadiographStudy.fromMap(Map<String, dynamic> row) {
    final patient = row['pacientes'] as Map<String, dynamic>?;
    final relation = row['radiografias'];
    final Map<String, dynamic>? file = relation is List
        ? (relation.isEmpty
              ? null
              : Map<String, dynamic>.from(relation.first as Map))
        : (relation is Map ? Map<String, dynamic>.from(relation) : null);
    return RadiographStudy(
      id: row['id'] as String,
      patientName: patient == null
          ? 'Paciente'
          : '${patient['nombres']} ${patient['apellidos']}'.trim(),
      studyType: row['tipo'] as String,
      status: row['estado'] as String,
      fileName: file?['nombre'] as String?,
      mimeType: file?['tipo'] as String?,
      storagePath: file?['storage_path'] as String?,
    );
  }
}
