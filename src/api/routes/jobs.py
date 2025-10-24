from flask import Blueprint, jsonify, request
from kubernetes import client, config
import os
import time
from datetime import datetime

bp = Blueprint('jobs', __name__, url_prefix='/api')

# Load Kubernetes config
try:
    config.load_incluster_config()
except:
    config.load_kube_config()

batch_v1 = client.BatchV1Api()
core_v1 = client.CoreV1Api()

@bp.route('/jobs', methods=['POST'])
def create_job():
    """Create a new indexing job with configurable parallelism"""
    try:
        data = request.get_json()
        
        # Job configuration parameters
        job_name = data.get('job_name', f"indexing-job-{int(time.time())}")
        namespace = os.getenv('KUBERNETES_NAMESPACE', 'default')
        
        # Parallelism and retry configuration
        parallelism = data.get('parallelism', 3)  # Default: 3 parallel pods
        completions = data.get('completions', 1)  # Default: 1 completion needed
        backoff_limit = data.get('backoff_limit', 5)  # Default: 5 retries
        active_deadline = data.get('active_deadline_seconds', 3600)  # Default: 1 hour
        ttl_after_finished = data.get('ttl_seconds_after_finished', 86400)  # Default: 24 hours
        
        # Container configuration
        image = data.get('image', 'devbemindcontainerregistryse.azurecr.io/bemind-indexer:latest')
        job_env = data.get('env', {})
        
        # Resource limits
        cpu_request = data.get('cpu_request', '500m')
        memory_request = data.get('memory_request', '1Gi')
        cpu_limit = data.get('cpu_limit', '1000m')
        memory_limit = data.get('memory_limit', '2Gi')
        
        # Build environment variables
        env_vars = [
            client.V1EnvVar(
                name="JOB_NAME",
                value_from=client.V1EnvVarSource(
                    field_ref=client.V1ObjectFieldSelector(field_path="metadata.name")
                )
            ),
            client.V1EnvVar(
                name="POD_NAME",
                value_from=client.V1EnvVarSource(
                    field_ref=client.V1ObjectFieldSelector(field_path="metadata.name")
                )
            ),
            client.V1EnvVar(
                name="NAMESPACE",
                value_from=client.V1EnvVarSource(
                    field_ref=client.V1ObjectFieldSelector(field_path="metadata.namespace")
                )
            )
        ]
        
        # Add Azure credentials from secrets
        secret_env_vars = [
            'AZURE_OPENAI_ENDPOINT',
            'AZURE_OPENAI_API_KEY',
            'AZURE_SEARCH_ENDPOINT',
            'AZURE_SEARCH_KEY',
            'AZURE_STORAGE_CONNECTION_STRING'
        ]
        
        for env_name in secret_env_vars:
            env_vars.append(
                client.V1EnvVar(
                    name=env_name,
                    value_from=client.V1EnvVarSource(
                        secret_key_ref=client.V1SecretKeySelector(
                            name='bemind-secrets',
                            key=env_name
                        )
                    )
                )
            )
        
        # Add custom environment variables
        for k, v in job_env.items():
            env_vars.append(client.V1EnvVar(name=k, value=str(v)))
        
        # Define the job
        job = client.V1Job(
            api_version="batch/v1",
            kind="Job",
            metadata=client.V1ObjectMeta(
                name=job_name,
                namespace=namespace,
                labels={
                    'app': 'bemind-indexer',
                    'component': 'job',
                    'managed-by': 'bemind-api',
                    'job-type': data.get('job_type', 'indexing')
                },
                annotations={
                    'created-by': 'bemind-api',
                    'created-at': datetime.utcnow().isoformat()
                }
            ),
            spec=client.V1JobSpec(
                parallelism=parallelism,
                completions=completions,
                backoff_limit=backoff_limit,
                active_deadline_seconds=active_deadline,
                ttl_seconds_after_finished=ttl_after_finished,
                template=client.V1PodTemplateSpec(
                    metadata=client.V1ObjectMeta(
                        labels={
                            'app': 'bemind-indexer',
                            'component': 'job-pod',
                            'job-name': job_name
                        },
                        annotations={
                            'cluster-autoscaler.kubernetes.io/safe-to-evict': 'false'
                        }
                    ),
                    spec=client.V1PodSpec(
                        restart_policy="OnFailure",
                        service_account_name="bemind-indexer-sa",
                        containers=[
                            client.V1Container(
                                name="indexer",
                                image=image,
                                image_pull_policy="Always",
                                command=data.get('command', ["python"]),
                                args=data.get('args', ["-m", "src.indexer.main"]),
                                env=env_vars,
                                resources=client.V1ResourceRequirements(
                                    requests={
                                        'memory': memory_request,
                                        'cpu': cpu_request
                                    },
                                    limits={
                                        'memory': memory_limit,
                                        'cpu': cpu_limit
                                    }
                                ),
                                volume_mounts=[
                                    client.V1VolumeMount(
                                        name="temp-storage",
                                        mount_path="/tmp/indexing"
                                    )
                                ]
                            )
                        ],
                        volumes=[
                            client.V1Volume(
                                name="temp-storage",
                                empty_dir=client.V1EmptyDirVolumeSource(
                                    size_limit="5Gi"
                                )
                            )
                        ]
                    )
                )
            )
        )
        
        # Create the job
        created_job = batch_v1.create_namespaced_job(namespace, job)
        
        return jsonify({
            'message': 'Job created successfully',
            'job_name': created_job.metadata.name,
            'namespace': namespace,
            'configuration': {
                'parallelism': parallelism,
                'completions': completions,
                'backoff_limit': backoff_limit,
                'active_deadline_seconds': active_deadline
            },
            'status_url': f'/api/jobs/{created_job.metadata.name}/status',
            'created_at': created_job.metadata.creation_timestamp.isoformat() if created_job.metadata.creation_timestamp else None
        }), 201
    
    except Exception as e:
        return jsonify({
            'error': str(e),
            'message': 'Failed to create job'
        }), 500

