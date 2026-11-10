/// Términos y Condiciones (RF-03). Si cambias el texto, cambia también
/// [termsDocCode]: en la T4 el servidor guardará qué versión aceptó cada usuario.
const termsDocCode = 'GA-TOS-2026';
const termsTitle = 'TÉRMINOS Y CONDICIONES DE USO Y POLÍTICA DE PRIVACIDAD DE DATOS';
const termsSubtitle = 'Aplicación Móvil y Ecosistema de Servicios Generales – Gama Chile S.A.';
const termsUpdatedAt = 'Última actualización: Septiembre de 2026';

/// Piezas con las que se arma cada sección.
sealed class TermsBlock {
  const TermsBlock();
}

class TermsParagraph extends TermsBlock {
  const TermsParagraph(this.text);
  final String text;
}

class TermsSubheading extends TermsBlock {
  const TermsSubheading(this.text); // "A. Datos Personales Recopilados"
  final String text;
}

class TermsItem extends TermsBlock {
  const TermsItem(this.text, {this.marker = '•', this.label}); // viñeta o "1."
  final String marker;
  final String? label; // parte en negrita, ej. "Credenciales Corporativas:"
  final String text;
}

class TermsSection {
  const TermsSection(this.title, this.blocks);
  final String title;
  final List<TermsBlock> blocks;
}

