# CloudWall

A simple image-sharing web application built with Node.js, Express, EJS, and SQLite. CloudWall is designed as a hands-on project for learning AWS hosting and cloud infrastructure.

## Features

- User registration and login
- Password hashing with bcrypt
- Session-based authentication
- Image uploads with Multer
- SQLite database for users and image metadata
- Global image gallery
- Image upload validation

## Tech Stack

- Node.js
- Express.js
- EJS
- SQLite with better-sqlite3
- Multer
- bcryptjs
- express-session

## Prerequisites

Install:

- Node.js and npm
- Git

No MongoDB account or external database is required.

## Getting Started

### 1. Clone the repository

```bash
git clone YOUR_REPOSITORY_URL
cd Cloudwall
```

Replace `YOUR_REPOSITORY_URL` with the repository's Git URL.

### 2. Install dependencies

```bash
npm install
```

### 3. Configure environment variables

Create a `.env` file in the project root:

```env
PORT=3000
SESSION_SECRET=replace-with-a-long-random-secret
```

Generate a session secret using:

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Copy the generated value into `SESSION_SECRET`.

### 4. Start the application

```bash
npm run dev
```

Open:

http://localhost:3000

## Project Structure

```text
Cloudwall/
├── database/
│   └── db.js
├── routes/
│   ├── auth.js
│   ├── pages.js
│   ├── user.js
│   └── upload.js
├── public/
│   └── css/
│       └── style.css
├── uploads/
├── views/
├── app.js
├── package.json
├── package-lock.json
├── .env.example
├── .gitignore
└── README.md
```

The SQLite database file is generated automatically when the application starts.

## AWS Workshop Roadmap

CloudWall will be extended during the workshop to demonstrate:

1. Deploying a Node.js application on Amazon EC2
2. Managing the application with PM2
3. Configuring Nginx as a reverse proxy
4. Storing uploaded images in Amazon S3
5. Using IAM roles for AWS service access
6. Monitoring application and instance metrics with CloudWatch
7. Setting up additional infrastructure monitoring with Zabbix

## Security Notes

- Never commit `.env` or credentials to GitHub.
- Do not commit the SQLite database file or uploaded user images.
- Use a strong session secret.
- This project is intended for learning and requires additional security hardening before public production use.

## License

For educational use and workshop demonstrations.