const admin = require('firebase-admin');
module.exports = async function(req, res, next) {
  const auth = req.headers.authorization || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Unauthorized' });
  try {
    await admin.auth().verifyIdToken(token);
    return next();
  } catch (e) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
};