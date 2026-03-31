import express from "express";
import bcrypt from "bcryptjs";

import { findUserForLogin, normalizeEmail, touchLastLogin } from "../repos/users.repo.js";
import { signAccessToken, signRefreshToken, verifyRefreshToken } from "../utils/jwt.js";

const router = express.Router();

router.post("/auth/login", async (req, res) => {
  try {
    const tenantCode = String(req.body?.tenantCode || "").trim();
    const email = String(req.body?.email || "").trim();
    const password = String(req.body?.password || "");

    if (!tenantCode || !email || !password) {
      return res.status(400).json({ message: "tenantCode, email and password are required" });
    }

    const user = await findUserForLogin({
      tenantCode,
      emailNormalized: normalizeEmail(email)
    });

    if (!user) return res.status(401).json({ message: "Invalid credentials" });

    const valid = await bcrypt.compare(password, user.PasswordHash || "");
    if (!valid) return res.status(401).json({ message: "Invalid credentials" });

    await touchLastLogin({ tenantId: user.TenantId, userId: user.UserId });

    const tokenPayload = {
      userId: user.UserId,
      tenantId: user.TenantId,
      email: user.Email
    };

    const accessToken = signAccessToken(tokenPayload);
    const refreshToken = signRefreshToken(tokenPayload);

    return res.json({
      accessToken,
      refreshToken,
      user: {
        userId: user.UserId,
        tenantId: user.TenantId,
        tenantCode: user.TenantCode,
        tenantName: user.TenantName,
        email: user.Email,
        displayName: user.DisplayName,
        firstName: user.FirstName,
        lastName: user.LastName
      }
    });
  } catch (err) {
    return res.status(500).json({ message: "Login error", error: err.message });
  }
});

router.post("/auth/refresh", async (req, res) => {
  try {
    const refreshToken = String(req.body?.refreshToken || "");
    if (!refreshToken) return res.status(400).json({ message: "refreshToken is required" });

    const payload = verifyRefreshToken(refreshToken);
    if (payload.type !== "refresh") return res.status(401).json({ message: "Invalid refresh token" });

    const accessToken = signAccessToken({
      userId: payload.sub,
      tenantId: payload.tenantId,
      email: payload.email
    });

    return res.json({ accessToken });
  } catch {
    return res.status(401).json({ message: "Invalid or expired refresh token" });
  }
});

export default router;
