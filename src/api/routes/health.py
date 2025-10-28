from flask import Blueprint, jsonify

bp = Blueprint('health', __name__)

@bp.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "healthy", "service": "indexing-api"}), 200

@bp.route('/readiness', methods=['GET'])
def readiness_check():
    return jsonify({"status": "ready", "service": "indexing-api"}), 200