#!/bin/bash
#
# Monitoring script that checks the current state of a disk/filesystem. 
# If any errors are found with a ZFS pool or from a previous SmartCTL scan, 
# the script will send an alert.
#
#
# This script works in combination with:
#
#   * smartctl@<timer>.sh
#   * zfs_scrub@<timer>.sh
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
declare state

for pool in $(zpool list -H -o name); do
    state=0
    echo "Checking ZFS pool '$pool' status"
    
    if [[ "$(zpool list -H -o health $pool)" != "ONLINE" ]]; then
        echo "Critical : The zpool '$pool' needs your attention"
        /usr/bin/alert --priority "critical" --title "ZFS Health Check" --id zfs_health_$pool --timeout 86400 "The zpool '$pool' needs your attention"
        state=1
        
    else
        for device in $(zpool status -PL $pool | grep -oe '/dev/.*$' | awk '{print $1}'); do
            echo "Checking device '$device' beloning to ZFS pool '$pool'"
        
            device=$(blksrc $device)                                # Convert something like /dev/dm-1 -> /dev/sdb1
            device=/dev/$(lsblk -no pkname $device | tail -n 1)     # Convert something like /dev/sdb1 -> /dev/sdb
            
            if [[ -n "$device" && -b $device ]]; then
                echo "    Realpath: $device"
            
                if [[ ! " ${devices[*]} " =~ " $(basename $device) " ]]; then
                    if /usr/sbin/smartctl -i $device >/dev/null 2>&1; then
                        health="$(smartctl -H $device | tail -n 2)"
                    
                        if grep -q ' result:' <<< "$health" && ! grep -q 'PASSED' <<< "$health"; then
                            devices+=( $(basename $device) )
                            
                            echo "Critical : SmartCTL Health Check" "The device '$device' that belongs to zpool '$pool' is in danger"
                            /usr/bin/alert --priority "critical" --title "SmartCTL Health Check" --id zfs_health_$pool --timeout 86400 "The device '$device' that belongs to zpool '$pool' is in danger"
                            state=1
                        fi
                    fi
                fi
            fi
        done
    fi
    
    if [ $state -eq 0 ]; then
        /usr/bin/alert --id zfs_health_$pool --timeout reset
    fi
    
    avail=$(zfs get -Hp avail $pool | awk '{print $3}')
    used=$(zfs get -Hp used $pool | awk '{print $3}')
    perc=$(bc -l <<< "$used / ($avail + $used) * 100" | awk -F. '{print $1}')
    
    echo "Checking disk usage"
    
    if [ $perc -gt 95 ]; then
        echo "Warning : The zpool '$pool' exceeds 95% usage"
        /usr/bin/alert --priority "medium" --title "ZFS Health Check" --id zfs_usage_$pool "The zpool '$pool' exceeds 95% usage"
        
    else
        /usr/bin/alert --id zfs_usage_$pool --timeout reset
    fi
done

