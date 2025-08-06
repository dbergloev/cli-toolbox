#!/bin/bash
#
# Automated snapshots of datasets. 
# --------------------------------
#
# Configure the dataset by adding a few properties. 
#
#   * zfs:snapshot=1
#   * zfs:snapshot.keep_<timer>=<keep>   # Example: 'zfs:snapshot.keep_daily=5' or 'zfs:snapshot.keep_hourly=7'
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
get_prop_all() {
    zfs get -o $1 -H -r -s local -t filesystem $2 $3
}

get_prop() {
    zfs get -o $1 -H $2 $3
}

###
#
#
for volume in $(zfs list -o name -H -d 0); do
    for dataset in $(get_prop_all name zfs:snapshot.keep_$timer $volume); do
        if [ $(get_prop value zfs:snapshot $dataset) -eq 1 ]; then
            echo "Creating snapshot of '$dataset'"
            
            if ! /usr/bin/zfs-auto-snapshot --skip-scrub --prefix=snapshot --label=$timer --keep=$(get_prop value zfs:snapshot.keep_$timer $dataset) $dataset; then
                /usr/bin/alert2 --priority "medium" --title "ZFS Snapshot" "ZFS Auto Snapshot failed on dataset '$dataset' with error '$?'"
            fi
        fi
    done
done

