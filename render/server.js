const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.static(path.join(__dirname, 'public')));

// Config pública de Appwrite (endpoint y projectId NO son secretos,
// son necesarios en el cliente para inicializar el SDK)
app.get('/api/config', (req, res) => {
  res.json({
    appwriteEndpoint: process.env.APPWRITE_ENDPOINT, // ej: https://cloud.appwrite.io/v1
    appwriteProjectId: process.env.APPWRITE_PROJECT_ID,
  });
});

app.get('/verify-email', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'verify-email.html'));
});

// Alias por si en Appwrite configuraste la URL de verificación como /verify
app.get('/verify', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'verify-email.html'));
});

app.get('/reset-password', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'reset-password.html'));
});

// Alias por si en Appwrite configuraste la URL de recuperación como /recovery
app.get('/recovery', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'reset-password.html'));
});

app.listen(PORT, () => console.log(`Server running on port ${PORT}`));