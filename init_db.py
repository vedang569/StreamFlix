# ─────────────────────────────────────────────────────────────
# StreamFlix  —  Database Initializer
# Runs schema.sql using python mysql-connector
# ─────────────────────────────────────────────────────────────

import os
from dotenv import load_dotenv
import mysql.connector

load_dotenv()

def init_db():
    host = os.getenv("DB_HOST", "localhost")
    port = int(os.getenv("DB_PORT", 3306))
    user = os.getenv("DB_USER", "root")
    password = os.getenv("DB_PASSWORD", "")

    print(f"Connecting to MySQL server at {host}:{port} as '{user}'...")
    
    # Connect without specifying database first (to create database if needed)
    conn = mysql.connector.connect(
        host=host,
        port=port,
        user=user,
        password=password
    )
    cursor = conn.cursor()

    schema_file = "schema.sql"
    if not os.path.exists(schema_file):
        print(f"Error: {schema_file} not found!")
        return

    print(f"Reading {schema_file}...")
    with open(schema_file, "r", encoding="utf-8") as f:
        sql_script = f.read()

    print("Executing database schema & seed data...")
    # Execute multi-statement SQL script
    for result in cursor.execute(sql_script, multi=True):
        if result.with_rows:
            result.fetchall()

    conn.commit()
    cursor.close()
    conn.close()

    print("\n[OK] Database 'streamflix' successfully created and seeded!")

if __name__ == "__main__":
    init_db()
