from flask import Flask
from flask_cors import CORS
from src.api.routes import health, indices, jobs

app = Flask(__name__)

# CORS configuration
CORS(app, 
     origins=["*"],  # Adjust this as necessary for your application
     supports_credentials=True,
     allow_headers=["*"],
     methods=["*"])

# Register blueprints (Flask equivalent of FastAPI routers)
app.register_blueprint(health.bp)
app.register_blueprint(indices.bp)
app.register_blueprint(jobs.bp)  # Add jobs blueprint

@app.route("/")
def read_root():
    return {"message": "Welcome to Indexing API!", "version": "1.0.0"}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5002, debug=False)