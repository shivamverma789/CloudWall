const express = require("express");
const bcrypt = require("bcryptjs");

const db = require("../database/db");

const router = express.Router();


// =========================================
// REGISTER PAGE
// =========================================

router.get("/register", (req, res) => {

    res.render("register", {
        title: "Create Account",
        error: null
    });

});


// =========================================
// REGISTER USER
// =========================================

router.post("/register", async (req, res) => {

    const { name, email, password } = req.body;


    // Check required fields
    if (!name || !email || !password) {

        return res.render("register", {
            title: "Create Account",
            error: "Please fill in all fields."
        });

    }


    // Check password length
    if (password.length < 6) {

        return res.render("register", {
            title: "Create Account",
            error: "Password must contain at least 6 characters."
        });

    }


    const normalizedEmail = email.toLowerCase().trim();


    // Check existing user
    const existingUser = db
        .prepare("SELECT id FROM users WHERE email = ?")
        .get(normalizedEmail);


    if (existingUser) {

        return res.render("register", {
            title: "Create Account",
            error: "An account with this email already exists."
        });

    }


    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);


    // Insert user
    db.prepare(`
        INSERT INTO users (name, email, password)
        VALUES (?, ?, ?)
    `).run(
        name.trim(),
        normalizedEmail,
        hashedPassword
    );


    console.log("[INFO] New user registered:", normalizedEmail);


    res.redirect("/login");

});


// =========================================
// LOGIN PAGE
// =========================================

router.get("/login", (req, res) => {

    res.render("login", {
        title: "Login",
        error: null
    });

});


// =========================================
// LOGIN USER
// =========================================

router.post("/login", async (req, res) => {

    const { email, password } = req.body;

    const normalizedEmail = email.toLowerCase().trim();


    // Find user
    const user = db
        .prepare(`
            SELECT *
            FROM users
            WHERE email = ?
        `)
        .get(normalizedEmail);


    if (!user) {

        return res.render("login", {
            title: "Login",
            error: "Invalid email or password."
        });

    }


    // Compare password
    const passwordMatch = await bcrypt.compare(
        password,
        user.password
    );


    if (!passwordMatch) {

        return res.render("login", {
            title: "Login",
            error: "Invalid email or password."
        });

    }


    // Create session
    req.session.user = {
        id: user.id,
        name: user.name,
        email: user.email
    };


    console.log(
        "[INFO] User logged in:",
        normalizedEmail
    );


    res.redirect("/dashboard");

});

module.exports = router;