const termsSections = <TermsSection>[
  TermsSection('1. ASPECTOS GENERALES Y ACEPTACIÓN', [
    TermsParagraph(
      'El presente documento regula los términos y condiciones de uso (en adelante, "Términos") de la '
      'aplicación móvil y plataforma web de Servicios Generales de Gama Chile S.A. (RUT 78.806.090-4).',
    ),
    TermsParagraph(
      'Al descargar, acceder, registrarse o utilizar esta aplicación móvil, el usuario (en adelante, el '
      '"Colaborador" o "Usuario") declara haber leído, comprendido y aceptado expresamente la totalidad de '
      'las cláusulas contenidas en este documento. Si no está de acuerdo con estos Términos, deberá '
      'abstenerse de utilizar la aplicación.',
    ),
    TermsParagraph(
      'El acceso y uso de esta plataforma está estrictamente restringido a los colaboradores, trabajadores '
      'y personal autorizado de Gama Chile S.A.',
    ),
  ]),
  TermsSection('2. FINALIDAD Y FUNCIONALIDAD DE LA APLICACIÓN', [
    TermsParagraph('La Aplicación Móvil constituye una herramienta de trabajo corporativa destinada exclusivamente a:'),
    TermsItem(
      'Permitir la solicitud catalogada de artículos de oficina (escritorio) y suministros de casino/cafetería.',
      marker: '1.',
      label: 'Gestión e Insumos:',
    ),
    TermsItem(
      'Reportar fallas en las instalaciones (eléctricas, climatización, infraestructura, baños, mobiliario, '
      'entre otros).',
      marker: '2.',
      label: 'Reporte de Incidencias e Infraestructura:',
    ),
    TermsItem(
      'Consultar el estado de atención de las solicitudes y recibir alertas informativas en tiempo real '
      '(Push Notifications).',
      marker: '3.',
      label: 'Trazabilidad y Notificaciones:',
    ),
  ]),
  TermsSection('3. AUTENTICACIÓN, CUENTA Y SEGURIDAD', [
    TermsItem(
      'El acceso se realiza exclusivamente mediante el correo electrónico corporativo de Gama Chile S.A. y '
      'contraseña. El Usuario es responsable de mantener la confidencialidad de sus credenciales.',
      label: 'Credenciales Corporativas:',
    ),
    TermsItem(
      'Queda estrictamente prohibido ceder, transferir o permitir el uso de la cuenta a terceros o a '
      'personal ajeno a la organización.',
      label: 'Uso Personal e Intransferible:',
    ),
    TermsItem(
      'El sistema aplica un control de acceso basado en roles. Las funciones administrativas están '
      'reservadas exclusivamente al departamento de Servicios Generales.',
      label: 'Control de Accesos (RBAC):',
    ),
  ]),
  TermsSection('4. TRATAMIENTO DE DATOS PERSONALES (Cumplimiento Ley N° 21.719 / Ley N° 19.628 de Chile)', [
    TermsParagraph(
      'En conformidad con la legislación chilena vigente en materia de protección de datos personales '
      '(Ley N° 21.719 y Ley N° 19.628), Gama Chile S.A. actúa como Responsable del Tratamiento de Datos.',
    ),
    TermsSubheading('A. Datos Personales Recopilados'),
    TermsParagraph(
      'Para el correcto funcionamiento de la plataforma, la aplicación recopila y procesa los siguientes datos:',
    ),
    TermsItem(
      'Nombre, apellidos, cargo, área/departamento y ubicación o piso habitual de trabajo.',
      label: 'Datos de Identificación y Perfil Laboral:',
    ),
    TermsItem(
      'Piso, oficina, sector o sala de reuniones seleccionada explícitamente al reportar una falla.',
      label: 'Datos de Ubicación Operativa:',
    ),
    TermsItem(
      'Fotografía(s) capturada(s) desde la cámara del dispositivo móvil o cargada(s) desde la galería, '
      'adjuntada(s) voluntariamente por el Usuario como evidencia del problema técnico o de infraestructura '
      'reportado.',
      label: 'Evidencia Fotográfica / Galería:',
    ),
    TermsItem(
      'Registro de insumos pedidos, reportes generados y fechas de emisión.',
      label: 'Historial de Solicitudes:',
    ),
    TermsSubheading('B. Base Legal de Licitud'),
    TermsParagraph('El tratamiento de sus datos personales se fundamenta en:'),
    TermsItem(
      'La necesidad de coordinar, gestionar y proveer las herramientas, insumos e infraestructura adecuada '
      'para el desarrollo de las funciones laborales del colaborador dentro de Gama Chile S.A.',
      marker: '1.',
      label: 'Ejecución del Contrato de Trabajo:',
    ),
    TermsItem(
      'La aceptación expresa de estos Términos al momento del primer acceso a la app móvil.',
      marker: '2.',
      label: 'Consentimiento Explicito:',
    ),
    TermsSubheading('C. Finalidad del Tratamiento'),
    TermsParagraph('Los datos serán procesados única y exclusivamente para:'),
    TermsItem('Gestionar, aprobar y entregar los insumos de oficina y casino.'),
    TermsItem('Asignar, reparar y dar resolución a las fallas físicas reportadas en las dependencias.'),
    TermsItem(
      'Generar métricas, analítica interna y reportes consolidados (mantenimiento e inventario) para '
      'optimizar el gasto y la operación de la empresa.',
    ),
    TermsSubheading('D. Derechos ARCOP (Acceso, Rectificación, Cancelación, Oposición y Portabilidad)'),
    TermsParagraph(
      'El Usuario tiene derecho a ejercer en todo momento sus derechos legales de Acceso, Rectificación, '
      'Cancelación/Supresión, Oposición y Portabilidad de sus datos personales. Para hacer uso de estos '
      'derechos, podrá dirigir una solicitud formal al departamento de Servicios Generales o TI de Gama '
      'Chile S.A. a través de los canales internos institucionales.',
    ),
    TermsSubheading('E. Almacenamiento, Seguridad y Retención'),
    TermsItem(
      'Los datos son encriptados en tránsito (HTTPS/TLS) y almacenados de forma segura en bases de datos '
      'PostgreSQL sobre infraestructura en la nube (Oracle Cloud Infrastructure).',
      label: 'Seguridad de la Información:',
    ),
    TermsItem(
      'Gama Chile S.A. no venderá, cederá ni compartirá los datos personales con terceros para fines '
      'comerciales o publicitarios.',
      label: 'Transferencia de Datos:',
    ),
    TermsItem(
      'Los datos asociados a los tickets e inventarios se conservarán durante el periodo que dure la '
      'relación laboral del colaborador y/o los plazos exigidos para fines de auditoría operativa interna '
      'de la empresa.',
      label: 'Plazo de Retención:',
    ),
  ]),
  TermsSection('5. USO DE CÁMARA, GALERÍA Y PERMISOS DEL DISPOSITIVO', [
    TermsParagraph('Para utilizar la función de Reporte de Fallas:'),
    TermsItem(
      'La app solicitará permiso explícito para acceder a la cámara y/o almacenamiento/galería del smartphone.',
    ),
    TermsItem(
      'Dichos permisos se utilizarán únicamente en el momento en que el Usuario decida adjuntar una '
      'fotografía como evidencia del daño reportado.',
    ),
    TermsItem(
      'La aplicación no realiza capturas de imagen ni de video en segundo plano ni accede a fotos privadas '
      'que no hayan sido seleccionadas activamente por el Usuario.',
    ),
  ]),
  TermsSection('6. NOTIFICACIONES PUSH', [
    TermsParagraph(
      'La aplicación incluye un servicio de notificaciones en tiempo real (Push Notifications) mediante '
      'servicios integrados (ej. Firebase Cloud Messaging) con el único propósito de mantener informado al '
      'Usuario sobre el cambio de estado de sus requerimientos (ej: "En Proceso", "Resuelto", "Pedido en '
      'camino"). El Usuario puede gestionar la recepción de estas notificaciones desde los ajustes de su '
      'dispositivo móvil.',
    ),
  ]),
  TermsSection('7. PROPIEDAD INTELECTUAL', [
    TermsParagraph(
      'Todos los derechos de propiedad intelectual, marcas, logotipos, diseño de interfaz (UI/UX), código '
      'fuente (Flutter/Dart, Node.js) y contenidos de la aplicación son propiedad exclusiva de Gama Chile '
      'S.A. Se prohíbe cualquier copia, reproducción, ingeniería inversa o uso no autorizado de la '
      'plataforma fuera de los fines operativos previstos.',
    ),
  ]),
  TermsSection('8. MODIFICACIONES DE LOS TÉRMINOS', [
    TermsParagraph(
      'Gama Chile S.A. se reserva el derecho de actualizar o modificar los presentes Términos en cualquier '
      'momento para adaptarse a cambios legales, técnicos o corporativos. Las actualizaciones serán '
      'notificadas a través de la misma aplicación. El uso continuado de la app tras la publicación de los '
      'cambios constituirá la aceptación implícita de los nuevos términos.',
    ),
  ]),
  TermsSection('9. LEGISLACIÓN APLICABLE Y JURISDICCIÓN', [
    TermsParagraph(
      'Este documento se rige e interpreta íntegramente por las leyes de la República de Chile. Para '
      'cualquier controversia derivada del uso de la aplicación, las partes se someten a la jurisdicción de '
      'los Tribunales Ordinarios de Justicia de Santiago de Chile.',
    ),
  ]),
];
