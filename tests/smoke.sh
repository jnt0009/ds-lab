#!/bin/sh
# The NSF image's smoke test: everything it promises loads and runs. Run inside the image:
#   docker run --rm --entrypoint /opt/nsf/smoke.sh nsf:dev
set -e
fail=0
check() { if sh -c "$2" >/tmp/smoke.out 2>&1; then echo "PASS $1"; else echo "FAIL $1"; sed 's/^/     /' /tmp/smoke.out | tail -5; fail=1; fi; }
check "R and every base package load" "Rscript -e 'p <- read.delim(\"/opt/nsf/r-packages.tsv\")\$Package; invisible(lapply(c(\"tidyverse\",\"arrow\",\"duckdb\",\"tidymodels\",\"mgcv\",\"lme4\",\"targets\",\"gt\",\"CausalImpact\"), library, character.only=TRUE)); cat(length(p), \"packages\n\")'"
check "R installs from the pinned snapshot" "Rscript -e 'stopifnot(grepl(\"p3m.dev/cran/__linux__/resolute/20\", getOption(\"repos\")[[\"CRAN\"]]))'"
check "Python and every base package import" "/opt/venv/bin/python -c 'import numpy, pandas, polars, pyarrow, duckdb, scipy, sklearn, statsmodels, xgboost, lightgbm, umap, hdbscan, mlxtend, matplotlib, seaborn, google.cloud.storage, ipykernel'"
check "the Python (NSF) kernel is registered" "jupyter-kernelspec list 2>/dev/null | grep -q nsf || /opt/venv/bin/jupyter kernelspec list | grep -q nsf"
check "an SSH session's PATH finds the venv's python" "grep -q '^PATH=\"/opt/venv/bin' /etc/environment"
check "sshd's config is valid: keys only, no root" "ssh-keygen -q -t ed25519 -N \"\" -f /tmp/smoke_hostkey && /usr/sbin/sshd -t -h /tmp/smoke_hostkey && grep -q '^PasswordAuthentication no' /etc/ssh/sshd_config.d/nsf.conf && grep -q '^PermitRootLogin no' /etc/ssh/sshd_config.d/nsf.conf"
check "Claude Code runs, auto-update off, pushes to main denied" "claude --version && grep -q DISABLE_AUTOUPDATER /etc/claude-code/managed-settings.json && grep -q 'git push origin main' /etc/claude-code/managed-settings.json"
check "Quarto, uv, gcloud, git run" "quarto --version && uv --version && gcloud --version >/dev/null && git --version"
check "no secrets baked in" "! grep -qiE 'api_key|token|secret' /etc/environment"
check "no SSH host keys baked in" "! ls /etc/ssh/ssh_host_* 2>/dev/null"
check "the project template is in place" "test -f /opt/nsf/templates/project/CLAUDE.md && test -f /opt/nsf/templates/project/.gitignore"
echo "--- versions"
echo "R $(Rscript -e 'cat(as.character(getRversion()))'), $(/opt/venv/bin/python --version), $(claude --version 2>/dev/null), quarto $(quarto --version), $(uv --version), $(gcloud --version 2>/dev/null | head -1), $(uname -m)"
exit $fail
