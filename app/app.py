import os
import time
from flask import Flask, jsonify
import psycopg2

app = Flask(__name__)

DB_HOST = os.environ.get("DB_HOST", "db")
DB_NAME = os.environ.get("DB_NAME", "appdb")
DB_USER = os.environ.get("DB_USER", "appuser")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "apppassword")


def get_db_connection(retries=5, delay=3):
    """Retry connecting to Postgres since the DB container may still be starting."""
    last_err = None
    for attempt in range(retries):
        try:
            conn = psycopg2.connect(
                host=DB_HOST, dbname=DB_NAME, user=DB_USER, password=DB_PASSWORD
            )
            return conn
        except Exception as e:
            last_err = e
            time.sleep(delay)
    raise last_err


@app.route("/")
def index():
    return jsonify({
        "status": "ok",
        "message": "Hello from the Flask backend! Routed through Nginx reverse proxy.",
        "hostname": os.environ.get("HOSTNAME", "unknown")
    })


@app.route("/health")
def health():
    """Used by infra_health_check.sh / container healthcheck."""
    return jsonify({"status": "healthy"}), 200


@app.route("/db-check")
def db_check():
    try:
        conn = get_db_connection(retries=1)
        cur = conn.cursor()
        cur.execute("SELECT version();")
        version = cur.fetchone()[0]
        cur.close()
        conn.close()
        return jsonify({"db_status": "connected", "version": version})
    except Exception as e:
        return jsonify({"db_status": "error", "detail": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