@bp.route('/jobs/<job_name>/status', methods=['GET'])
def get_job_status_endpoint(job_name: str):
    """Get detailed status including parallelism metrics"""
    try:
        namespace = os.getenv('KUBERNETES_NAMESPACE', 'default')
        job = batch_v1.read_namespaced_job(job_name, namespace)
        
        # Get all pods for this job
        pods = core_v1.list_namespaced_pod(
            namespace,
            label_selector=f'job-name={job_name}'
        )
        
        # Aggregate pod statuses
        pod_statuses = []
        for pod in pods.items:
            pod_status = {
                'name': pod.metadata.name,
                'phase': pod.status.phase,
                'start_time': pod.status.start_time.isoformat() if pod.status.start_time else None,
                'restarts': sum(cs.restart_count for cs in (pod.status.container_statuses or [])),
                'node': pod.spec.node_name
            }
            
            # Get logs if available
            if pod.status.phase in ['Running', 'Succeeded', 'Failed']:
                try:
                    pod_status['logs'] = core_v1.read_namespaced_pod_log(
                        pod.metadata.name,
                        namespace,
                        tail_lines=20
                    )
                except:
                    pod_status['logs'] = "Logs not available"
            
            pod_statuses.append(pod_status)
        
        status = {
            'name': job.metadata.name,
            'namespace': namespace,
            'status': get_job_status(job),
            'created': job.metadata.creation_timestamp.isoformat() if job.metadata.creation_timestamp else None,
            'start_time': job.status.start_time.isoformat() if job.status.start_time else None,
            'completion_time': job.status.completion_time.isoformat() if job.status.completion_time else None,
            'configuration': {
                'parallelism': job.spec.parallelism,
                'completions': job.spec.completions,
                'backoff_limit': job.spec.backoff_limit,
                'active_deadline_seconds': job.spec.active_deadline_seconds
            },
            'metrics': {
                'succeeded': job.status.succeeded or 0,
                'active': job.status.active or 0,
                'failed': job.status.failed or 0,
                'ready': job.status.ready or 0,
                'total_pods': len(pod_statuses)
            },
            'conditions': [
                {
                    'type': c.type,
                    'status': c.status,
                    'reason': c.reason,
                    'message': c.message,
                    'last_transition_time': c.last_transition_time.isoformat() if c.last_transition_time else None
                } for c in (job.status.conditions or [])
            ],
            'pods': pod_statuses
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

@bp.route('/jobs', methods=['GET'])
def list_jobs():
    """List all jobs with metrics"""
    try:
        namespace = os.getenv('KUBERNETES_NAMESPACE', 'default')
        jobs = batch_v1.list_namespaced_job(namespace)
        
        job_list = []
        for job in jobs.items:
            job_list.append({
                'name': job.metadata.name,
                'status': get_job_status(job),
                'created': job.metadata.creation_timestamp.isoformat() if job.metadata.creation_timestamp else None,
                'configuration': {
                    'parallelism': job.spec.parallelism,
                    'completions': job.spec.completions,
                    'backoff_limit': job.spec.backoff_limit
                },
                'metrics': {
                    'succeeded': job.status.succeeded or 0,
                    'active': job.status.active or 0,
                    'failed': job.status.failed or 0
                },
                'labels': job.metadata.labels
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

@bp.route('/jobs/<job_name>', methods=['DELETE'])
def delete_job(job_name: str):
    """Delete a job and its pods"""
    try:
        namespace = os.getenv('KUBERNETES_NAMESPACE', 'default')
        
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
    """Determine job status"""
    if job.status.succeeded and job.status.succeeded >= (job.spec.completions or 1):
        return 'Completed'
    elif job.status.failed and job.status.failed >= (job.spec.backoff_limit or 6):
        return 'Failed'
    elif job.status.active:
        return 'Running'
    else:
        return 'Pending'