require("dotenv").config();
const express = require("express");
const session = require("express-session");
const path = require("path");
const db = require("./database/db");

const pagesRouter = require("./routes/pages");
const authRouter = require("./routes/auth");
const userRouter = require("./routes/user");
const uploadRouter = require("./routes/upload");

const app = express();

const PORT = process.env.PORT || 3000;


// =========================================
// CONFIGURATION
// =========================================

app.set("view engine", "ejs");


// =========================================
// MIDDLEWARE
// =========================================

app.use(express.urlencoded({ extended: true }));
app.use(express.json());

app.use(express.static("public"));
app.use(
    "/uploads",
    express.static(path.join(__dirname, "uploads"))
);

app.use(
    session({
        secret: process.env.SESSION_SECRET,
        resave: false,
        saveUninitialized: false
    })
);

// =========================================
// ROUTES
// =========================================

app.use("/", pagesRouter);

app.use("/", authRouter);

app.use("/", userRouter);

app.use("/", uploadRouter);

// =========================================
// SERVER
// =========================================

app.listen(PORT, () => {

    console.log(
        `CloudWall running at http://localhost:${PORT}`
    );

});