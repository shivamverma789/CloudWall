const express = require("express");

const router = express.Router();


// =========================================
// AUTHENTICATION MIDDLEWARE
// =========================================

function requireLogin(req, res, next) {

    if (!req.session.user) {
        return res.redirect("/login");
    }

    next();
}


// =========================================
// DASHBOARD
// =========================================

router.get("/dashboard", requireLogin, (req, res) => {

    res.render("dashboard", {
        title: "Dashboard",
        user: req.session.user
    });

});


// =========================================
// LOGOUT
// =========================================

router.post("/logout", requireLogin, (req, res) => {

    req.session.destroy((error) => {

        if (error) {
            console.error("[ERROR] Logout failed:", error);
            return res.redirect("/dashboard");
        }

        res.redirect("/");

    });

});


module.exports = router;