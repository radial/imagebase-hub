#!/bin/sh
# There be shenanigans here to make this script work with busybox's ash shell.
set -e

UPDATES=${UPDATES:-"False"}

restart_message() {
    echo "Container restart on $(date)."
}

get_envs() {
    repoList=$(env | grep "WHEEL_REPO" | sort | awk -F "=" '{print $1}')
    branchList=$(env | grep "WHEEL_BRANCH" | sort | awk -F "=" '{print $1}')
    listLength=$(echo "$repoList" | wc -w)
}
    
pull_wheel_repos () {
    # Pull all WHEEL_REPO repositories
    get_repo() {
        echo $(eval echo $(echo "\$$(echo "$repoList" | awk -v i=${i} 'NR==i')"))
    }

    get_branch() {
        value=$(eval echo $(echo "\$$(echo "$branchList" | awk -v i=${i} 'NR==i')"))

        # Use default if no branches set
        if [ "$value" = "$" ]; then
            echo "config"
        else
            echo "$value"
        fi
    }

    i=1
    while [ $i -le $((listLength)) ]; do
        remoteName=$(date | md5sum | head -c10)
        git remote add ${remoteName} $(get_repo $i)
        git pull --no-edit ${remoteName} $(get_branch $i)
        i=$((i + 1))
    done
}

apply_permissions() {
    # Set file and folder permissions for all configuration and uploaded
    # files.

    do_apply() {
        if [ "$(find "$1" -type d -not -path "*/.git*")" ]; then
            find "$1" -type d -not -path "*/.git*" -print0 | xargs -0 chmod 755
            if [ "$(find "$1" -type f -not -path "*/.git*")" ]; then
                find "$1" -type f -not -path "*/.git*" -print0 | xargs -0 chmod 644
            fi
            echo "...file permissions successfully applied to $1."
        fi
    }

    if [ -d /config ]; then
        do_apply /config
    fi
    if [ -d /data ]; then
        do_apply /data
    fi
    if [ -d /log ]; then
        do_apply /log
    fi
}


launch() {
    cd /config
    
    get_envs

    pull_wheel_repos

    apply_permissions

    echo "Wheel repositories updated."

    rmdir /run/hub.lock

    exec IDLE
}


# Spoke containers will wait for Hub to finish loading before running.
mkdir -p /run/hub.lock

case "${1}" in
    dynamic)
        if [ ! -e /tmp/hub_first_run ]; then
            touch /tmp/hub_first_run

            # Get ENV variables from cli
            get_envs

            # Fail if no Wheel repo(s) set.
            if [ "$repoList" = "" ]; then
                echo "Warning: no Wheel repository(s) set. This hub has no configuration."
                exit 1
            fi

            # Clone supervisor skeleton
            git clone $SUPERVISOR_REPO -b $SUPERVISOR_BRANCH /config &&
                echo "...successfully cloned Supervisor skeleton config."

            launch
        else
            restart_message
            if [ "$UPDATES" != "False" ]; then
                echo "Refreshing configuration from wheel repositories..."
                launch
            fi
        fi
        ;;

    static)
        cd /config

        # Additional ENV variables have already made their way in at this point
        # via the '/build-env' file or from run time additions if they exist.
        # Process those too.
        get_envs

        # Git repo already initialized, merge from here on.
        git remote add supervisor $SUPERVISOR_REPO &&
        git pull --no-edit supervisor $SUPERVISOR_BRANCH &&
            echo "...successfully pulled Supervisor skeleton config."

        # Only pull if anything exists. If not, everything was added via 
        # the dockerfile COPY directive.
        if [ "$repoList" != "" ]; then
            pull_wheel_repos
        fi

        apply_permissions

        rmdir /run/hub.lock
        ;;

    static-update)
        if [ ! -e /tmp/hub_first_run ]; then
            touch /tmp/hub_first_run

            launch
        else
            restart_message
            if [ "$UPDATES" != "False" ]; then
                echo "Refreshing configuration from wheel repositories..."
                launch
            fi
            rmdir /run/hub.lock
            exec IDLE
        fi
        ;;
esac
