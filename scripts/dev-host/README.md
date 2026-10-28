# Dev host disk controls (SUP-313)

The 2026-10-28 incident exhausted the dev host root disk and crashed all CI runners.
Application data and CI builds shared the same filesystem. The two runners had
39 GiB of abandoned MongoDB test databases in `/tmp` (46 GiB total writable data).

CI for frontend, backend and Dali now defaults to GitHub-hosted runners. The shared
Docker build workflow also builds remotely. The dev host only receives images and
deployments. `CI_RUNNER=["ubuntu-latest"]` is set on those three repositories.

Run `sudo bash install.sh` from this directory on the dev host. This installs an
hourly maintenance timer, bounded journal retention, and a disk check. Maintenance
prunes only disposable Docker build cache and images unreferenced by containers.
It never prunes Docker volumes or running containers. Retained rollback containers
keep their images protected. Under 25 GiB free it also prunes recent unused cache
and unreferenced images older than 48 hours. A failed maintenance unit requires
investigation; do not delete database volumes to make it pass.

`disk-check.sh` rejects less than 20 GiB free or usage at/above 85%. Copy
`disk-check.sh`, `runner-cleanup.sh`, `runner-start.sh` into `/home/runner/` with
the `supplyz-` prefix, executable by the runner. Set
`ACTIONS_RUNNER_HOOK_JOB_STARTED=/home/runner/supplyz-runner-start.sh` and
`ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/home/runner/supplyz-runner-cleanup.sh` in
each runner `.env`, then restart idle runners. Cleanup removes isolated MongoDB
and Jest scratch directories older than one hour, and diagnostics older than
seven days. It refuses cleanup while any MongoDB test process remains alive. The backend's independent hourly GitHub-hosted health check
checks this reserve, timer activity and maintenance failures. GitHub workflow
notification preferences determine who receives failure notifications.

New deployments use Docker's rotating local logger (3 x 10 MB per container).
Existing containers retain their current logging configuration until replaced.
After installing, verify `systemctl list-timers supplyz-dev-disk-maintenance.timer`,
run the maintenance service, and check `df -h /` plus the independent health workflow.

## Existing ClickHouse log storm

After disk recovery ClickHouse's failed file logger repeatedly wrote errors to
an unbounded Docker JSON log, which grew past 35 GiB. New deployment defaults do
not change existing container logging. Run `sudo python3 bound-clickhouse-logs.py`
on the dev host, validate Compose, then recreate only the ClickHouse service:

```sh
cd /home/sami/langfuse-observe
sudo docker compose -f docker-compose.yml -f docker-compose.override.yml config --quiet
sudo docker compose -f docker-compose.yml -f docker-compose.override.yml up -d --no-deps --force-recreate clickhouse
```

The script backs up the existing override and preserves service settings and data
mounts. It routes ClickHouse diagnostics to the console and caps Docker's local
logs at 3 x 10 MB. Verify `SELECT 1`, unchanged data mounts, bounded logging, and
stable free disk space. This recovered dev to about 61 GiB free / 51% used.
