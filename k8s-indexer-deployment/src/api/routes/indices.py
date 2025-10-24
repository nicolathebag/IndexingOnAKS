from flask import Blueprint, request, jsonify

indices_bp = Blueprint('indices', __name__)

@indices_bp.route('/indices', methods=['POST'])
def create_index():
    data = request.json
    # Logic to create an index using data
    return jsonify({"message": "Index created", "data": data}), 201

@indices_bp.route('/indices/<index_id>', methods=['GET'])
def get_index(index_id):
    # Logic to retrieve an index by index_id
    return jsonify({"message": "Index retrieved", "index_id": index_id})

@indices_bp.route('/indices/<index_id>', methods=['PUT'])
def update_index(index_id):
    data = request.json
    # Logic to update an index using index_id and data
    return jsonify({"message": "Index updated", "index_id": index_id, "data": data})

@indices_bp.route('/indices/<index_id>', methods=['DELETE'])
def delete_index(index_id):
    # Logic to delete an index by index_id
    return jsonify({"message": "Index deleted", "index_id": index_id})