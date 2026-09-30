# ─────────────────────────────────────────────────────────────
# StreamFlix  —  Flask Application
# ─────────────────────────────────────────────────────────────

import os
import functools
import time
from datetime import datetime

from flask import (
    Flask, render_template, request, redirect,
    url_for, session, flash, g, jsonify
)
from werkzeug.security import generate_password_hash, check_password_hash
import mysql.connector
from mysql.connector import pooling
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "streamflix-secret-key-change-me")

# ──────────────────────────────────────────────
# Database connection pool
# ──────────────────────────────────────────────
db_config = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "port":     int(os.getenv("DB_PORT", 3306)),
    "user":     os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", ""),
    "database": os.getenv("DB_NAME", "streamflix"),
}

pool = pooling.MySQLConnectionPool(
    pool_name="streamflix_pool",
    pool_size=5,
    **db_config
)


def get_db():
    """Return a connection from the pool (stored on `g` for the request)."""
    if "db" not in g:
        g.db = pool.get_connection()
    return g.db


@app.teardown_appcontext
def close_db(exc):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def query(sql, params=None, fetchone=False):
    """Helper — execute SELECT and return dict(s)."""
    conn = get_db()
    cur = conn.cursor(dictionary=True)
    cur.execute(sql, params or ())
    rows = cur.fetchone() if fetchone else cur.fetchall()
    cur.close()
    return rows


def execute(sql, params=None):
    """Helper — execute INSERT / UPDATE / DELETE and commit."""
    conn = get_db()
    cur = conn.cursor()
    cur.execute(sql, params or ())
    conn.commit()
    last_id = cur.lastrowid
    cur.close()
    return last_id


# ──────────────────────────────────────────────
# Auth decorator
# ──────────────────────────────────────────────
def login_required(view):
    @functools.wraps(view)
    def wrapped(**kwargs):
        if "user_id" not in session:
            flash("Please log in to continue.", "warning")
            return redirect(url_for("login"))
        return view(**kwargs)
    return wrapped


# Inject user info & last DB event into every template context
@app.context_processor
def inject_user():
    context = {"current_user": None, "last_db_event": None}
    if "user_id" in session:
        user = query(
            "SELECT user_id, name, email FROM users WHERE user_id = %s",
            (session["user_id"],),
            fetchone=True
        )
        context["current_user"] = user
    if "last_db_event" in session:
        context["last_db_event"] = session.pop("last_db_event")
    return context


# ──────────────────────────────────────────────
# ROUTES
# ──────────────────────────────────────────────

# ---- REGISTER ----
@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        name     = request.form.get("name", "").strip()
        email    = request.form.get("email", "").strip()
        password = request.form.get("password", "")

        if not name or not email or not password:
            flash("All fields are required.", "error")
            return redirect(url_for("register"))

        # Check duplicate email
        existing = query(
            "SELECT user_id FROM users WHERE email = %s",
            (email,),
            fetchone=True,
        )
        if existing:
            flash("An account with that email already exists.", "error")
            return redirect(url_for("register"))

        pw_hash = generate_password_hash(password)
        user_id = execute(
            "INSERT INTO users (name, email, password_hash) VALUES (%s, %s, %s)",
            (name, email, pw_hash),
        )

        session["last_db_event"] = {
            "title": "New Account Created & Saved",
            "table": "users",
            "type": "INSERT",
            "sql": "INSERT INTO users (name, email, password_hash) VALUES (%s, %s, %s)",
            "params": [name, email, "pbkdf2:sha256:..."],
            "details": f"Row inserted into table `users` for new user '{name}' ({email})."
        }

        flash("Account created! Please log in.", "success")
        return redirect(url_for("login"))

    return render_template("register.html")


# ---- LOGIN ----
@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        email    = request.form.get("email", "").strip()
        password = request.form.get("password", "")

        user = query(
            "SELECT user_id, name, password_hash FROM users WHERE email = %s",
            (email,),
            fetchone=True,
        )

        if user and check_password_hash(user["password_hash"], password):
            session.clear()
            session["user_id"]   = user["user_id"]
            session["user_name"] = user["name"]
            return redirect(url_for("home"))

        flash("Invalid email or password.", "error")
        return redirect(url_for("login"))

    return render_template("login.html")


# ---- LOGOUT ----
@app.route("/logout")
def logout():
    session.clear()
    flash("You have been logged out.", "info")
    return redirect(url_for("login"))


