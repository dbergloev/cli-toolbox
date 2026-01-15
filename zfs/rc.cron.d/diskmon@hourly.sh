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
case "$timer" in
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
                    if smartctl-overlay -i $device 2>/dev/null | grep -Eq 'SMART support is:[[:space:]]*Enabled'; then
                        read -r dev_type dev_temp <<< "$(
                          smartctl-overlay -A "$device" 2>/dev/null | awk '
                            # ATA / SATA / USB
                            $1 == 194 { print "ATA", $10; exit }
                            $1 == 190 { print "ATA", $10; exit }

                            # NVMe
                            /^Temperature:[[:space:]]*[0-9]+/ {
                                print "NVMe", $2
                                exit
                            }

                            # SAS
                            /Current Drive Temperature:/ {
                                print "SAS", $4
                                exit
                            }
                          '
                        )"
                        
                        if { [[ "$dev_type" == "SAS"  ]] && (( dev_temp >= 55 )); } ||
                           { [[ "$dev_type" == "ATA"  ]] && (( dev_temp >= 50 )); } ||
                           { [[ "$dev_type" == "NVMe" ]] && (( dev_temp >= 70 )); }
                        then
                            echo "The $dev_type device $device is above threshold at $dev_temp°C"
                            /usr/bin/alert --priority "critical" --title "SmartCTL Health Check" --id zfs_health_$(basename $device) --timeout 86400 "The $dev_type device $device is above temperature threshold at $dev_temp°C"
                    
                        else
                            echo "The $dev_type device $device is below temperature threshold at $dev_temp°C"
                            /usr/bin/alert --priority "low" --title "SmartCTL Health Check" --id zfs_health_$(basename $device) --timeout reset "The $dev_type device $device is below temperature threshold at $dev_temp°C"
                        fi
                        
                        health="$(smartctl-overlay -H $device | grep overall-health)"
                    
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
    
    if [[ $state -eq 0 ]]; then
        /usr/bin/alert --id zfs_health_$pool --timeout reset
    fi
    
    echo "Checking disk usage"
    read CAP FRAG <<< $(zpool list -H -o cap,frag $pool | tr -d '%')

    if (( CAP >= 94 )); then
      level="critical"
    elif (( CAP >= 85 && FRAG >= 35 )); then
      level="high"
    elif (( CAP >= 70 && FRAG >= 45 )); then
      level="medium"
    elif (( CAP < 70 && FRAG >= 55 )); then
      # Strange behaviour, give notice!
      level="low"
    else
      level=""
    fi
    
    if [[ -n "$level" ]]; then
        /usr/bin/alert --priority $level --title "ZFS Health Check" --id zfs_usage_$pool --timeout 86400 "The zpool '$pool' exceeds ${CAP}% usage with ${FRAG}% fragmentation"
        
    else
        /usr/bin/alert --id zfs_usage_$pool --timeout reset
    fi
done
