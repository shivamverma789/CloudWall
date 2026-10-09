const Database = require("better-sqlite3");
const path = require("path");

const dbPath = path.join(__dirname, "cloudwall.db");

const db = new Database(dbPath);

db.pragma("foreign_keys = ON");

console.log("[INFO] SQLite database connected.");


// USERS TABLE

db.exec(`
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
`);

console.log("[INFO] Users table ready.");


// IMAGES TABLE

db.exec(`
    CREATE TABLE IF NOT EXISTS images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        filename TEXT NOT NULL,
        image_url TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id)
    )
`);

console.log("[INFO] Images table ready.");

module.exports = db;