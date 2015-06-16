#!/bin/sh
# There be shenanigans here to make this script work with busybox's ash shell.
set -e

# Tunable variables
UPDATES=${UPDATES:-"False"}
PERMISSIONS_DEFAULT_DIR=${PERMISSIONS_DEFAULT_DIR:-755}
PERMISSIONS_DEFAULT_FILE=${PERMISSIONS_DEFAULT_FILE:-644}
PERMISSIONS_EXCEPTIONS=${PERMISSIONS_EXCEPTIONS:-''}


restart_message() {
    echo "Container restart on $(date)."
}

get_envs() {
    repoList=$(env | grep "WHEEL_REPO" | sort | awk -F "=" '{print $1}')
    branchList=$(env | grep "WHEEL_BRANCH" | sort | awk -F "=" '{print $1}')
    repoListLength=$(echo "$repoList" | wc -w)
}
    
pull_wheel_repos() {
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
    while [ $i -le $((repoListLength)) ]; do
        remoteName=$(date | md5sum | head -c10)
        git remote add ${remoteName} $(get_repo $i)
        git pull --no-edit ${remoteName} $(get_branch $i)
        i=$((i + 1))
    done
}

apply_permissions() {
    # Set default file and folder permissions for all configuration and
    # uploaded files.

    apply_default_permissions() {
        if [ "$(find "$1" -type d -not -path "*/.git*")" ]; then
            find "$1" -type d -not -path "*/.git*" -print0 | xargs -0 chmod "$PERMISSIONS_DEFAULT_DIR"
            if [ "$(find "$1" -type f -not -path "*/.git*")" ]; then
                find "$1" -type f -not -path "*/.git*" -print0 | xargs -0 chmod "$PERMISSIONS_DEFAULT_FILE"
            fi
            echo "...file permissions successfully applied to $1."
        fi
    }

    if [ -d /config ]; then
        apply_default_permissions /config
    fi
    if [ -d /data ]; then
        apply_default_permissions /data
    fi
    if [ -d /log ]; then
        apply_default_permissions /log
    fi

    # Set file/folder permissions exceptions, if any
    permExceptList=$(echo "$PERMISSIONS_EXCEPTIONS" | tr ' ' '\n' | sort -r )
    permExceptListLength=$(echo "$permExceptList" | wc -w) 

    get_entry() {
        echo "$permExceptList" | awk -F ':' -v line="$1" -v item="$2" 'NR==line {print $item}'
    }

    i=1
    while [ $i -le $((permExceptListLength)) ]; do
        if [ $(get_entry $i 4) ]; then
            chown $(get_entry $i 3):$(get_entry $i 4) $(get_entry $i 1)
            echo "Changed $(get_entry $i 1) owner and group to $(get_entry $i 3):$(get_entry $i 4)"
        elif [ $(get_entry $i 3) ]; then
            chown $(get_entry $i 3) $(get_entry $i 1)
            echo "Changed $(get_entry $i 1) owner to $(get_entry $i 3)"
        fi
        chmod $(get_entry $i 2) $(get_entry $i 1)
        echo "Changed $(get_entry $i 1) permissions to $(get_entry $i 2)"
        i=$((i + 1))
    done
}

launch() {
    cd /config
    
    get_envs

    # Warn if no Wheel repo(s) set in dynamic mode; don't attempt to pull anything.
    if [ "$repoList" = "" ]; then
        if [ "$1" = "dynamic" ]; then
            echo "Warning: no Wheel repository(s) set. This hub has no configuration."
        fi
    else
        pull_wheel_repos
    fi

    apply_permissions

    echo "Configuration setup complete."

    rmdir /run/hub.lock

    exec IDLE
}


# Spoke containers will wait for Hub to finish loading before running.
mkdir -p /run/hub.lock

case "${1}" in
    dynamic)
        if [ ! -e /tmp/hub_first_run ]; then
            touch /tmp/hub_first_run
            echo "hub is running in dynamic mode."

            # Get ENV variables from cli
            get_envs

            # Initialize our git config repo
            git init /config
                echo "...Initialized config repository."

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
