#!/bin/sh

set -eu

# NOTE: git can't track empty directories, so mkdir them all here
mkdir -p /home /mnt

# TODO this seems useful maybe? add it to /etc/runlevels if so
#rc-update add smartd default

# TODO is there a simpler way of doing this on alpine?
adduser -DH -h /home/siva -g 'Siva Mahadevan' -s /bin/sh siva
adduser siva wheel
adduser siva audio
adduser siva video
adduser siva seat
adduser siva abuild

chpasswd -e <<'EOF'
root:$6$QOltENq7.Ltj.51e$2JuUre4mU/IjxgBF9kjawQn7Wd/Dno1U2uFxHzDISof6pq4QLMR20naRtmELFjQHBLJNQGfa7YDYIIlhBBs/./
EOF
chpasswd -e <<'EOF'
siva:$6$cypOqzoJFgZIhGnu$eI/iaaVy0TJ6Nn0WGcwm8OTQwie/RvllMVCBnbNedcPJT5IYNlzp9oLPrxbtqnDmmlkdIxFs92BAdJ6.EfqDi/
EOF
