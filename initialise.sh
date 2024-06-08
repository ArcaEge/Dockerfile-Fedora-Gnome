#!/bin/bash
sudo docker run --name=fedora-vnc -d --rm \
        --tmpfs /run --tmpfs /run/lock --tmpfs /tmp \
        --cgroupns=host --cap-add SYS_BOOT --cap-add SYS_ADMIN \
        -v /sys/fs/cgroup:/sys/fs/cgroup \
        -v homeVolume:/home \
        -p 5901:5901 -p 6901:6901 \
        arcaege/fedora-gnome-vnc

sudo apt update -y && sudo apt install novnc -y

websockify --web=/usr/share/novnc/ 6080 localhost:5901