from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from src.api.routes import health, indices

app = FastAPI()

# CORS middleware configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Adjust this as necessary for your application
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include the routes
app.include_router(health.router)
app.include_router(indices.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to the API!"}