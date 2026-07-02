import { Client, Users, Query } from 'node-appwrite'; // <- Importamos Query aquí

export default async ({ req, res, log, error }) => {
  try {
    // Manejo seguro del cuerpo de la petición (soporta strings u objetos parseados)
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body;
    const { email, password, name, userId } = body;

    if (!email || !password) {
      return res.json({ success: false, error: 'email y password son requeridos' }, 400);
    }

    // Inicialización del cliente usando las variables del entorno inyectadas por Appwrite Cloud
    const client = new Client()
      .setEndpoint(process.env.APPWRITE_FUNCTION_ENDPOINT)
      .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
      .setKey(process.env.APPWRITE_API_KEY);

    const users = new Users(client);

    let authUserId;
    try {
      const created = await users.create(
        userId || 'unique()',
        email,
        undefined, // phone
        password,
        name || '',
      );
      authUserId = created.$id;
      log(`Usuario creado en Auth: ${authUserId}`);
    } catch (e) {
      // Control de conflicto si el correo ya existe
      if (e.code === 409) {
        log(`Usuario ya existe en Auth con email ${email}, obteniendo ID...`);
        
        // CORRECCIÓN: Uso correcto de Query.equal del SDK
        const list = await users.list([
          Query.equal('email', [email])
        ]);

        if (list.users.length > 0) {
          authUserId = list.users[0].$id;
          log(`Usuario existente recuperado: ${authUserId}`);
        } else {
          return res.json({ success: false, error: 'El email ya existe pero no se pudo recuperar el usuario' }, 409);
        }
      } else {
        error(`Error al crear usuario en Auth: ${e.message}`);
        return res.json({ success: false, error: e.message }, e.code || 500);
      }
    }

    return res.json({ success: true, userId: authUserId });
  } catch (e) {
    error(`Error inesperado: ${e.message}`);
    return res.json({ success: false, error: e.message }, 500);
  }
};