# ---- HOME ----
@app.route("/")
@login_required
def home():
    user_id = session["user_id"]

    # Featured Title for Hero Banner
    featured = query("""
        SELECT c.content_id, c.title, c.description, c.poster_url, c.type,
               c.avg_rating, c.release_year,
               GROUP_CONCAT(g.genre_name ORDER BY g.genre_name SEPARATOR ' • ') AS genres
        FROM content c
        LEFT JOIN content_genres cg ON cg.content_id = c.content_id
        LEFT JOIN genres g ON g.genre_id = cg.genre_id
        WHERE c.avg_rating >= 8.5
        GROUP BY c.content_id
        ORDER BY c.avg_rating DESC
        LIMIT 1
    """, fetchone=True)

    # Continue Watching — JOIN watch_history + content
    continue_watching = query("""
        SELECT c.content_id, c.title, c.poster_url, c.type,
               wh.progress_mins, wh.last_watched,
               COALESCE(c.duration_mins,
                   (SELECT SUM(e.duration_mins) FROM episodes e
                    WHERE e.content_id = c.content_id)) AS total_mins
        FROM watch_history wh
        JOIN content c ON c.content_id = wh.content_id
        WHERE wh.user_id = %s
        ORDER BY wh.last_watched DESC
        LIMIT 20
    """, (user_id,))

    # Build rows by genre — JOIN content, content_genres, genres
    genres = query("SELECT genre_id, genre_name FROM genres ORDER BY genre_name")

    genre_rows = []
    for g_row in genres:
        items = query("""
            SELECT c.content_id, c.title, c.poster_url, c.type,
                   c.avg_rating, c.release_year
            FROM content c
            JOIN content_genres cg ON cg.content_id = c.content_id
            WHERE cg.genre_id = %s
            ORDER BY c.avg_rating DESC
        """, (g_row["genre_id"],))
        if items:
            genre_rows.append({"genre": g_row["genre_name"], "content_list": items})

    return render_template(
        "home.html",
        featured=featured,
        continue_watching=continue_watching,
        genre_rows=genre_rows,
    )


# ---- SEARCH ----
@app.route("/search")
@login_required
def search():
    q = request.args.get("q", "").strip()
    results = []
    if q:
        like_term = f"%{q}%"
        results = query("""
            SELECT c.content_id, c.title, c.description, c.poster_url, c.type,
                   c.avg_rating, c.release_year,
                   GROUP_CONCAT(DISTINCT g.genre_name ORDER BY g.genre_name SEPARATOR ', ') AS genres
            FROM content c
            LEFT JOIN content_genres cg ON cg.content_id = c.content_id
            LEFT JOIN genres g ON g.genre_id = cg.genre_id
            WHERE c.title LIKE %s 
               OR c.description LIKE %s 
               OR g.genre_name LIKE %s 
               OR c.type LIKE %s
            GROUP BY c.content_id
            ORDER BY c.avg_rating DESC
        """, (like_term, like_term, like_term, like_term))

        if request.headers.get("X-Requested-With") == "XMLHttpRequest" or request.args.get("format") == "json":
            return jsonify(results)

    return render_template("search.html", results=results, query=q)


# ---- DETAIL (movie / series) ----
@app.route("/title/<int:content_id>")
@login_required
def detail(content_id):
    user_id = session["user_id"]

    item = query("""
        SELECT c.*,
               GROUP_CONCAT(g.genre_name ORDER BY g.genre_name SEPARATOR ', ') AS genres
        FROM content c
        LEFT JOIN content_genres cg ON cg.content_id = c.content_id
        LEFT JOIN genres g ON g.genre_id = cg.genre_id
        WHERE c.content_id = %s
        GROUP BY c.content_id
    """, (content_id,), fetchone=True)

    if not item:
        flash("Title not found.", "error")
        return redirect(url_for("home"))

    episodes = []
    if item["type"] == "series":
        episodes = query("""
            SELECT * FROM episodes
            WHERE content_id = %s
            ORDER BY season_number, episode_number
        """, (content_id,))

    # Check if already in My List
    in_list = query(
        "SELECT 1 FROM my_list WHERE user_id = %s AND content_id = %s",
        (user_id, content_id),
        fetchone=True,
    )

    # User's rating (if any)
    user_rating = query(
        "SELECT score FROM ratings WHERE user_id = %s AND content_id = %s",
        (user_id, content_id),
        fetchone=True,
    )

    return render_template(
        "detail.html",
        item=item,
        episodes=episodes,
        in_list=bool(in_list),
        user_rating=user_rating["score"] if user_rating else None,
    )


