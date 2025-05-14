#!/bin/bash

# this is a combination of a lot of things
# this happened after making wsl "boot" using systemd.
# this allows services to start automatically, like docker

# but seems to be driven by https://github.com/microsoft/WSL/issues/10205
echo "running sudo systemctl restart user@1000"
sudo systemctl restart user@1000

dbus-update-activation-environment --all
