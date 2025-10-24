from flask import Blueprint, jsonify, request
from kubernetes import client, config
import os

bp = Blueprint('jobs', __name__, url_prefix='/api')

# Load Kubernetes config
try:
    config.load_incluster_config()  # Running inside cluster
except:
    config.load_kube_config()  # Running locally

batch_v1 = client.BatchV1Api()
core_v1 = client.CoreV1Api()

@bp.route('/jobs', methods=['GET'])
def list_jobs():
    """List all jobs in the namespace"""
    try:
        namespace = os.getenv('KUBERNETES_NAMESPACE', 'default')
        jobs = batch_v1.list_namespaced_job(namespace)
        
        job_list = []
        for job in jobs.items:
            job_list.append({
                'name': job.metadata.name,
                'status': get_job_status(job),
                'created': job.metadata.creation_timestamp.isoformat() if job.metadata.creation_timestamp else None,
                'completions': job.status.succeeded or 0,
                'active': job.status.active or 0,
                'failed': job.status.failed or 0
            })
        
        return jsonify({
            'jobs': job_list,
            'total': len(job_list)
        }), 200
    
    except Exception as e:
        return jsonify({
            'error': str(e),
            'message': 'Failed to list jobs'
        }), 500

@bp.route('/jobs/<job_name>/status', methods=['GET'])
def get_job_status_endpoint(job_name: str):
    """Get detailed status of a specific job"""
    try:
        namespace = os.getenv('KUBERNETES_NAMESPACE', 'default')
        job = batch_v1.read_namespaced_job(job_name, namespace)
        
        # Get pod logs if job is running or completed
        pod_logs = None
        pods = core_v1.list_namespaced_pod(
            namespace,
            label_selector=f'job-name={job_name}'
        )
        
        if pods.items:
            pod = pods.items[0]
            try:
                pod_logs = core_v1.read_namespaced_pod_log(
                    pod.metadata.name,
                    namespace,
                    tail_lines=50
                )
            except:
                pod_logs = "Logs not available yet"
        
        status = {
            'name': job.metadata.name,
            'namespace': namespace,
            'status': get_job_status(job),
            'created': job.metadata.creation_timestamp.isoformat() if job.metadata.creation_timestamp else None,
            'start_time': job.status.start_time.isoformat() if job.status.start_time else None,
            'completion_time': job.status.completion_time.isoformat() if job.status.completion_time else None,
            'succeeded': job.status.succeeded or 0,
            'active': job.status.active or 0,
            'failed': job.status.failed or 0,
            'conditions': [
                {
                    'type': c.type,
                    'status': c.status,
                    'reason': c.reason,
                    'message': c.message
                } for c in (job.status.conditions or [])
            ],
            'logs': pod_logs
        }
        
        return jsonify(status), 200
    
    except client.exceptions.ApiException as e:
        if e.status == 404:
            return jsonify({
                'error': 'Job not found',
                'job_name': job_name
            }), 404
        return jsonify({
            'error': str(e),
            'message': 'Failed to get job status'
        }), 500
    except Exception as e:
        return jsonify({
            'error': str(e),
            'message': 'Failed to get job status'
        }), 500

@bp.route('/jobs', methods=['POST'])
def create_job():
    """Create a new indexing job"""
    try:
        data = request.get_json()
        job_name = data.get('job_name', f"indexing-job-{int(time.time())}")
        namespace = os.getenv('KUBERNETES_NAMESPACE', 'default')
        
        # Define the job specification
        job = client.V1Job(
            api_version="batch/v1",
            kind="Job",
            metadata=client.V1ObjectMeta(
                name=job_name,
                labels={
                    'app': 'bemind-indexer',
                    'component': 'job'
                }
            ),
            spec=client.V1JobSpec(
                template=client.V1PodTemplateSpec(
                    metadata=client.V1ObjectMeta(
                        labels={
                            'app': 'bemind-indexer',
                            'component': 'job'
                        }
                    ),
                    spec=client.V1PodSpec(
                        restart_policy="Never",
                        service_account_name="bemind-indexer-sa",
                        containers=[
                            client.V1Container(
                                name="indexer",
                                image=data.get('image', 'devbemindcontainerregistryse.azurecr.io/bemind-indexer:latest'),
                                env=[
                                    client.V1EnvVar(name=k, value=v)
                                    for k, v in data.get('env', {}).items()
                                ],
                                resources=client.V1ResourceRequirements(
                                    requests={'memory': '512Mi', 'cpu': '250m'},
                                    limits={'memory': '1Gi', 'cpu': '500m'}
                                )
                            )
                        ]
                    )
                ),
                backoff_limit=3,
                ttl_seconds_after_finished=3600  # Cleanup after 1 hour
            )
        )
        
        # Create the job
        created_job = batch_v1.create_namespaced_job(namespace, job)
        
        return jsonify({
            'message': 'Job created successfully',
            'job_name': created_job.metadata.name,
            'namespace': namespace,
            'status_url': f'/api/jobs/{created_job.metadata.name}/status'
        }), 201
    
    except Exception as e:
        return jsonify({
            'error': str(e),
            'message': 'Failed to create job'
        }), 500

@bp.route('/jobs/<job_name>', methods=['DELETE'])
def delete_job(job_name: str):
    """Delete a job"""
    try:
        namespace = os.getenv('KUBERNETES_NAMESPACE', 'default')
        
        # Delete job and its pods
        batch_v1.delete_namespaced_job(
            job_name,
            namespace,
            propagation_policy='Foreground'
        )
        
        return jsonify({
            'message': 'Job deleted successfully',
            'job_name': job_name
        }), 200
    
    except client.exceptions.ApiException as e:
        if e.status == 404:
            return jsonify({
                'error': 'Job not found',
                'job_name': job_name
            }), 404
        return jsonify({
            'error': str(e),
            'message': 'Failed to delete job'
        }), 500

def get_job_status(job):
    """Determine job status from K8s Job object"""
    if job.status.succeeded:
        return 'Completed'
    elif job.status.failed:
        return 'Failed'
    elif job.status.active:
        return 'Running'
    else:
        return 'Pending'

import time