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
chk_pool_health() {
    local pool="$1"
    local status="$(zpool list -H -o health "$pool")"
    
    echo "Checking pool health on '$pool'"
    
    if [[ "$status" != "ONLINE" ]]; then
        echo "    Warning: The health on '$pool' is '$status'" >&2
        /usr/bin/alert --priority "critical" --title "ZFS Health Check" --id zfs_health_$pool --timeout 86400 "The health on '$pool' is '$status'"
        
    else
        echo "    The health on '$pool' is normal"
        /usr/bin/alert --priority "low" --title "ZFS Health Check" --id zfs_health_$pool --timeout reset "The health on '$pool' has returned to normal"
    fi
}

###
#
#
chk_pool_usage() {
    local pool="$1"
    local level=
    
    echo "Checking disk usage on '$pool'"
    read CAP FRAG <<< $(zpool list -H -o cap,frag $pool | tr -d '%')

    if (( CAP >= 90 )); then
      level="critical"
    elif (( CAP >= 80 && FRAG >= 35 )); then
      level="high"
    elif (( CAP >= 70 && FRAG >= 55 )); then
      level="medium"
    fi
    
    if [[ -n "$level" ]]; then
        echo "    Warning: The zpool '$pool' exceeds ${CAP}% usage with ${FRAG}% fragmentation" >&2
        /usr/bin/alert --priority $level --title "ZFS Health Check" --id zfs_usage_$pool --timeout 86400 "The zpool '$pool' exceeds ${CAP}% usage with ${FRAG}% fragmentation"
        
    else
        echo "    Usage on '$pool' is normal at ${CAP}% usage with ${FRAG}% fragmentation"
        /usr/bin/alert --id zfs_usage_$pool --timeout reset
    fi
}

###
#
#
chk_device_health() {
    local pool="$1"
    local device="$2"
    local health="$(smartctl-overlay -H $device | grep overall-health)"
    
    echo "Checking device health on '$device'"

    if grep -q ' result:' <<< "$health" && ! grep -q 'PASSED' <<< "$health"; then
        echo "    Warning: The disk '$device' from '$pool' did not pass SMART health check" >&2
        /usr/bin/alert --priority "critical" --title "Disk Health Check" --id disk_health_$device --timeout 86400 "The disk '$device' from '$pool' did not pass SMART health check"
        
    else
        echo "    The disk '$device' from '$pool' successfully passed SMART health check"
        /usr/bin/alert --id disk_health_$device --timeout reset
    fi
}

###
#
#
chk_device_temp() {
    local pool="$1"
    local device="$2"
    local dev_type dev_temp
    
    echo "Checking temperature on '$device'"

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
        echo "    Warning: The disk '$device' from '$pool' is above temperature threshold for $dev_type devices at $dev_temp°C" >&2
        /usr/bin/alert --priority "critical" --title "Disk Health Check" --id disk_temp_$device --timeout 86400 "The disk '$device' from '$pool' is above temperature threshold for $dev_type devices at $dev_temp°C"

    else
        echo "    The disk '$device' from '$pool' is below temperature threshold at $dev_temp°C"
        /usr/bin/alert --priority "low" --title "Disk Health Check" --id disk_temp_$device --timeout reset "The disk '$device' from '$pool' is below temperature threshold at $dev_temp°C"
    fi
}

###
#
#
declare -a devices

for pool in $(zpool list -H -o name); do
    echo "Running disk monitoring on the ZFS pool '$pool'"

    chk_pool_health $pool
    chk_pool_usage $pool
    
    for device in $(zpool status -PL $pool | grep -oe '/dev/.*$' | awk '{print $1}'); do
        device=$(blksrc $device)                                # Convert something like /dev/dm-1 -> /dev/sdb1
        device=/dev/$(lsblk -no pkname $device | tail -n 1)     # Convert something like /dev/sdb1 -> /dev/sdb
        
        if [[ -n "$device" && -b $device ]]; then
            if [[ ! " ${devices[*]} " =~ " $(basename $device) " ]]; then
                devices+=( $(basename $device) )
                
                echo "Evaluating SMART status of the device $device"
                
                if smartctl-overlay -i $device 2>/dev/null | grep -Eq 'SMART support is:[[:space:]]*Enabled'; then
                    chk_device_health $pool $device
                    chk_device_temp $pool $device
                
                else
                    echo "    SMART is not enabled on the device $device"
                fi
            fi
        fi
    done
done

