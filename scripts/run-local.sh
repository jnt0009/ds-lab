#!/bin/sh
# Runs the NSF lab on this Mac: `nsf-local` in ~/.ssh/config (127.0.0.1:2222) for Positron's Remote SSH.
#   ~/nsf/work   projects (git clones), also visible in Finder      -> /work
#   ~/nsf/data   big or downloaded data                               -> /data
#   nsf-home     the lab user's home (Positron's server, shell history, caches): a Docker volume
#   ~/.ssh/nsf_ed25519.pub            the key allowed in
#   ~/.config/nsf/secrets.env         optional: ANTHROPIC_API_KEY=..., GH_TOKEN=... (never committed anywhere)
# Usage: scripts/run-local.sh [image]   (default nsf:dev; later the Artifact Registry tag)
set -e
IMAGE=${1:-nsf:dev}
mkdir -p "$HOME/nsf/work" "$HOME/nsf/data"
SECRETS=""
[ -f "$HOME/.config/nsf/secrets.env" ] && SECRETS="-v $HOME/.config/nsf/secrets.env:/run/nsf/secrets.env:ro"
docker rm -f nsf-local >/dev/null 2>&1 || true
docker run -d --name nsf-local --restart unless-stopped \
    -p 127.0.0.1:2222:22 \
    -v "$HOME/nsf/work":/work -v "$HOME/nsf/data":/data -v nsf-home:/home/jt \
    -v "$HOME/.ssh/nsf_ed25519.pub":/run/nsf/authorized_keys:ro $SECRETS \
    "$IMAGE" >/dev/null
echo "nsf-local is up ($IMAGE). Positron: Remote-SSH: Connect to Host... -> nsf-local"
