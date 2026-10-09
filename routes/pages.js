const express = require("express");

const db = require("../database/db");

const router = express.Router();


// =========================================
// HOME / GALLERY
// =========================================

router.get("/", (req, res) => {

    const images = db.prepare(`
        SELECT
            images.id,
            images.filename,
            images.image_url,
            images.created_at,
            users.name AS uploader
        FROM images
        JOIN users
            ON images.user_id = users.id
        ORDER BY images.created_at DESC
    `).all();


    res.render("index", {
    title: "CloudWall",
    images: images,
    user: req.session.user || null
});


});


module.exports = router;