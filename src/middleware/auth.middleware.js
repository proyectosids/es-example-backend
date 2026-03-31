import { verifyAccessToken } from "../utils/jwt.js";

export function authenticate(req, res, next) {
  const auth = req.headers.authorization || "";
  const [scheme, token] = auth.split(" ");

  if (scheme !== "Bearer" || !token) {
    return res.status(401).json({ message: "Missing Bearer token" });
  }

  try {
    const payload = verifyAccessToken(token);
    req.auth = {
      userId: payload.sub,
      tenantId: payload.tenantId,
      email: payload.email
    };
    return next();
  } catch {
    return res.status(401).json({ message: "Invalid or expired token" });
  }
}
