FROM fedora:40

ENV container docker

# Install locale
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
RUN dnf update -y

# Install systemd
RUN dnf install -y \
    dbus dbus-x11 systemd
VOLUME ["/sys/fs/cgroup"]
STOPSIGNAL SIGRTMIN+3
CMD [ "/sbin/init" ]

# Install GNOME
# NOTE initial setup uninstalled as disabling via /etc/gdm3/custom.conf stopped working: https://askubuntu.com/q/1028822/206608
RUN dnf install -y @base-x gnome-shell gnome-terminal nautilus firefox # chrome-gnome-shell gnome-tweaks @development-tools

# Remove unnecessary system targets
# TODO remove more targets but make sure that startup completes and login promt is displayed when "docker run -it"
#   https://github.com/moby/moby/issues/42275#issue-853601974
RUN rm -f \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* \
    /lib/systemd/system/systemd-update-utmp* \
    /lib/systemd/system/systemd-resolved.service

# Install TigerVNC server
# TODO set VNC port in service file > exec command
# TODO check if it works with default config file
# NOTE tigervnc because of XKB extension: https://github.com/i3/i3/issues/1983
RUN dnf install -y tigervnc-server tigervnc tigervnc-server-module

# TODO fix PID problem: Type=forking would be best, but system daemon is run as root on startup
#   ERROR tigervnc@:1.service: New main PID 233 does not belong to service, and PID file is not owned by root. Refusing.
#   https://www.freedesktop.org/software/systemd/man/systemd.service.html#Type=
#   https://www.freedesktop.org/software/systemd/man/systemd.unit.html#Specifiers
#   https://wiki.archlinux.org/index.php/TigerVNC#Starting_and_stopping_vncserver_via_systemd
# -> this should be fixed by official systemd file once released: https://github.com/TigerVNC/tigervnc/pull/838
# TODO specify options like geometry as environment variables -> source variables in service via EnvironmentFile=/path/to/env
# NOTE logout will stop tigervnc service -> need to manually start (gdm for graphical login is not working)
COPY tigervnc@.service /etc/systemd/system/tigervnc@.service
RUN systemctl enable tigervnc@:1
EXPOSE 5901

# Install noVNC
# TODO novnc depends on net-tools until version 1.1.0: https://github.com/novnc/noVNC/issues/1075
RUN dnf install -y \
    net-tools novnc

# TODO specify options like ports as environment variables -> source variables in service via EnvironmentFile=/path/to/env
COPY novnc.service /etc/systemd/system/novnc.service
RUN systemctl enable novnc
EXPOSE 6901

# Create unprivileged user
# NOTE user hardcoded in tigervnc.service
# NOTE alternative is to use libnss_switch and create user at runtime -> use entrypoint script
ARG UID=1001
ARG USER=default
RUN useradd ${USER} -u ${UID} -U -d /home/${USER} -m -s /bin/bash
RUN dnf install -y sudo && \
    echo "${USER} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${USER}" && \
    chmod 440 "/etc/sudoers.d/${USER}"
USER "${USER}"
ENV USER="${USER}" \
    HOME="/home/${USER}"
WORKDIR "/home/${USER}"

# Set up VNC
RUN mkdir -p $HOME/.vnc
COPY xstartup $HOME/.vnc/xstartup
RUN echo "1234" | vncpasswd -f >> $HOME/.vnc/passwd && chmod 600 $HOME/.vnc/passwd

# switch back to root to start systemd
USER root

