// Datos de prueba. Solo existen en la base BDTyckOps_pruebas.
// Las contraseñas son ficticias y únicamente sirven para estas pruebas.

export const ROLES = ['colaborador', 'administrador', 'invitado'];
export const DEPARTAMENTOS = ['RRHH', 'Administracion', 'Servicios generales'];
export const CATEGORIAS = ['Inmoviliario', 'Electrica', 'Baños', 'Aire acondicionado'];

export const USUARIOS = {
  // Primer ingreso: aún no acepta Términos ni decide su contraseña.
  colaboradorNuevo: {
    email: 'colaborador.nuevo@gamaitaly.cl',
    password: 'ClaveTemporal1',
    name: 'Camila',
    appat: 'Henriquez',
    apmat: 'Rojas',
    rol: 'colaborador',
    depa: 'RRHH',
    isFirstLogin: true,
    termsAccepted: false,
  },
  adminNuevo: {
    email: 'admin.nuevo@gamaitaly.cl',
    password: 'ClaveTemporal2',
    name: 'Felipe',
    appat: 'Morales',
    apmat: 'Soto',
    rol: 'administrador',
    depa: 'Administracion',
    isFirstLogin: true,
    termsAccepted: false,
  },
  // Ya completaron el primer acceso.
  colaboradorActivo: {
    email: 'colaborador.activo@gamaitaly.cl',
    password: 'ClaveActiva123',
    name: 'Martin',
    appat: 'Diaz',
    apmat: 'Suarez',
    rol: 'colaborador',
    depa: 'Servicios generales',
    isFirstLogin: false,
    termsAccepted: true,
  },
  adminActivo: {
    email: 'admin.activo@gamaitaly.cl',
    password: 'ClaveAdmin123',
    name: 'Pablo',
    appat: 'Escobar',
    apmat: 'Gaviria',
    rol: 'administrador',
    depa: 'Administracion',
    isFirstLogin: false,
    termsAccepted: true,
  },
  // Rol que el backend no reconoce (ni colaborador ni administrador).
  sinRolValido: {
    email: 'invitado@gamaitaly.cl',
    password: 'ClaveInvitado1',
    name: 'Invitado',
    appat: 'Sin',
    apmat: 'Rol',
    rol: 'invitado',
    depa: 'RRHH',
    isFirstLogin: false,
    termsAccepted: true,
  },
};
