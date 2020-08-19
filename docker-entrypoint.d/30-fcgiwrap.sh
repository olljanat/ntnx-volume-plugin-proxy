
#!/bin/sh
# vim:sw=4:ts=4:et

set -e

fcgiwrap -s unix:/var/run/fcgiwrap.sock &

exit 0