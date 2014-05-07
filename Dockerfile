# Dockerfile for Hub-Base
FROM            radial/busyboxplus
MAINTAINER      Brian Clements <brian@brianclements.net>

# Dynamic data mode: run from image.
#
# `docker pull radial/hub-base` yields a non-versioned hub image
# that can be run "as is" and later linked up at run time via '--volumes-from'
# with it's application container. All data stored in this container's
# exposed volumes are deleted when the containers are removed. Run with `-e
# "CONFIG_REPO="` to download a configuration at runtime.
ENV CONFIG_REPO none
ENV CONFIG_BRANCH none

VOLUME          ["/config", "/data", "/log"]

# Make everything permissive so Spoke containers are free to use other system
# users to run their applications. Note: running this container interactively
# and changing the `CMD` like `docker run -it radial/hub-base sh` will omit
# this step and file permissions are not guaranteed to be uniform.
CMD             git clone $CONFIG_REPO -b $CONFIG_BRANCH /config >/dev/null 2>&1 &&\
                chmod 644 -R /config /data /log >/dev/null 2>&1


# Static data mode: built from Dockerfile
#
# With one line, `FROM radial/hub-base` in a new Dockerfile, all
# files from context directory are loaded into the container at build time in
# their respective folders. Those directories are then shared via "VOLUME".
# This means the files are now subject to version control within docker AND
# WILL PERSIST AS PART OF THE RESULTING IMAGE. Not just stored temporarily in
# the running container. 

# Add all files in context to / of container. This includes your Dockerfile,
# your build-env file, and any directories and their contents. Normally, only 
# a 'config' folder needs to be added.
ONBUILD ADD     . /

# If not explicitly using 'ADD' for configuration files, we need to source
# 'build-env' for the location of our configuration repository.
ONBUILD RUN     test -f /build-env && source /build-env || true

# Pull our configuration
ONBUILD RUN     git clone $CONFIG_REPO -b $CONFIG_BRANCH /config >/dev/null 2>&1 || true

# Expose our VOLUME directories
ONBUILD VOLUME  ["/config", "/data", "/log"]

# Make everything permissive so Spoke containers are free to use other system
# users to run their applications. Note: running this container interactively
# and changing the `CMD` like `docker run -it radial/hub-base sh` will omit
# this step and file permissions are not guaranteed to be uniform.
ONBUILD CMD     chmod 644 -R /config /data /log >/dev/null 2>&1
