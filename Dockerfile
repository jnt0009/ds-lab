# syntax=docker/dockerfile:1
# The National Science Foundation's base image: one data science environment for the Mac, battlestation and GCP.
# R and Python, reached by Positron over SSH; Claude Code for agents. No projects, data or secrets in it: projects are
# git repos cloned into /work, data lives in /data, keys arrive at run time (docker/entrypoint.sh).
# Plan: home-lab's docs/ds-lab-plan.md.
#
# Pinned: R (the base tag), CRAN (a Posit Package Manager snapshot date), Python packages (python/uv.lock), Quarto,
# uv. Claude Code and the gcloud CLI come from their signed apt repos at build time; the smoke test records versions.
FROM rocker/r-ver:4.6.2

ARG TARGETARCH
ARG CRAN_SNAPSHOT=2026-11-17
ARG QUARTO_VERSION=1.11.9
ARG NSF_USER=jt
ENV CRAN=https://p3m.dev/cran/__linux__/resolute/${CRAN_SNAPSHOT} \
    UV_PROJECT_ENVIRONMENT=/opt/venv \
    UV_PYTHON_DOWNLOADS=never \
    DEBIAN_FRONTEND=noninteractive

# --- system: sshd, Python, git, and the libraries the R and Python binaries load ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server sudo less vim-tiny nano htop procps curl wget ca-certificates gnupg git git-lfs \
        python3 python3-venv python3-dev build-essential pkg-config \
        libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev libfreetype-dev libharfbuzz-dev \
        libfribidi-dev libpng-dev libjpeg-dev libtiff-dev libwebp-dev libgit2-dev libuv1-dev libsodium-dev \
        libicu-dev zlib1g-dev libbz2-dev liblzma-dev libzstd-dev libglpk-dev libgmp-dev cmake pandoc \
    && rm -rf /var/lib/apt/lists/*

# --- Claude Code and the gcloud CLI, from their signed apt repositories ---
RUN install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://downloads.claude.ai/keys/claude-code.asc -o /etc/apt/keyrings/claude-code.asc \
    && gpg --show-keys --with-colons /etc/apt/keyrings/claude-code.asc | grep -q 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE \
    && echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" \
        > /etc/apt/sources.list.d/claude-code.list \
    && curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
        > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update && apt-get install -y --no-install-recommends claude-code google-cloud-cli \
    && rm -rf /var/lib/apt/lists/*

# --- Quarto and uv, pinned ---
# downloaded into a build cache that outlives the layer, resuming a partial download (GitHub's downloads can crawl)
RUN --mount=type=cache,target=/var/cache/nsf-downloads \
    f=/var/cache/nsf-downloads/quarto-${QUARTO_VERSION}-linux-${TARGETARCH}.deb \
    && curl -fsSL --retry 5 --retry-all-errors --connect-timeout 30 -C - -o "$f" \
        "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-${TARGETARCH}.deb" \
    && apt-get install -y "$f"
COPY --from=ghcr.io/astral-sh/uv:0.13.9 /uv /uvx /usr/local/bin/

# --- R packages: binaries from the CRAN snapshot (r/packages.R lists them and writes what it installed) ---
RUN echo "options(repos = c(CRAN = '${CRAN}'))" >> /usr/local/lib/R/etc/Rprofile.site
COPY r/packages.R /opt/nsf/r/packages.R
RUN Rscript /opt/nsf/r/packages.R

# --- Python packages: the locked set, into /opt/venv ---
COPY python/pyproject.toml python/uv.lock /opt/nsf/python/
RUN cd /opt/nsf/python && uv venv --python /usr/bin/python3 /opt/venv && uv sync --frozen --no-install-project \
    && /opt/venv/bin/python -m ipykernel install --prefix /usr/local --name nsf --display-name "Python (NSF)"

# --- the user, sshd and the agents' settings ---
RUN useradd -m -s /bin/bash "${NSF_USER}" \
    && mkdir -p /run/sshd /work /data && chown "${NSF_USER}:${NSF_USER}" /work /data \
    && git config --system init.defaultBranch main && git config --system pull.ff only \
    && rm -f /etc/ssh/ssh_host_*   # no host keys in the image: each lab makes its own on first start (entrypoint)
COPY docker/sshd_nsf.conf /etc/ssh/sshd_config.d/nsf.conf
COPY docker/environment /etc/environment
COPY docker/claude-managed-settings.json /etc/claude-code/managed-settings.json
COPY templates/ /opt/nsf/templates/
COPY docker/entrypoint.sh /entrypoint.sh
COPY tests/smoke.sh /opt/nsf/smoke.sh
RUN sed -i "s/__NSF_USER__/${NSF_USER}/" /etc/ssh/sshd_config.d/nsf.conf /entrypoint.sh \
    && chmod +x /entrypoint.sh /opt/nsf/smoke.sh

LABEL org.opencontainers.image.source="https://github.com/jnt0009/ds-lab" \
      org.opencontainers.image.title="nsf" \
      org.opencontainers.image.description="The National Science Foundation's base data science image (R + Python + Positron over SSH + Claude Code)"
WORKDIR /work
EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
