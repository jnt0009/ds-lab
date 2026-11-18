# <project name>: a National Science Foundation project

A personal data science project in the NSF lab (https://github.com/jnt0009/ds-lab). Replace this first section with
what the project is for and where its data comes from.

## The lab

- This repo lives in `/work/<project>` inside the NSF container. R 4.6 and Python 3.14 (`/opt/venv`, the "Python
  (NSF)" kernel) are already installed with the lab's base packages; Quarto, uv, git and gcloud are on the PATH.
- **Packages:** the base set is in the image. A package only this project needs goes in its own lock: `renv` for R
  (`renv::init()` once, then `renv::install()` / `renv::snapshot()`), `uv add <pkg>` for Python. Never `sudo` or
  install into the image's libraries.
- **Data:** raw data in `data/raw/` (never edited), intermediate and results in `data/`; anything big or downloaded
  goes in `/data/<project>/` instead. **Data is never committed** (see `.gitignore`). Outputs (figures, reports) in
  `artifacts/`.
- **Secrets** come from the environment (e.g. `ANTHROPIC_API_KEY`); never write a key into a file in the repo.

## Working here as an agent

- **Run the code you change** and look at its output before saying it works.
- **Git:** commit on a branch named `agent/<short-task>`; push that branch. **Never push to `main`**, never force-push,
  never rewrite history JT has pushed. JT merges.
- **Jobs:** running scripts and long jobs in this container (or at home) is fine. **Anything in GCP that costs money**
  (Cloud Run jobs, VMs) needs JT's OK first: ask, and stop.
- **Done means:** the branch pushed, and a short summary of what changed, what was run, and what's left.
