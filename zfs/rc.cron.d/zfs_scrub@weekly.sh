#!/bin/bash

timer="$1"

###
#
#
case $timer in
    startup|shutdown) exit 0 ;; # Unused
esac

###
#
#
for pool in $(zpool list -H -o name); do
    if [[ "$(zpool list -H -o health $pool)" == "ONLINE" ]]; then
        if ! zpool status $pool | grep -q 'scrub in progress'; then
            echo "Initiating ZFS Scrub on storage pool '$pool'"
            zpool scrub $pool
            
        else
            echo "Scrub is already in progress, skipping..."
        fi
    fi
done