# ---- ADD TO MY LIST ----
@app.route("/mylist/add/<int:content_id>", methods=["POST"])
@login_required
def add_to_list(content_id):
    user_id = session["user_id"]
    status = "success"
    msg = "Added to My List!"
    try:
        execute(
            "INSERT INTO my_list (user_id, content_id) VALUES (%s, %s)",
            (user_id, content_id),
        )
        flash("Added to My List!", "success")
    except mysql.connector.IntegrityError:
        status = "info"
        msg = "Already in your list."
        flash("Already in your list.", "info")

    if request.headers.get("X-Requested-With") == "XMLHttpRequest" or request.args.get("ajax"):
        return jsonify({"success": status == "success", "status": status, "message": msg, "table": "my_list"})
    return redirect(url_for("detail", content_id=content_id))


# ---- REMOVE FROM MY LIST ----
@app.route("/mylist/remove/<int:content_id>", methods=["POST"])
@login_required
def remove_from_list(content_id):
    user_id = session["user_id"]
    execute(
        "DELETE FROM my_list WHERE user_id = %s AND content_id = %s",
        (user_id, content_id),
    )
    flash("Removed from My List.", "info")
    if request.headers.get("X-Requested-With") == "XMLHttpRequest" or request.args.get("ajax"):
        return jsonify({"success": True, "status": "info", "message": "Removed from My List.", "table": "my_list"})
    return redirect(url_for("detail", content_id=content_id))


# ---- RATE CONTENT ----
@app.route("/rate/<int:content_id>", methods=["POST"])
@login_required
def rate(content_id):
    user_id = session["user_id"]
    score = int(request.form.get("score", 5))
    score = max(1, min(10, score))

    existing = query(
        "SELECT 1 FROM ratings WHERE user_id = %s AND content_id = %s",
        (user_id, content_id),
        fetchone=True,
    )
    if existing:
        execute(
            "UPDATE ratings SET score = %s, rated_at = NOW() WHERE user_id = %s AND content_id = %s",
            (score, user_id, content_id),
        )
    else:
        execute(
            "INSERT INTO ratings (user_id, content_id, score) VALUES (%s, %s, %s)",
            (user_id, content_id, score),
        )

    execute("""
        UPDATE content c
        SET c.avg_rating = (
            SELECT ROUND(AVG(r.score), 1)
            FROM ratings r
            WHERE r.content_id = %s
        )
        WHERE c.content_id = %s
    """, (content_id, content_id))

    msg = f"Rated {score}/10!"
    flash(msg, "success")
    if request.headers.get("X-Requested-With") == "XMLHttpRequest" or request.args.get("ajax"):
        new_avg = query("SELECT avg_rating FROM content WHERE content_id = %s", (content_id,), fetchone=True)
        return jsonify({"success": True, "status": "success", "message": msg, "table": "ratings", "new_avg": new_avg["avg_rating"] if new_avg else None})
    return redirect(url_for("detail", content_id=content_id))


# ---- PLAY (record to watch_history) ----
@app.route("/play/<int:content_id>", methods=["POST"])
@login_required
def play(content_id):
    user_id = session["user_id"]
    episode_id = request.form.get("episode_id")
    episode_id = int(episode_id) if episode_id else None

    execute("""
        INSERT INTO watch_history (user_id, content_id, episode_id, progress_mins)
        VALUES (%s, %s, %s, %s)
    """, (user_id, content_id, episode_id, 0))

    item = query("SELECT title, poster_url, type FROM content WHERE content_id = %s", (content_id,), fetchone=True)

    msg = "Playing now — added to Continue Watching."
    flash(msg, "success")
    if request.headers.get("X-Requested-With") == "XMLHttpRequest" or request.args.get("ajax"):
        return jsonify({
            "success": True,
            "status": "success",
            "message": msg,
            "table": "watch_history",
            "title": item["title"] if item else "StreamFlix Selection",
            "poster_url": item["poster_url"] if item else "",
            "type": item["type"] if item else "movie"
        })
    return redirect(url_for("detail", content_id=content_id))


# ---- MY LIST PAGE ----
@app.route("/mylist")
@login_required
def my_list_page():
    user_id = session["user_id"]
    items = query("""
        SELECT c.content_id, c.title, c.poster_url, c.type,
               c.avg_rating, c.release_year,
               ml.added_at
        FROM my_list ml
        JOIN content c ON c.content_id = ml.content_id
        WHERE ml.user_id = %s
        ORDER BY ml.added_at DESC
    """, (user_id,))
    return render_template("mylist.html", items=items)


# ──────────────────────────────────────────────
# Run
# ──────────────────────────────────────────────
if __name__ == "__main__":
    app.run(debug=True, port=5000)


