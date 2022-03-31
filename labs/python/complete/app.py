# app.py

# Required imports
import os
from flask import Flask, request, jsonify
from google.cloud import spanner

# Initialize Flask app
app = Flask(__name__)

# Initialize Spanner client
# Your Cloud Spanner instance ID.
instance_id = "music-catalog"
#
# Your Cloud Spanner database ID.
database_id = "musicians"


# Instantiate a client.
spanner_client = spanner.Client()

# Get a Cloud Spanner instance by ID.
instance = spanner_client.instance(instance_id)

# Get a Cloud Spanner database by ID.
database = instance.database(database_id)


@app.route("/")
def hello_world():
    return "<p>Hello, World!</p>"

@app.route('/add', methods=['POST'])
def create():
    """
        create() : Add a new entry to Spanner with request body.
        Sample Request:
        curl -X POST http://localhost:8080/add -H 'Content-Type: application/json' -d '{"first_name":"Cat","last_name":"Meow", "singer_id": 6}'
    """
    try:
        request_json = request.get_json()
        singer_id = request_json['singer_id']
        first_name = request_json['first_name']
        last_name = request_json['last_name']
        def insert_singers(transaction):
            row_ct = transaction.execute_update(
                f"INSERT Singers (SingerId, FirstName, LastName) VALUES" \
                f"({singer_id}, '{first_name}', '{last_name}')"
            )
            print("{} record(s) inserted.".format(row_ct))

        database.run_in_transaction(insert_singers)

        return {"Success": True}, 200
    except Exception as e:
        return e

@app.route('/get-singer', methods=['GET'])
def get_singer():
    """
        create() : Add a new entry to Spanner with request body.
        Sample Request:
        curl -X GET http://localhost:8080/get-singer?singer_id=6
    """

    try:
        singer_id = request.args.get('singer_id')
        def get_singer():
            first_name = ''
            last_name = ''
            with database.snapshot() as snapshot:
                results = snapshot.execute_sql(
                    f"SELECT SingerId, FirstName, LastName FROM Singers " \
                    f"where SingerId = {singer_id}",
                    )
                for row in results:
                    first_name = row[1]
                    last_name = row[2]
                return (first_name,last_name )
        first_name, last_name = get_singer()  
        return {"first_name": first_name, "last_name": last_name }, 200
    except Exception as e:
        return e

@app.route('/update-first-name', methods=['PUT'])
def update_singer_first_name():
    """
        delete() : Delete an entry from Spanner.
        Sample Request:
        curl -X PUT http://localhost:8080/update-first-name?singer_id=6 -H 'Content-Type: application/json' -d '{"first_name":"Bow"}'
    """
    try:
        singer_id = request.args.get('singer_id')
        request_json = request.get_json()
        first_name = request_json['first_name']
        
        def update_singer(transaction):
            row_ct = transaction.execute_update(
                f"UPDATE Singers SET FirstName = '{first_name}' WHERE SingerId = {singer_id}"
            )

            print("{} record(s) updated.".format(row_ct))

        database.run_in_transaction(update_singer)
        return {"Success": True}, 200
    except Exception as e:
        return e

@app.route('/delete-singer', methods=['DELETE'])
def delete_singer():
    """
        delete() : Delete an entry from Spanner.
        Sample Request:
        curl -X DELETE http://localhost:8080/get-singer?singer_id=6
    """
    try:
        singer_id = request.args.get('singer_id')
    
        def delete_singer(transaction):
            row_ct = transaction.execute_update(
                f"DELETE FROM Singers WHERE SingerId = {singer_id}"
            )
            print("{} record(s) deleted.".format(row_ct))

        database.run_in_transaction(delete_singer)
        return {"Success": True}, 200
    except Exception as e:
        return e

port = int(os.environ.get('PORT', 8080))
if __name__ == '__main__':
    app.run(threaded=True, host='0.0.0.0', port=port)