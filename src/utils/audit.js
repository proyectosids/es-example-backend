import { recordAuditEvent } from "../repos/audit.repo.js";

export async function safeAudit(event) {
  try {
    await recordAuditEvent(event);
  } catch (err) {
    // La auditoria no debe romper el flujo principal.
    console.error("Audit write failed:", err.message);
  }
}

