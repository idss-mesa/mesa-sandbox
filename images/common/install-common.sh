#!/bin/sh
# install-common.sh — run as root in every app image after `COPY --from=tools`
# and `COPY images/common /opt/vice/common`. Installs the shared helpers and
# configs, creates the `agent` user, and removes sudo (ADR-0003, ADR-0008).
set -eu
C=/opt/vice/common
install -d -m 755 /opt/vice/bin /opt/vice/etc/configs
install -m 755 $C/bin/* /opt/vice/bin/
install -m 644 $C/configs/* /opt/vice/etc/configs/
install -m 755 $C/etc/motd /etc/motd
install -m 644 $C/etc/mesa-prompt.sh /etc/profile.d/mesa-prompt.sh
# a second, unprivileged identity for agents that run inside the workbench (profile P1)
getent group agent >/dev/null || groupadd -g 1001 agent
id -u agent >/dev/null 2>&1 || useradd -u 1001 -g agent -G users -m -d /home/agent -s /bin/bash agent
# no sudo, no setuid escalation paths, anywhere in the image
if command -v apt-get >/dev/null 2>&1; then apt-get purge -y sudo >/dev/null 2>&1 || true; fi
rm -f /etc/sudoers /usr/bin/sudo /usr/local/bin/sudo; rm -rf /etc/sudoers.d
find / -xdev -perm /6000 -type f \( -name sudo -o -name su -o -name mount -o -name umount -o -name chsh -o -name chfn -o -name newgrp -o -name gpasswd -o -name passwd \) -exec chmod a-s {} + 2>/dev/null || true
echo "install-common: done (agent uid 1001, sudo removed)"
