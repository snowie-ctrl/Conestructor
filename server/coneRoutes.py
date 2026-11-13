from flask import Blueprint, jsonify, request, send_file
from pathlib import Path
import mysql.connector, re

from . import DBUtils


# ---------------------------------------------------------
# Configuration
# ---------------------------------------------------------

TRACK_ROOT = Path("/pool/appFiles/conestructor/tracks")


# ---------------------------------------------------------
# Blueprint
# ---------------------------------------------------------

coneBP = Blueprint(
    "cone",
    __name__
)


# ---------------------------------------------------------
# Database
# ---------------------------------------------------------

def getDB():
    return DBUtils.initConnection("cone")


def sanitize_name_part(value):
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-") or "track"


# ---------------------------------------------------------
# GET TILE DATA
#
# GET /api/cone/tracks/5
#
# GET /api/cone/tracks/5?exclude=1,2,3
# ---------------------------------------------------------

@coneBP.route("/tracks/get", methods=["POST"])
def get_tile_data():

    data = request.get_json(silent=True) or {}

    num_tiles = data.get("numTiles", 0)
    used_ids = data.get("usedIDs", [])


    # Validate numTiles
    try:
        num_tiles = int(num_tiles)

    except (TypeError, ValueError):

        return jsonify({
            "error": "numTiles must be an integer"
        }), 400


    if num_tiles <= 0:

        return jsonify({
            "error": "numTiles must be greater than 0"
        }), 400


    # Validate usedIDs
    try:

        excluded_ids = [
            int(track_id)
            for track_id in used_ids
        ]

    except (TypeError, ValueError):

        return jsonify({
            "error": "usedIDs must contain only integer IDs"
        }), 400


    connection = None
    cursor = None


    try:

        connection = getDB()

        cursor = connection.cursor(
            dictionary=True
        )


        query = """
            SELECT
                id,
                location,
                numCones,
                processingType

            FROM tracks
        """


        parameters = []


        if excluded_ids:

            placeholders = ", ".join(
                ["%s"] * len(excluded_ids)
            )


            query += f"""
                WHERE id NOT IN ({placeholders})
            """


            parameters.extend(
                excluded_ids
            )


        query += """
            ORDER BY RAND()
            LIMIT %s
        """


        parameters.append(
            num_tiles
        )


        cursor.execute(
            query,
            parameters
        )


        tracks = cursor.fetchall()


        return jsonify(
            tracks
        ), 200


    except mysql.connector.Error as error:

        print(
            f"MySQL error while getting tile data: {error}"
        )


        return jsonify({
            "error": "Database error"
        }), 500


    finally:

        if cursor is not None:
            cursor.close()


        if connection is not None:
            connection.close()


# ---------------------------------------------------------
# GET THUMBNAIL
#
# GET /api/cone/tracks/5/thumbnail
# ---------------------------------------------------------

@coneBP.route(
    "/tracks/<int:track_id>/thumbnail",
    methods=["GET"]
)
def get_thumbnail(track_id):

    connection = None
    cursor = None


    try:

        connection = getDB()

        cursor = connection.cursor()


        cursor.execute(
            """
            SELECT thumbnailPath
            FROM tracks
            WHERE id = %s
            """,
            (track_id,)
        )


        result = cursor.fetchone()


        if result is None:

            return jsonify({
                "error": "Track not found"
            }), 404


        relative_path = Path(
            result[0]
        )


        full_path = (
            TRACK_ROOT / relative_path
        ).resolve()


        if not full_path.is_file():

            return jsonify({
                "error": "Thumbnail file not found"
            }), 404


        return send_file(
            str(full_path)
        )


    except mysql.connector.Error as error:

        print(
            f"MySQL error while getting thumbnail: {error}"
        )


        return jsonify({
            "error": "Database error"
        }), 500


    finally:

        if cursor is not None:
            cursor.close()


        if connection is not None:
            connection.close()


# ---------------------------------------------------------
# GET TRACK FILE
#
# GET /api/cone/tracks/5/file
# ---------------------------------------------------------

@coneBP.route(
    "/tracks/<int:track_id>/file",
    methods=["GET"]
)
def get_track_file(track_id):

    connection = None
    cursor = None


    try:

        connection = getDB()

        cursor = connection.cursor()


        cursor.execute(
            """
            SELECT filePath
            FROM tracks
            WHERE id = %s
            """,
            (track_id,)
        )


        result = cursor.fetchone()


        if result is None:

            return jsonify({
                "error": "Track not found"
            }), 404


        relative_path = Path(
            result[0]
        )


        full_path = (
            TRACK_ROOT / relative_path
        ).resolve()


        if not full_path.is_file():

            return jsonify({
                "error": "Track file not found"
            }), 404


        return send_file(
            str(full_path)
        )


    except mysql.connector.Error as error:

        print(
            f"MySQL error while getting track file: {error}"
        )


        return jsonify({
            "error": "Database error"
        }), 500


    finally:

        if cursor is not None:
            cursor.close()


        if connection is not None:
            connection.close()
            
            
            
            
            
            
            
@coneBP.route(
    "/tracks/reserve",
    methods=["POST"]
)
def reserve_track_directory():

    data = request.get_json(silent=True) or {}

    location = data.get("location", "")
    processing_type = data.get("processingType", "")

    if not location or not processing_type:
        return jsonify({
            "error": "location and processingType are required"
        }), 400

    location_part = sanitize_name_part(location)
    processing_part = sanitize_name_part(processing_type)

    counter = 1
    candidate_path = None
    candidate_name = None

    while True:
        candidate_name = f"{location_part}_{processing_part}_{counter}"
        candidate_path = TRACK_ROOT / candidate_name

        if not candidate_path.exists():
            break

        counter += 1

    try:
        candidate_path.mkdir(parents=True, exist_ok=False)

    except OSError as error:
        print(f"Error creating track directory: {error}")
        return jsonify({
            "error": "Could not reserve track directory"
        }), 500

    return jsonify({
        "dirName": candidate_name
    }), 201
    
    
    

@coneBP.route(
    "/tracks/upload",
    methods=["POST"]
)
def create_track():

    data = request.get_json(silent=True) or {}

    required_fields = ["location", "numCones", "processingType", "thumbnailPath", "filePath"]

    if not all(field in data for field in required_fields):
        return jsonify({
            "error": f"Missing required fields: {required_fields}"
        }), 400

    connection = None
    cursor = None

    try:
        connection = getDB()
        cursor = connection.cursor()

        cursor.execute(
            """
            INSERT INTO tracks (location, numCones, processingType, thumbnailPath, filePath)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (
                data["location"],
                data["numCones"],
                data["processingType"],
                data["thumbnailPath"],
                data["filePath"]
            )
        )

        connection.commit()
        track_id = cursor.lastrowid

        return jsonify({
            "id": track_id
        }), 201

    except mysql.connector.Error as error:
        print(f"MySQL error while creating track: {error}")
        return jsonify({
            "error": "Database error"
        }), 500

    finally:
        if cursor is not None:
            cursor.close()

        if connection is not None:
            connection.close()