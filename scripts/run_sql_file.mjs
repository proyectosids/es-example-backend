import "dotenv/config";
import fs from "fs";
import path from "path";
import { getPool } from "../src/db/pool.js";

async function main() {
  const fileArg = process.argv[2];
  if (!fileArg) {
    console.error("Usage: node scripts/run_sql_file.mjs <sql-file-path>");
    process.exit(1);
  }

  const filePath = path.resolve(fileArg);
  if (!fs.existsSync(filePath)) {
    console.error(`SQL file not found: ${filePath}`);
    process.exit(1);
  }

  const sqlText = fs.readFileSync(filePath, "utf8");
  const pool = await getPool();
  const res = await pool.request().query(sqlText);

  console.log(`Executed: ${filePath}`);
  if (res.recordset?.length) {
    console.log("Result:", res.recordset);
  } else {
    console.log("Result: OK");
  }
}

main().catch((err) => {
  console.error("SQL execution error:", err.message);
  process.exit(1);
});

