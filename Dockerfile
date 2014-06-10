# Dockerfile for Hub-Base
#
# This Hub-Base Dockerfile sets up a volume container used to persist, extract,
# and manage application configuration. It is split into two sections: Dynamic
# data mode for command line usage only, and static data mode for use as a
# Dockerfile.
FROM            radial/busyboxplus:git
MAINTAINER      Brian Clements <radial@brianclements.net>

# Default configuration for supervisor.
ENV             SUPERVISOR_REPO https://github.com/radial/config-supervisor.git
ENV             SUPERVISOR_BRANCH master

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
ENTRYPOINT      git clone $SUPERVISOR_REPO -b $SUPERVISOR_BRANCH /config &&\
                    echo "...successfully cloned Supervisor skeleton config.";echo"";\
                if [ $WHEEL_REPO == "none" ]; then\
                    echo "warning: no Wheel repository is set. This hub has no configuration"; else\
                    git remote add wheel $WHEEL_REPO &&\
                    git pull --no-edit wheel $WHEEL_BRANCH; fi;\
                find /config -type d -not -path "*/.git*" -print0 | xargs -0 chmod 755 &&\
                find /config -type f -not -path "*/.git*" -print0 | xargs -0 chmod 644 &&\
                echo""; echo "...file permissions successfully applied to '/config'."

# NOTE: if you run this image dynamically, you must manually share the volumes
# '/config', '/data', and '/log' if not using --volumes-from another Axle
# container.

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
ONBUILD COPY    /config /config
ONBUILD COPY    /data /data
ONBUILD COPY    /build-env /build-env

# Create the '/log' directory as a backup in case we don't use a log Axle
# container.
ONBUILD RUN     mkdir /log

# Make the copied files in '/config' a git repository so we can merge
# outside configuration into it.
ONBUILD RUN     git init && git add . && git commit -m "Configuration from COPY files" 

# If not explicitly using 'COPY' for configuration files, we need to source
# 'build-env' for the location of our configuration so we can pull our
# configuration from those locations.
ONBUILD RUN     test -f /build-env && source /build-env;\
                git remote add supervisor $SUPERVISOR_REPO &&\
                git pull --no-edit supervisor $SUPERVISOR_BRANCH &&\
                if [ $WHEEL_REPO != "none" ]; then\
                    git remote add wheel $WHEEL_REPO &&\
                    git pull --no-edit wheel $WHEEL_BRANCH;\
                fi

# Set up file and folder permissions
ONBUILD RUN     find /config /data /log -type d -not -path "*/.git*" -print0 | xargs -0 chmod 755 &&\
                find /config /data /log -type f -not -path "*/.git*" -print0 | xargs -0 chmod 644

# Share our VOLUME directories
ONBUILD VOLUME  ["/config", "/data", "/log"]

ONBUILD ENTRYPOINT /bin/sh
