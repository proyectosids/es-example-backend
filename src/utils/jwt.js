import jwt from "jsonwebtoken";

const accessSecret = process.env.JWT_ACCESS_SECRET || "dev-access-secret-change-me";
const refreshSecret = process.env.JWT_REFRESH_SECRET || "dev-refresh-secret-change-me";
const accessExpiresIn = process.env.JWT_ACCESS_EXPIRES || "15m";
const refreshExpiresIn = process.env.JWT_REFRESH_EXPIRES || "30d";

export function signAccessToken({ userId, tenantId, email }) {
  return jwt.sign(
    { sub: userId, tenantId, email, type: "access" },
    accessSecret,
    { expiresIn: accessExpiresIn }
  );
}

export function signRefreshToken({ userId, tenantId, email }) {
  return jwt.sign(
    { sub: userId, tenantId, email, type: "refresh" },
    refreshSecret,
    { expiresIn: refreshExpiresIn }
  );
}

export function verifyAccessToken(token) {
  return jwt.verify(token, accessSecret);
}

export function verifyRefreshToken(token) {
  return jwt.verify(token, refreshSecret);
}
