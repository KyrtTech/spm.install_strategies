import knex from "knex";

import env from "./env";

const db = knex({
  client: "postgres",
  connection: {
    host: env.DB_HOST,
    port: env.DB_PORT,
    database: env.DB_NAME,
    user: env.DB_USER,
    password: env.DB_PASSWORD,
    ssl: {
        ca: require("fs").readFileSync('./global-bundle.pem')
    },
    pool: {
      min: env.DB_POOL_MIN,
      max: env.DB_POOL_MAX
    }
  }
});

export default db;