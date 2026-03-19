# Docker

In the `bashrc.d/` there is an environment script for extending docker commands as well as a script for providing tab completion to those commands. To install this, add those files to `/etc/bashrc.d/`. Then add the following to your `/etc/bash.bashrc` file. 

    for file in /etc/bashrc.d/*.sh; do
        [ -x $file ] || continue
        . $file
    done
    
## New Commands

Here is a list of the commands that this environment script provides. 

 * __ls__  
    List all containers. This provides something similar to `docker ps` only it provides a much cleaner output than the mess that `docker ps` throws into the shell. 

 * __info__  
    Extends the command `info` to containers. Simply run `docker info [container]` to get a useful list of information about a specific container. 
    
 * __scan__  
    Scan all containers for possible updates. You you a quick and clean list of containers that has updates available. 
    
 * __start|stop__  
    Extended start/stop that makes sure to track dependency namespaces when container use the network of other containers _(Pods)_. 
    
 * __compile__  
    Build containers from systemd-like files in `/etc/docker/containers/*.container`.
    
#### Scan

The scan command works by polling the `latest` tag and compare it against whatever the container is running. In 95% of cases this will work as intended. There are of cause some niche cases where publishers deal with tags a bit differently and for this you can add a label to your container called `update.tag` containing the tag to compare against. 

#### docker compile

`docker compile` is a declarative container builder that uses systemd-like configuration files located in: `/etc/docker/containers/`. It allows you to define containers using structured files, apply reusable profiles, and support templated instances.

Instead of manually running `docker run` or `docker create`, you define container configurations in files:

 * <name>.container  
 * <name>@.container  
 * <name>.profile  

Then build or run them with:

```sh
docker compile <name>  
```
```sh
docker compile <name>@<param>  
```

These files are structured like so:

```
[config]

  repo = <repo>/<image>:<tag>
  mode = run|create|start
  command = <cmd>
  profile = profile1,profile2

[container]

  name = MyContainer
  network = bridge0
  ip = 172.16.0.1
  tty = true
  ...
```

Profiles are always loaded first and allows shared configuration to be stored in a single place rather than being copied to each container file. The default profile `default.profile` is always applied as the very first and does not require being declared, simply to exist.

The `[container]` section takes any valid docker double dash argument. Arguments without values like `--tty` is treated as a boolean and simply uses `true|false`. 

