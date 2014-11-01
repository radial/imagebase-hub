# Dockerfile for Hub-Base

This repository creates a lightweight, but still mostly capable Docker container
called a "Hub" used to link up all the complexities of a standard application
stack but still allow fine grained control over an applications configuration.

The image extends the full-chain `radial/busyboxplus:git` image with some logic
to allow for both static and dynamic configuration as well as some other
strategies for simplifying how to run the different parts of a full application
stack using Docker.

Check out the documentation
[here](https://github.com/radial/docs) for more details.

## Tunables

Tunable environment variables; modify at runtime. Italics are defaults.

  - **SUPERVISOR_REPO**: [_https://github.com/radial/config-supervisor.git_]
    Repository location for default Supervisor daemon configuration.
  - **SUPERVISOR_BRANCH**: [_master_] Repository default branch.
  - **[WHEEL_REPO[_APP1]...]**: Additional repositories to download and merge
    with the default SUPERVISOR_REPO repository.
  - **[WHEEL_BRANCH[_APP1]...]**: Branches to pull for given WHEEL_REPO
    repositories.
  - **UPDATES**: [_False_|True] Update configuration from the selected
    WHEEL_REPO repositories (if any) on container restart.
  - **PERMISSIONS_DEFAULT_DIR**: [_"755"_] Default (recursive) directory
    permissions for /config, /data, and /log.
  - **PERMISSIONS_DEFAULT_FILE**: [_"644"_] Default (recursive) file permissions
    for files contained in /config, /data, and /log.
  - **PERMISSIONS_EXCEPTIONS**: [_empty_] A single string, separated by spaces,
    containing a list of files/directories to chmod/chown.
    - The format for a single entry:
    {<path to dir or file\>}{:<octal mode\>}[:<user\>][:<group\>]
    - These values, separated by ':' are passed directly into `chown` and
      `chmod` so things like `/config/*` work for directory contents and numeric
      user and group ids work as well.
    - Some examples:
        - `/config/supervisor/conf.d/*:700`
        - `/config/supervisor/supervisord.conf:700:root:root`
        - `/config/supervisor/myprogram.conf:777:myprogramuser`
