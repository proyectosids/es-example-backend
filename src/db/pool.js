import sql from "mssql";

let pool;

export async function getPool() {
    if (pool) return pool;

    pool = await sql.connect({
        user: process.env.DB_USER,
        password: process.env.DB_PASS,
        server: process.env.DB_SERVER,
        database: process.env.DB_NAME,
        options: {
            encrypt: true,
            trustServerCertificate: true
        }
    });

    return pool;
}

export { sql };
