# Dockerfile for Hub-Base
#
# This Hub-Base Dockerfile sets up a volume container used to persist, extract,
# and manage application configuration. It is split into two sections: Dynamic
# data mode for command line usage only, and static data mode for use as a
# Dockerfile.
FROM            radial/busyboxplus:git
MAINTAINER      Brian Clements <radial@brianclements.net>

# Simple program to keep the container alive and do nothing
COPY            IDLE /usr/bin/IDLE

# Default configuration for supervisor.
ENV             SUPERVISOR_REPO https://github.com/radial/config-supervisor.git
ENV             SUPERVISOR_BRANCH master

# Recreate /run to Ubuntu specifications since it will be Ubuntu systems
# that actually use this directory via an exposed volume, not busybox.
RUN             rm /run && rm /var/run &&\
                mkdir -m 777 /run &&\
                ln -s /run /var/run
WORKDIR         /run
RUN             mkdir -p -m 755 network/interface resolvconf sendsigs.omit.d shm sshd &&\
                mkdir -m 777 lock &&\
                touch motd.dynamic utmp &&\
                chmod 644 motd.dynamic utmp &&\
                chmod 664 utmp &&\
                chown root:102 network &&\
                chown root:utmp utmp

#-------------------------------------------------------------------------------
# Dynamic data mode: run from image.
#
# `docker pull radial/hub-base` yields a non-versioned hub image that can be run
# "as is" and later linked up at run time via '--volumes-from' with it's Spoke
# container. All data stored in this container's exposed volumes are deleted
# when the containers are removed. Run with `-e
# "WHEEL_REPO=https://path.to.your/wheel/repo.git"` to download a configuration
# at runtime. Your configuration should have it's own branch in your wheel
# repository, named "config" by default, with it's relative root being /config.
ENV             WHEEL_REPO none
ENV             WHEEL_BRANCH config

WORKDIR         /config

# When run from the image directly, the resulting container will:
# 1) Clone the /config skeleton containing our default Supervisor configuration.
# 2) Add the location of our wheel repository and pull the 'config' branch to
#    merge the Supervisor skeleton and our Wheel configuration together.
# 3) Set up file and folder permissions accordingly
COPY            /hub-entrypoint.sh /hub-entrypoint.sh

ENTRYPOINT      ["/hub-entrypoint.sh", "dynamic"]

# NOTE: if you run this image dynamically, you must manually share the volumes
# '/config', '/data', '/log', and '/run' (if your Spokes need to communicate
# via sockets) if not using --volumes-from another Axle container that shares
# these directories already.

# ------------------------------------------------------------------------------
# Static data mode: built from Dockerfile
#
# With one line, `FROM radial/hub-base` in a new Dockerfile, all files in
# '/config' and '/data' are uploaded into '/config' and '/data' respectively in
# the hub-container. Only later are the '/config', '/data', as well as '/log'
# directories declared with 'VOLUME'.  This means that the files uploaded into
# '/config' and '/data' are now subject to version control within docker AND
# WILL PERSIST AS PART OF THE RESULTING IMAGE. Not just stored temporarily in
# the running container. 

# 1) Add the contents of the '/config' and '/data' folders
# 2) Add the build-env file (a file that contains ENV vars needed for our
#    build, if any as well as to specify a custom Supervisor skeleton and/or
#    Wheel repository at build time).
ONBUILD COPY    / /

# Create the '/log' directory as a backup in case we don't use a log Axle
# container.
ONBUILD RUN     mkdir /log

# Make the copied files in '/config' a git repository so we can merge
# outside configuration into it.
ONBUILD WORKDIR /config
ONBUILD RUN     git init && git add . && git commit -m "Configuration from COPY files" 

# If not explicitly using 'COPY' for configuration files, or if combining files
# locally and remotely, we need to source 'build-env' for the location of our
# additional configuration so we can pull it from those locations. 'build-env'
# is a series of `export SOME_VAR="value"` statements that is sourced before
# running our setup script.
#
# After this, file permissions are set on all the /config, /data, and /log
# directories.
ONBUILD ENV     ENV /build-env
ONBUILD RUN     test -f /build-env && source /build-env;\
                /hub-entrypoint.sh static

# Share our VOLUME directories
ONBUILD VOLUME  ["/config", "/data", "/log", "/run"]

ONBUILD ENTRYPOINT ["/hub-entrypoint.sh", "static-update"]
