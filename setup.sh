#!/bin/sh

set -eu

# TODO this seems useful maybe? add it to /etc/runlevels if so
#rc-update add smartd default

chpasswd -R "${ROOTFS}" -e <<'EOF'
root:$6$QOltENq7.Ltj.51e$2JuUre4mU/IjxgBF9kjawQn7Wd/Dno1U2uFxHzDISof6pq4QLMR20naRtmELFjQHBLJNQGfa7YDYIIlhBBs/./
EOF
