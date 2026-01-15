#!/bin/bash
#
# Find any block device that is accociated with ZFS pools
# and run SmartCTL scans on them. 
#

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
declare -a devices

for pool in $(zpool list -H -o name); do
    for device in $(zpool status -PL $pool | grep -oe '/dev/.*$' | awk '{print $1}'); do
        device=$(blksrc $device)                                # Convert something like /dev/dm-1 -> /dev/sdb1
        device=/dev/$(lsblk -no pkname $device | tail -n 1)     # Convert something like /dev/sdb1 -> /dev/sdb
        
        if [[ -n "$device" && -b $device ]]; then
            if [[ ! " ${devices[*]} " =~ " $(basename $device) " ]]; then
                if smartctl-overlay -i $device 2>/dev/null | grep -Eq 'SMART support is:[[:space:]]*Enabled'; then
                    echo "Starting SmartCRL scan on device '$device'"
                    devices+=( $(basename $device) )
                    
                    if smartctl-overlay -l selftest $device >/dev/null 2>&1; then
                        if ! smartctl-overlay -t long $device; then
                            echo "    Failed to initiate self test"
                        fi
                        
                    else
                        echo "    The device does not support self test"
                    fi
                
                else
                    echo "The device '$device' is not SMART enabled."
                fi
            fi
            
        else
            echo "Skipping device '$device'. Not a block device."
        fi
    done
done

