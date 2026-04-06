"""
Flask backend updates for reports integration.
Apply these snippets into your existing Flask app (do not remove current APIs).
"""

from flask import jsonify, request
import psycopg

# Reuse your current DATABASE_URL setting from Render environment.
DATABASE_URL = "YOUR_RENDER_POSTGRES_DATABASE_URL"


def get_db_connection():
    return psycopg.connect(DATABASE_URL)


# 1) INIT ROUTE: creates reports table if it does not exist.
@app.route('/api/init-db', methods=['GET'])
def init_db():
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS reports (
                    id SERIAL PRIMARY KEY,
                    user_id INT,
                    prediction TEXT,
                    confidence FLOAT,
                    risk_level TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                """
            )
        conn.commit()

    return "Reports table created", 200


def derive_risk_level(prediction: str, confidence: float) -> str:
    prediction_text = (prediction or "").lower()

    if "no tumor" in prediction_text:
        return "Low"
    if confidence >= 80:
        return "High"
    if confidence >= 50:
        return "Medium"
    return "Low"


def insert_report_record(user_id: int, prediction: str, confidence: float) -> None:
    """Stores report row for one prediction result."""
    risk_level = derive_risk_level(prediction, confidence)

    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO reports (user_id, prediction, confidence, risk_level)
                VALUES (%s, %s, %s, %s)
                """,
                (user_id, prediction, confidence, risk_level),
            )
        conn.commit()


# 2) PREDICT ROUTE INTEGRATION:
# Add this block near the end of your existing /api/predict route,
# after you compute prediction + confidence and before returning JSON.
#
# user_id_raw = request.form.get("user_id") or request.args.get("user_id")
# if user_id_raw is None and request.is_json:
#     body = request.get_json(silent=True) or {}
#     user_id_raw = body.get("user_id")
#
# if user_id_raw is not None:
#     try:
#         insert_report_record(
#             user_id=int(user_id_raw),
#             prediction=str(prediction),
#             confidence=float(confidence),
#         )
#     except Exception as report_error:
#         # Keep predict API non-breaking even if report save fails.
#         app.logger.error(f"Report insert failed: {report_error}")


# 3) OPTIONAL REPORTS API:
@app.route('/api/reports', methods=['GET'])
def get_reports():
    user_id = request.args.get('user_id', type=int)
    if user_id is None:
        return jsonify({'error': 'user_id is required'}), 400

    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, user_id, prediction, confidence, risk_level, created_at
                FROM reports
                WHERE user_id = %s
                ORDER BY created_at DESC
                """,
                (user_id,),
            )
            rows = cur.fetchall()

    reports = [
        {
            'id': row[0],
            'user_id': row[1],
            'prediction': row[2],
            'confidence': row[3],
            'risk_level': row[4],
            'created_at': row[5].isoformat() if row[5] else None,
        }
        for row in rows
    ]

    return jsonify(reports), 200
