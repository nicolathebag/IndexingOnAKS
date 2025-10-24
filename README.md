# k8s-indexer-deployment

## Overview
This project is designed to manage indexing jobs and provide an API for interacting with those jobs. It includes functionality for handling blob storage, converting PDF files, and managing indices.

## Project Structure
- **src/**: Contains the source code for the application.
  - **api/**: The API layer of the application.
    - **app.py**: Main application logic and server setup.
    - **routes/**: Contains route definitions for the API.
      - **health.py**: Health check route.
      - **indices.py**: Routes for index management.
  - **indexer/**: Contains logic for managing indexing jobs.
    - **job.py**: Job management and scheduling.
    - **processors/**: Contains various processors for handling files.
      - **blob_handler.py**: Functions for blob storage operations.
      - **pdf_converter.py**: PDF conversion functionality.
      - **search_indexer.py**: Document indexing logic.
  - **utils/**: Utility functions for the application.
    - **auth.py**: Authentication-related functions.
    - **logger.py**: Logging functionality.

- **k8s/**: Contains Kubernetes configuration files.
  - **namespace.yaml**: Defines the Kubernetes namespace.
  - **configmap.yaml**: Configuration data for the application.
  - **secrets.yaml**: Sensitive information for the application.
  - **api-deployment.yaml**: Deployment configuration for the API.
  - **api-service.yaml**: Service configuration for the API.
  - **indexer-cronjob.yaml**: Cron job configuration for the indexer.
  - **rbac.yaml**: Role-Based Access Control configurations.

- **scripts/**: Contains deployment and cleanup scripts.
  - **deploy.sh**: Script for deploying the application.
  - **cleanup.sh**: Script for cleaning up resources.

- **requirements.txt**: Lists Python dependencies for the project.

- **.dockerignore**: Specifies files to ignore when building Docker images.

## Setup Instructions
1. Clone the repository.
2. Navigate to the project directory.
3. Install the required dependencies:
   ```
   pip install -r requirements.txt
   ```
4. Configure Kubernetes resources as needed.
5. Deploy the application using the provided scripts.

## Usage
- Start the application by running `app.py`.
- Access the API at the configured endpoint.
- Use the health check route to monitor the application's status.

## Contributing
Contributions are welcome! Please submit a pull request or open an issue for any enhancements or bug fixes.