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
# uid/gid 1001 when free, else the first free id >= 1001 (Kasm bases already use 1001)
free_id() { i=$1; while getent "$2" "$i" >/dev/null 2>&1; do i=$((i+1)); done; echo "$i"; }
if ! getent group agent >/dev/null; then groupadd -g "$(free_id 1001 group)" agent; fi
if ! id -u agent >/dev/null 2>&1; then useradd -u "$(free_id 1001 passwd)" -g agent -G users -m -d /home/agent -s /bin/bash agent; fi
echo "agent user: $(id agent)"
# no sudo, no setuid escalation paths, anywhere in the image. Files are removed
# rather than the package purged: some bases (rocker's rstudio-server deb)
# declare a dependency on sudo, and `apt-get purge sudo` would remove them too.
rm -f /etc/sudoers /usr/bin/sudo /usr/bin/sudoedit /usr/bin/sudoreplay /usr/sbin/visudo /usr/local/bin/sudo
rm -rf /etc/sudoers.d /usr/lib/sudo /usr/libexec/sudo /var/lib/sudo /run/sudo
find / -xdev -perm /6000 -type f \( -name sudo -o -name su -o -name mount -o -name umount -o -name chsh -o -name chfn -o -name newgrp -o -name gpasswd -o -name passwd \) -exec chmod a-s {} + 2>/dev/null || true
echo "install-common: done (sudo removed)"
