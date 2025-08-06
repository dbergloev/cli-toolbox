# ZFS

This repo has a bunch of script automation for dealing with ZFS on servers. 

#### SmartCTL

Simple script that will run `smartctl` on any disk that is part of a ZFS pool. 

#### ZFS Scrub

Will run `zfs scrub` on any ZFS storage pool.

#### Disk Monitor

This script combines the work of ZFS Scrub and SmartCTL by analysing the result and reporting any issues that was raised. It also notifies you when a storage pool reaches 95% usage. 

#### Snapshot

Automatically creates snapshots of ZFS Datasets. You can use ZFS user properties to define which datasets to snapshot, how often and how many to keep of each. 

 * `zfs:snapshot=1` - Boolen to enable snapshot for this dataset.
 * `zfs:snapshot.keep_<timer>=<keep>` - Defines when to make snapshots and how many to keep. You can create multiple of these to have snapshots at various times. 
 
```sh
zfs set zfs:snapshot=1 <dataset>
zfs set zfs:snapshot.keep_daily=7 <dataset>
zfs set zfs:snapshot.keep_monthly=4 <dataset>
```

The above will take snapshots daily and monthly and keep 7 and 4 copies respectively. 

#### RClone

Automatically runs rclone against ZFS Datasets. Just like with snapshots, you can use dataset properties to configure each dataset.

 * `rclone:sync=1` - Boolean to enable rsync for this dataset.
 * `rclone:sync.path=<name:path>` - The remote path to sync against.
 * `rclone:sync.user=<user>` - The user to run rsync as, must have ~/.config/rclone/rclone.conf
 * `rclone:sync.do_<timer>=<action>` - Defines when to run rsync and what action to take, copy or sync.
 
```sh
zfs set rclone:sync=1 <dataset>
zfs set rclone:sync.path=koofr:MyFolder <dataset>
zfs set rclone:sync.user=sync-admin <dataset>
zfs set rclone:sync.do_hourly=copy <dataset>
zfs set rclone:sync.do_daily=sync <dataset>
```

The above will copy to `koofr:MyFolder` ones every hour and sync to it ones a day, using the user `sync-admin`.

