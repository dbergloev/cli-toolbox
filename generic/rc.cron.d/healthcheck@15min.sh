#!/bin/bash

###
#
get_mem() {
    local memory="$(memory --type mem | tail -n +2)"
    local total=$(awk '{print $2}' <<< "$memory")
    local used=$(awk '{print $3}' <<< "$memory")
    
    echo $(( 100 * $used / $total ))
}

###
#
get_thermal() {
    local temp=0
    local line=$(thermal-probe thermal-zone | grep -E 'x86_|cpu[_-]' | head -n1)

    if [[ -n "$line" ]]; then
        temp=$(cut -d: -f2 <<< "$line")
        
    else
        for chip in coretemp k10temp; do
            temp=$(thermal-probe -m $chip)
            
            if [ $? -eq 0 ]; then
                break
            fi
        done
    fi

    if [ $temp -gt 0 ]; then
        echo $(($temp / 1000))
        
    else
        echo 0
    fi
}

###
#
get_load() {
    local cores=$(grep -c ^processor /proc/cpuinfo 2>/dev/null)
    local loadavg1=$(cut -f1 -d ' ' /proc/loadavg)
    local loadavg5=$(cut -f2 -d ' ' /proc/loadavg)

    if [ $cores -eq 0 ]; then
        cores=1
    fi

    awk -v s1="$loadavg1" -v s2="$cores" 'BEGIN { printf("%.2f", s1 / s2) }'
}

echo "Checking system health"

###
#
if awk -v s1="$(get_load)" "BEGIN {exit !(s1 > 0.85)}"; then
    echo "Critical: System CPU load is above threshold"
    /usr/bin/alert --priority "critical" --title "System Health" --id "sys_health_cpu" --timeout 86400 "System CPU load is above threshold"
    
else
    /usr/bin/alert --priority "low" --title "System Health" --id "sys_health_cpu" --timeout reset "System CPU load is normalized"
fi

###
#
if awk -v s1="$(get_thermal)" "BEGIN {exit !(s1 > 68)}"; then
    echo "Critical: System CPU thermals is above threshold"
    /usr/bin/alert --priority "critical" --title "System Health" --id "sys_health_thermals" --timeout 86400 "System CPU thermals are above threshold"
    
else
    /usr/bin/alert --priority "low" --title "System Health" --id "sys_health_thermals" --timeout reset "System CPU thermals are normalized"
fi

###
#
if awk -v s1="$(get_mem)" "BEGIN {exit !(s1 > 85)}"; then
    echo "Critical: System memory utilization is above threshold"
    /usr/bin/alert --priority "critical" --title "System Health" --id "sys_health_memory" --timeout 86400 "System memory utilization is above threshold"
    
else
    /usr/bin/alert --priority "low" --title "System Health" --id "sys_health_memory" --timeout reset "System memory utilization is normalized"
fi

