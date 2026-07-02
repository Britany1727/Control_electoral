import { Client, Users } from 'node-appwrite';

export default async ({ req, res, log, error }) => {
  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : (req.body || {});
    const { email, password, name } = body;

    log(`Recibido: email=${email}, name=${name}`);

    if (!email || !password) {
      return res.json({ success: false, error: 'email y password son requeridos' }, 400);
    }

    const endpoint = process.env.APPWRITE_ENDPOINT || process.env.APPWRITE_FUNCTION_ENDPOINT || 'https://cloud.appwrite.io/v1';
    const projectId = process.env.APPWRITE_PROJECT_ID || process.env.APPWRITE_FUNCTION_PROJECT_ID;
    log(`endpoint=${endpoint} projectId=${projectId}`);

    const client = new Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(process.env.APPWRITE_API_KEY);

    const users = new Users(client);

    let authUserId;
    try {
      const created = await users.create('unique()', email, undefined, password, name || '');
      authUserId = created.$id;
      log(`Usuario creado: ${authUserId}`);
    } catch (e) {
      log(`Error create: code=${e.code} message=${e.message}`);
      if (e.code === 409) {
        const list = await users.list();
        const found = list.users.find(u => u.email === email);
        if (found) {
          authUserId = found.$id;
          log(`Usuario existente recuperado: ${authUserId}`);
        } else {
          return res.json({ success: false, error: 'Email ya existe pero no se encontró en listado' }, 409);
        }
      } else {
        return res.json({ success: false, error: e.message }, e.code || 500);
      }
    }

    return res.json({ success: true, userId: authUserId });
  } catch (e) {
    error(`Fatal: ${e.message}`);
    return res.json({ success: false, error: e.message }, 500);
  }
};
