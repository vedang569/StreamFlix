# 🎬 StreamFlix

A **Netflix-inspired movie and series management platform** built for a college Database Management Systems (DBMS) project. StreamFlix demonstrates real SQL functionality — JOINs, foreign keys, normalized schema, aggregate queries — in a fully working dark-themed web app.

![Python](https://img.shields.io/badge/Python-3.10+-blue)
![Flask](https://img.shields.io/badge/Flask-3.0-green)
![MySQL](https://img.shields.io/badge/MySQL-8.0-orange)

---

## ✨ Features

| Feature | SQL Concepts Demonstrated |
|---------|--------------------------|
| **User Registration** | INSERT with password hashing |
| **User Login** | SELECT with WHERE clause, session management |
| **Home — Genre Rows** | Multi-table JOIN (content ⟶ content_genres ⟶ genres) |
| **Home — Continue Watching** | JOIN (watch_history ⟶ content), subquery for total duration |
| **Search** | LIKE pattern matching with wildcards |
| **Movie/Series Detail** | JOIN + GROUP_CONCAT for genre tags |
| **Play (Watch History)** | INSERT into watch_history with FK to episodes |
| **Add/Remove My List** | INSERT / DELETE on junction table |
| **Rate Content** | INSERT / UPDATE + aggregate AVG() to recompute avg_rating |
| **Episodes Table** | One-to-many relationship (content ⟶ episodes) |

---

## 🗃️ Database Schema (ER Overview)

```
users ──┬── watch_history ──── content ──┬── content_genres ──── genres
        ├── my_list ──────────────┘       ├── episodes
        ├── ratings ──────────────┘       │
        └── subscriptions ── plans        └── (poster_url, avg_rating …)
```

**10 tables**: `users`, `genres`, `content`, `content_genres`, `episodes`, `watch_history`, `my_list`, `ratings`, `plans`, `subscriptions`

---

## 🚀 Setup Instructions

### Prerequisites

- **Python 3.10+** installed
- **MySQL 8.0+** installed and running
- **pip** (Python package manager)

### 1. Clone the repository

```bash
git clone <repo-url>
cd dbms-python
```

### 2. Create a Python virtual environment

```bash
python -m venv venv

# Windows
venv\Scripts\activate

# macOS / Linux
source venv/bin/activate
```

### 3. Install Python dependencies

```bash
pip install -r requirements.txt
```

### 4. Create the MySQL database & seed data

Log into MySQL and run the schema file:

```bash
mysql -u root -p < schema.sql
```

Or from the MySQL shell:

```sql
SOURCE /path/to/schema.sql;
```

This will:
- Create the `streamflix` database
- Create all 10 tables with proper foreign keys
- Seed 20 movies/series, 10 genres, 35+ episodes, and 4 subscription plans

### 5. Configure database credentials

Edit the `.env` file in the project root:

```env
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=streamflix
SECRET_KEY=change-this-to-a-random-secret-key
```

### 6. Run the application

```bash
python app.py
```

Open your browser at **http://localhost:5000**

---

## 📁 Project Structure

```
dbms-python/
├── app.py                  # Flask routes & DB logic
├── schema.sql              # Full DDL + seed data
├── requirements.txt        # Python dependencies
├── .env                    # DB credentials (edit this)
├── README.md
├── static/
│   ├── style.css           # “Projection Booth” cinema-themed CSS
│   └── posters/            # Poster images (placeholders)
└── templates/
    ├── base.html           # Layout with navbar & footer
    ├── login.html          # Sign-in page
    ├── register.html       # Account creation page
    ├── home.html           # Home with genre rows
    ├── search.html         # Search results grid
    ├── detail.html         # Movie/series detail page
    └── mylist.html         # User's personal list
```

---

## 🔒 Security

- **Password hashing** via `werkzeug.security` (PBKDF2-SHA256)
- **Parameterized queries** everywhere — no string-formatted SQL
- **Session-based auth** with `login_required` decorator on all protected routes
- SQL injection safe by design

---

## 📝 Key SQL Queries Used

### Multi-table JOIN (Home page genre rows)
```sql
SELECT c.content_id, c.title, c.poster_url, c.type, c.avg_rating
FROM content c
JOIN content_genres cg ON cg.content_id = c.content_id
WHERE cg.genre_id = %s
ORDER BY c.avg_rating DESC;
```

### Aggregate + Subquery (Update average rating)
```sql
UPDATE content c
SET c.avg_rating = (
    SELECT ROUND(AVG(r.score), 1)
    FROM ratings r WHERE r.content_id = %s
)
WHERE c.content_id = %s;
```

### LIKE Search
```sql
SELECT c.*, GROUP_CONCAT(g.genre_name) AS genres
FROM content c
LEFT JOIN content_genres cg ON cg.content_id = c.content_id
LEFT JOIN genres g ON g.genre_id = cg.genre_id
WHERE c.title LIKE %s
GROUP BY c.content_id;
```

---

## 📜 License

This project is for **educational purposes** (college DBMS coursework).
