const express = require("express");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const db = require("../database/db");

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
// MULTER CONFIGURATION
// =========================================

const uploadDirectory = path.join(__dirname, "../uploads");

fs.mkdirSync(uploadDirectory, { recursive: true });


const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, uploadDirectory);
    },

    filename: (req, file, cb) => {
        const uniqueName =
            Date.now() +
            "-" +
            Math.round(Math.random() * 1e9) +
            path.extname(file.originalname).toLowerCase();

        cb(null, uniqueName);
    }
});


// Accepted image types
const allowedTypes = [
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/gif"
];


const upload = multer({
    storage: storage,

    limits: {
        fileSize: 5 * 1024 * 1024
    },

    fileFilter: (req, file, cb) => {
        if (allowedTypes.includes(file.mimetype)) {
            return cb(null, true);
        }

        cb(new Error(
            "Only JPEG, PNG, WEBP and GIF images are allowed."
        ));
    }
});


// =========================================
// UPLOAD PAGE
// =========================================

router.get("/upload", requireLogin, (req, res) => {
    res.render("upload", {
        title: "Upload Image",
        error: null
    });
});


// =========================================
// UPLOAD IMAGE
// =========================================

router.post(
    "/upload",
    requireLogin,

    (req, res, next) => {
        upload.single("image")(req, res, (err) => {
            if (err) {
                let message = "Unable to upload image.";

                if (
                    err instanceof multer.MulterError &&
                    err.code === "LIMIT_FILE_SIZE"
                ) {
                    message = "Image must be 5 MB or smaller.";
                } else if (err.message) {
                    message = err.message;
                }

                return res.status(400).render("upload", {
                    title: "Upload Image",
                    error: message
                });
            }

            next();
        });
    },

    (req, res) => {
        if (!req.file) {
            return res.status(400).render("upload", {
                title: "Upload Image",
                error: "Please select an image."
            });
        }

        try {
            // Save image metadata in SQLite
            const insertImage = db.prepare(
                "INSERT INTO images (user_id, filename, image_url) VALUES (?, ?, ?)"
            );

            insertImage.run(
                req.session.user.id,
                req.file.filename,
                "/uploads/" + req.file.filename
            );

            console.log(
                "[INFO] Image uploaded:",
                req.file.filename
            );

            res.redirect("/");

        } catch (error) {
            console.error(
                "[ERROR] Could not save image metadata:",
                error.message
            );

            return res.status(500).render("upload", {
                title: "Upload Image",
                error: "The image could not be saved. Please try again."
            });
        }
    }
);


module.exports = router;
