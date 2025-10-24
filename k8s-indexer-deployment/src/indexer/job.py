class IndexerJob:
    def __init__(self):
        self.jobs = []

    def schedule_job(self, job):
        self.jobs.append(job)
        print(f"Job '{job}' scheduled.")

    def execute_jobs(self):
        for job in self.jobs:
            print(f"Executing job: {job}")
            # Logic to execute the job goes here
            self.jobs.remove(job)

    def get_scheduled_jobs(self):
        return self.jobs

if __name__ == "__main__":
    indexer_job = IndexerJob()
    indexer_job.schedule_job("Indexing documents")
    indexer_job.execute_jobs()