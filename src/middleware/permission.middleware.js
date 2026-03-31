import { hasPermissionAnyScope, hasPermissionAtScope } from "../repos/roles.repo.js";

export function requirePermission(permissionCode, scopeResolver = null) {
  return async (req, res, next) => {
    try {
      if (!req.auth?.tenantId || !req.auth?.userId) {
        return res.status(401).json({ message: "Unauthorized" });
      }

      const { tenantId, userId } = req.auth;
      const scopeOrgUnitId = scopeResolver ? scopeResolver(req) : null;

      if (!scopeOrgUnitId) {
        const ok = await hasPermissionAnyScope({ tenantId, userId, permissionCode });
        if (!ok) return res.status(403).json({ message: "Forbidden" });
        return next();
      }

      const ok = await hasPermissionAtScope({
        tenantId,
        userId,
        permissionCode,
        orgUnitId: scopeOrgUnitId
      });
      if (!ok) return res.status(403).json({ message: "Forbidden" });
      return next();
    } catch (err) {
      return res.status(500).json({ message: "Permission check failed", error: err.message });
    }
  };
}
