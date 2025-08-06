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
    
 * __netshoot__  
    Quick way to launch `netshoot` when doing container network debugging. Simply run `docker netshoot [container]`. 
    
#### Scan

The scan command works by polling the `latest` tag and compare it against whatever the container is running. In 95% of cases this will work as intended. There are of cause some niche cases where publishers deal with tags a bit differently and for this you can add a label to your container called `update.tag` containing the tag to compare against. 

