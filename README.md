# ds-lab: the National Science Foundation

JT's personal data science lab: **one container image** (R + Python, Positron over SSH, Claude Code) that runs the same
on the Mac, on battlestation at home (over the tailnet) and in GCP for long jobs. Projects are git repos cloned into the
lab, not baked into the image. Personal work only: nothing from Honeylove goes in or out.

The plan and its decisions live in home-lab: `docs/ds-lab-plan.md`. Bigger personal projects later get tailored labs,
**departments of the NSF**: images built `FROM` this one.

## What's in the image

| | |
| - | - |
| R 4.6.2 | `rocker/r-ver:4.6.2`; ~45 packages (tidyverse, arrow, duckdb, tidymodels, mgcv, lme4, targets, gt, …) as binaries from a pinned Posit Package Manager snapshot (`CRAN_SNAPSHOT` in the Dockerfile); list in `r/packages.R` |
| Python 3.14 | `/opt/venv`, the "Python (NSF)" kernel; numpy, pandas, polars, scikit-learn, statsmodels, xgboost, lightgbm, … locked in `python/uv.lock` |
| Tools | Quarto 1.11.9, uv 0.13.9, git, the gcloud CLI, Claude Code (Anthropic's signed apt repo, stable channel) |
| Access | `sshd`: keys only, one user (`jt`), no root; host keys made per lab on first start, never in the image |
| Agents | Claude Code with managed settings: no auto-update; `git push` to main/master, force-pushes and GCP job/VM creation denied (a guard rail, not a lock) |
| Templates | `nsf-new <name>` in the lab's shell starts a project with the NSF `CLAUDE.md` and `.gitignore` |

Nothing secret is in the image. At run time the container takes:
- `/run/nsf/authorized_keys`: the public key(s) allowed in (required);
- `/run/nsf/secrets.env`: optional `KEY=value` lines (`ANTHROPIC_API_KEY`, `GH_TOKEN`, …), which reach SSH sessions
  through `/etc/environment` (readable by root and `jt` only). `NSF_GIT_NAME` and `NSF_GIT_EMAIL` there set who the
  lab's commits are by, once, on first start (new repos default to `main`).

## On the Mac

```sh
docker build -t nsf:dev .                                   # native arm64, ~4 minutes (Quarto comes from GitHub: slow some days, resumable)
docker run --rm --entrypoint /opt/nsf/smoke.sh nsf:dev      # the smoke test
scripts/run-local.sh                                        # the lab on 127.0.0.1:2222
```

`~/.ssh/config`:

```
Host nsf-local
    HostName 127.0.0.1
    Port 2222
    User jt
    IdentityFile ~/.ssh/nsf_ed25519
    IdentitiesOnly yes
    UserKnownHostsFile ~/.ssh/known_hosts_nsf
    StrictHostKeyChecking accept-new
```

Then in Positron: **Remote-SSH: Connect to Host… → nsf-local**. Projects live in `~/nsf/work` (the lab's `/work`), data
in `~/nsf/data` (`/data`); the lab user's home (Positron's server, ~2 GB) is the `nsf-home` volume.

## Changing the image

- **An R package**: add it to `r/packages.R`. The build fails if any package won't load or any compiled library is
  missing a system library, and says which. A newer CRAN: move `CRAN_SNAPSHOT`.
- **A Python package**: add it to `python/pyproject.toml`, then relock:
  `docker run --rm -v "$PWD/python":/p -w /p ghcr.io/astral-sh/uv:0.13.9-python3.14-trixie-slim uv lock`.
- Run the smoke test after every build; it records the versions it found.

## The registry (amd64, for battlestation and GCP)

Every push to `main` that touches the image builds it for amd64 on GitHub Actions (`.github/workflows/image.yml`),
runs the smoke test and pushes it to Artifact Registry:

    us-east1-docker.pkg.dev/house-282504/nsf/nsf:<commit>   and   :latest

No key is stored anywhere: the workflow trades GitHub's OIDC token for the `nsf-builder` service account (Workload
Identity Federation), which only this repo's `main` branch may use and which can only write to the `nsf` repository.
The Mac doesn't pull it: it builds its own arm64 copy from the same Dockerfile and locks (above). To pull elsewhere:

```sh
gcloud auth configure-docker us-east1-docker.pkg.dev     # with the personal (nsf) gcloud configuration
docker pull us-east1-docker.pkg.dev/house-282504/nsf/nsf:latest
```

## Still to come (see the plan)

battlestation's `lab` on the tailnet; Cloud Run Jobs and a VM in GCP; a `lab run` command.
