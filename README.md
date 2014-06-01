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
