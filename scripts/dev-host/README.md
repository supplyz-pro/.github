# Dev host disk controls (SUP-313)

The 2026-10-28 incident exhausted the dev host root disk and crashed all CI runners.
Application data and CI builds shared the same filesystem.

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

`disk-check.sh` rejects less than 20 GiB free or usage at/above 85%. Install it as
`ACTIONS_RUNNER_HOOK_JOB_STARTED` on every dev runner. Restart idle runners after
updating their `.env`. The backend's independent hourly GitHub-hosted health check
checks this reserve, timer activity and maintenance failures. GitHub workflow
notification preferences determine who receives failure notifications.

New deployments use Docker's rotating local logger (3 x 10 MB per container).
Existing containers retain their current logging configuration until replaced.
After installing, verify `systemctl list-timers supplyz-dev-disk-maintenance.timer`,
run the maintenance service, and check `df -h /` plus the independent health workflow.
