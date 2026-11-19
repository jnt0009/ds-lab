#!/bin/sh
# Starts the NSF container: the SSH key and any secrets arrive at run time, never in the image.
#   /run/nsf/authorized_keys   the public key(s) allowed in (required)
#   /run/nsf/secrets.env       KEY=value lines (ANTHROPIC_API_KEY, GH_TOKEN, ...), optional
# An SSH session doesn't see the container's environment: it gets /etc/environment through PAM, so secrets go there
# (readable by root and the lab user only), for Positron's terminal, its Assistant and Claude Code alike.
set -e
U=__NSF_USER__
[ -f /run/nsf/authorized_keys ] || { echo "no /run/nsf/authorized_keys: mount the public key to let anyone in" >&2; exit 1; }
install -d -m 700 -o "$U" -g "$U" "/home/$U/.ssh"
install -m 600 -o "$U" -g "$U" /run/nsf/authorized_keys "/home/$U/.ssh/authorized_keys"
# a fresh home volume gets the lab's starting files once
[ -f "/home/$U/.nsf-welcome" ] || { cp /opt/nsf/templates/home/.bashrc_nsf "/home/$U/.bashrc_nsf" 2>/dev/null || true
    grep -q bashrc_nsf "/home/$U/.bashrc" 2>/dev/null || echo '[ -f ~/.bashrc_nsf ] && . ~/.bashrc_nsf' >> "/home/$U/.bashrc"
    date -u +%FT%TZ > "/home/$U/.nsf-welcome"; chown "$U:$U" "/home/$U/.bashrc_nsf" "/home/$U/.bashrc" "/home/$U/.nsf-welcome" 2>/dev/null || true; }
# secrets: the image's /etc/environment, plus the mounted ones, readable by root and the lab user only
cp /etc/environment.nsf /etc/environment 2>/dev/null || cp /etc/environment /etc/environment.nsf
if [ -f /run/nsf/secrets.env ]; then
    # tr: a file saved on Windows ends its lines in \r\n, and the \r would ride along at the end of every value
    # (found 2026-11-19: battlestation's ANTHROPIC_API_KEY ended in \r). `|| true`: a file with no KEY= lines (an
    # empty one, as lab/README.md suggests) must not stop the lab under set -e
    tr -d '\r' < /run/nsf/secrets.env | { grep -E '^[A-Za-z_][A-Za-z0-9_]*=' || true; } >> /etc/environment
fi
chown root:"$U" /etc/environment && chmod 640 /etc/environment
# who the lab's commits are by: NSF_GIT_NAME / NSF_GIT_EMAIL from the secrets, set once (edit ~/.gitconfig after)
GN=$(sed -n 's/^NSF_GIT_NAME=//p' /etc/environment | tail -1 | tr -d '"'); GE=$(sed -n 's/^NSF_GIT_EMAIL=//p' /etc/environment | tail -1 | tr -d '"')
if [ -n "$GE" ] && ! su -s /bin/sh "$U" -c 'git config --global user.email' >/dev/null 2>&1; then
    su -s /bin/sh "$U" -c "git config --global user.name \"${GN:-$U}\" && git config --global user.email \"$GE\""
fi
# the lab's host identity: made on its first start and kept in the home volume, so it survives rebuilds (Positron
# never sees "host identification changed") and is never in the image, where anyone who pulls it could copy it
KEEP="/home/$U/.nsf-hostkeys"
if [ -d "$KEEP" ] && ls "$KEEP"/ssh_host_* >/dev/null 2>&1; then
    cp -p "$KEEP"/ssh_host_* /etc/ssh/
else
    ssh-keygen -A >/dev/null
    install -d -m 700 -o root -g root "$KEEP" && cp -p /etc/ssh/ssh_host_* "$KEEP"/
fi
exec /usr/sbin/sshd -D -e
