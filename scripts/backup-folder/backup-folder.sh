#!/bin/bash

#       ____             _                  ______    _     _
#      |  _ \           | |                |  ____|  | |   | |
#      | |_) | __ _  ___| | ___   _ _ __   | |__ ___ | | __| | ___ _ __
#      |  _ < / _` |/ __| |/ / | | | '_ \  |  __/ _ \| |/ _` |/ _ \ '__|
#      | |_) | (_| | (__|   <| |_| | |_) | | | | (_) | | (_| |  __/ |
#      |____/ \__,_|\___|_|\_\\__,_| .__/  |_|  \___/|_|\__,_|\___|_|
#                                  | |
#                                  |_|
# v2.3.8

# Purpose:
# The purpose of this script is to backup a defined folder to another folder using tar archiving and pigz compression
# This can be useful if you have folders that are vital to keep and wish to back them up to another location
# Eg: I back up my Pictures directory to a backup share, then backup that share offsite so that way I always have at least 3 copies
# at all times of a particular picture. Backups are deleted at intervals as new ones become available. The offsite backup is kept in sync
# with the backup share.
# There are many different ways to achieve this functionality I wrote this to suite my needs.

#------------- DEFINE VARIABLES -------------#
name=''                         # Set your script name, must be unique to any other script.
source=''                       # Set source directory
destination=''                  # Set backup directory
keep_backup=2                   # Number of days to keep backup
compress=yes                    # Use 7Zip to further compress your backup (yes) will use 7Zip to further compress, (no) will not use 7Zip

unraid_notify=no                # Use unRAID's built in notification system
alternate_format=no             #This option will remove the time from the file and move it over to the directory structure.
                                    #Yes = /path/to/source/yyyy-mm-dd@00.01_AM/<container_name>.tar
                                    #No = /path/to/source/yyyy-mm-dd/<container_name>-12_01_AM.tar.7z
#------------- DEFINE DISCORD VARIABLES -------------#
# This section is not required

use_discord=yes                                                                                                                    # Use discord for notifications
webhook=''                      # Discord webhook
bot_name='Notification Bot'                                                                                                        # Name your bot
bar_color='3036236'                                                                                                                # The bar color for discord notifications, must be decimal -> https://www.mathsisfun.com/hexadecimal-decimal-colors.html

#------------- DO NOT MODIFY BELOW THIS LINE -------------#
# Will not run again if currently running.
if [ ! -d "$source" ]; then
    echo "ERROR: Your source directory does not exist, please check your configuration"
    exit 2
fi
if [ -z "$source" ]; then
    echo "ERROR: Your source directory is not set, please check your configuration."
    exit 2
fi
if [ "$use_discord" == "yes" ] && [ -z "$webhook" ]; then
    echo "ERROR: You're attempting to use the Discord integration but did not enter the webhook url."
    exit 1
fi

if [ "$compress" == "yes" ]; then
    command -v 7z >/dev/null 2>&1 || {
        echo -e "7Zip is not installed.\nPlease install 7Zip and rerun.\nIf on unRaid, 7Zip can be found through the NerdTools which is found in the appstore" >&2
        exit 1
    }
fi

if [ -e "/tmp/i.am.running.${name}.tmp" ]; then
    echo "Another instance of the script is running. Aborting."
    echo "Please use rm /tmp/i.am.running.${name}.tmp in your terminal to remove the locking file"
    exit 1
else
    touch "/tmp/i.am.running.${name}.tmp"
fi

#Set variables
start=$(date +%s) #Sets start time for runtime information

parentdir=$(dirname "$source")
cd "$(realpath -s "$parentdir")" || exit
source_basename=$(basename "$source")

dest=$(realpath -s "$destination")

if [ "$alternate_format" == "yes" ]; then
    dt=$(date +"%Y-%m-%d"@%H.%M)
else
    dt=$(date +"%Y-%m-%d")
    now=$(date +"%H.%M")
fi

# create the backup directory if it doesn't exist - error handling - will not create backup file it path does not exist
mkdir -p "$dest"
# Creating backup of directory
echo -e "\nCreating backup..."
mkdir -p "$dest/$dt"

# Data Backup
if [ "$compress" == "yes" ]; then
    if [ "$alternate_format" != "yes" ]; then
        tar cf - "$source_basename" | 7z a -si -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on "$dest/$dt/backup-$now.tar.7z"
        run_size=$(du -sh "$dest/$dt/backup-$now.tar.7z" | awk '{print $1}')
    else

        tar cf - "$source_basename" | 7z a -si -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on "$dest/$dt/backup.tar.7z"
        run_size=$(du -sh "$dest/$dt/backup.tar.7z" | awk '{print $1}')
    fi
else
    if [ "$alternate_format" != "yes" ]; then
        tar -cf "$dest/$dt/backup-$now.tar" "$source"
        run_size=$(du -sh "$dest/$dt/backup-$now.tar" | awk '{print $1}') #Set run_size information
    else
        tar -cf "$dest/$dt/backup-$now.tar" "$source"
        run_size=$(du -sh "$dest/$dt/backup.tar" | awk '{print $1}') #Set run_size information
    fi
fi
sleep 2
chmod -R 777 "$dest"

#Cleanup Old Backups
cd "$destination" || exit
# echo -e "\nRemoving backups older than " "$delete_after" "days...\n"
# find "$destination"* -mtime +"$delete_after" -type d -exec rm -rf {} \;
echo -e "Removing all but the last " $keep_backup "backups... please wait"
ls -1tr | head -n -$keep_backup | xargs -d '\n' rm -Rfd --

echo "Done"

end=$(date +%s)
# Runtime
total_time=$((end - start))
seconds=$((total_time % 60))
minutes=$((total_time % 3600 / 60))
hours=$((total_time / 3600))

if ((minutes == 0 && hours == 0)); then
    run_output="Script completed in $seconds seconds"
elif ((hours == 0)); then
    run_output="Script completed in $minutes minutes and $seconds seconds"
else
    run_output="Script completed in $hours hours $minutes minutes and $seconds seconds"
fi
echo "$run_output"
# Gather size information
echo -e "This backup's size: $run_size"
if [ -d "$dest"/ ]; then
    total_size=$(du -sh "$dest" | awk '{print $1}')
    echo -e "\nTotal size of all backups: $total_size"
fi

# Notifications
if [ "$unraid_notify" == "yes" ]; then
    get_ts=$(date -u -Iseconds)
    /usr/local/emhttp/webGui/scripts/notify -e "Unraid Server Notice" -s "${name} Backup" -d "Backup completed: ${name} data has been backed up." -i "normal"
fi
if [ "$use_discord" == "yes" ]; then
    curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'"${bot_name}"'","embeds": [{"title": "'"${name} Backup Complete"'","description": "'"Backup completed: ${name} data has been backed up."'","fields": [{"name": "Runtime:","value": "'"${run_output}"'"},{"name": "'"This Backup's size:"'","value": "'"${run_size}"'"},{"name": "Total size of all backups:","value": "'"${total_size}"'"}],"footer": {"text": "Powered by: Drazzilb | What if there were no hypothetical questions?","icon_url": "https://i.imgur.com/r69iYhr.png"},"color": "'"${bar_color}"'","timestamp": "'"${get_ts}"'"}]}' "$webhook"
    echo -e "\nDiscord notification sent."
fi
echo -e '\nAll Done!\n'
# Removing temp \file
rm "/tmp/i.am.running.${name}.tmp"
exit 0
