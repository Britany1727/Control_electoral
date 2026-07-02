import { Client, Users } from 'node-appwrite';

export default async ({ req, res, log, error }) => {
  try {
    const { email, password, name, userId } = JSON.parse(req.body || '{}');

    if (!email || !password) {
      return res.json({ success: false, error: 'email y password son requeridos' }, 400);
    }

    const client = new Client()
      .setEndpoint(process.env.APPWRITE_ENDPOINT || 'https://cloud.appwrite.io/v1')
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
      if (e.code === 409) {
        log(`Usuario ya existe en Auth con email ${email}, obteniendo ID...`);
        const list = await users.list([`email.equal("${email}")`]);
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
