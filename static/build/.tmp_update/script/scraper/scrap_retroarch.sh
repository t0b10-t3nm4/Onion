#!/bin/sh
#echo $0 $*    # for debugging

if [ -z "$1" ]
then
  echo -e "\nusage : scrap_retroarch.sh emu_folder_name [rom_name]\nexample : scrap_retroarch SFC\n"
  exit
fi

sysdir=/mnt/SDCARD/.tmp_update
PATH="$sysdir/bin:$PATH"
LD_LIBRARY_PATH="/mnt/SDCARD/.tmp_update/lib:$sysdir/lib/parasyte:$LD_LIBRARY_PATH"

echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
#$sysdir/bin/freemma > /dev/null

NONE='\033[00m'
RED='\033[01;31m'
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
PURPLE='\033[01;35m'
CYAN='\033[01;36m'
WHITE='\033[01;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
BLINK='\x1b[5m'

romcount=0
Scrap_Success=0
Scrap_Fail=0
Scrap_notrequired=0

CurrentSystem=$1
CurrentRom="$2"


get_ra_alias(){

	# Get directory name from function argument
    DIRECTORY_NAME="$1"

    # Define the path to the JSON file
    JSON_FILE="/mnt/SDCARD/.tmp_update/config/systems.json"

    # Use jq to find the RetroArchSystem based on the DirectoryName
    REMOTE_SYSTEM=$(jq --arg dir "$DIRECTORY_NAME" '
        .[] | select(.DirectoryName == $dir) | .RetroArchSystem
    ' $JSON_FILE)

    # Check if a ScreenScraperSystem was found
    if [ -z "$REMOTE_SYSTEM" ]; then
        echo "No system found for the directory: $DIRECTORY_NAME"
		exit
    else
        echo "RetroArchSystem for $DIRECTORY_NAME is: $REMOTE_SYSTEM"
    fi

    remoteSystem=$REMOTE_SYSTEM
}

#Retroarch system folder name
get_ra_alias $CurrentSystem
 #ls /mnt/SDCARD/Roms/$CurrentSystem
mkdir -p /mnt/SDCARD/Roms/$CurrentSystem/Imgs &> /dev/null
clear
echo -e "\n*****************************************************"
echo -e "*******************   RETROARCH   *******************"
echo -e "*****************************************************\n\n"

ScraperConfigFile=/mnt/SDCARD/.tmp_update/config/scraper.json
config=$(cat $ScraperConfigFile)
MediaType=$(echo "$config" | jq -r '.RetroarchMediaType')
if [ -z "$MediaType" ]; then
	ssMediaType=$(echo "$config" | jq -r '.ScreenscraperMediaType')
    echo -e " The currently selected media ($ssMediaType)\n is not compatible with Retroarch scraper.\n\n\n\n\n\n\n\n\n\n\n\n Exiting."
	sleep 5
	exit
fi
echo "Media Type: $MediaType"
echo -e "Scraping $CurrentSystem...\n"
			
			
# =================
#this is a trick to manage spaces from find command, do not indent or modify
IFS='
'
set -f
# =================


#Roms loop
if ! [ -z "$CurrentRom" ]; then
 #   CurrentRom_noapostrophe=${CurrentRom//\'/\\\'}    # replacing   '   by    \'
 #   romfilter="-name  '*$CurrentRom_noapostrophe*'"
 #   romfilter="-name  '*$CurrentRom*'"
    romfilter="-name \"*$CurrentRom*\""
    #romfilter="-name  '*$CurrentRom*'"
    
fi

#eval echo "find /mnt/SDCARD/Roms/$CurrentSystem -maxdepth 2 -type f ! -name '.*' ! -name '*.xml' ! -name '*.db' ! -path '*/Imgs/*' ! -path '*/.game_config/*' $romfilter"      # for debugging
for file in $(eval "find /mnt/SDCARD/Roms/$CurrentSystem -maxdepth 2 -type f \
	! -name '.*' ! -name '*.xml' ! -name '*.miyoocmd' ! -name '*.cfg' ! -name '*.db' \
	! -path '*/Imgs/*' ! -path '*/.game_config/*' $romfilter"); do
	
    echo "-------------------------------------------------"
    let romcount++;
    
    # Cleaning up names
    romName=$(basename "$file")
    romNameNoExtension=${romName%.*}	
    romNameNoExtensionNoSpace=$(echo $romNameNoExtension | sed 's/ /%20/g')
    
    echo $romNameNoExtension
    #echo -e "$romNameNoExtension \n   ---- $romNameNoExtensionNoSpace"  # for debugging 
    
    remoteSystemNoSpace=$(echo $remoteSystem | sed 's/ /%20/g')
    
    startcapture=true
     
    
    if [ $startcapture == true ]; then
    		
    	FILE=/mnt/SDCARD/Roms/$CurrentSystem/Imgs/$romNameNoExtension.png
    	if [ -f "$FILE" ]; then
    		echo -e "${YELLOW}already Scraped !${NONE}"
    		let Scrap_notrequired++;
    	else
    	    wget -q --spider "http://thumbnails.libretro.com/$remoteSystemNoSpace/${MediaType}/$romNameNoExtensionNoSpace.png" 2>&1
    	    WgetResult=$?
    
    	    if [ $WgetResult = 0 ] ; then
            	wget -q  "http://thumbnails.libretro.com/$remoteSystemNoSpace/${MediaType}/$romNameNoExtensionNoSpace.png" -P "/mnt/SDCARD/Roms/$CurrentSystem/Imgs" -O "$romNameNoExtension.png"

            	# resizing :
            	#magick "/mnt/SDCARD/Roms/$CurrentSystem/Imgs/$romNameNoExtension.png" -resize 250x360 "/mnt/SDCARD/Roms/$CurrentSystem/Imgs/$romNameNoExtension-resized.png"
                #mv "/mnt/SDCARD/Roms/$CurrentSystem/Imgs/$romNameNoExtension-resized.png"  "/mnt/SDCARD/Roms/$CurrentSystem/Imgs/$romNameNoExtension.png"
                pngScale "/mnt/SDCARD/Roms/$CurrentSystem/Imgs/$romNameNoExtension.png" "/mnt/SDCARD/Roms/$CurrentSystem/Imgs/$romNameNoExtension.png"

            	echo -e "${GREEN}Scraped!${NONE}"
            	let Scrap_Success++;
    		else
    		    echo -e "${RED}No match found${NONE}"
    		    let Scrap_Fail++;
    		fi
    	fi
    
    
    fi
done

echo -e "\n--------------------------"
echo "Total scanned roms   : $romcount"
echo "--------------------------"
echo "Successfully scraped : $Scrap_Success"
echo "Alread present       : $Scrap_notrequired"
echo "Failed or not found  : $Scrap_Fail"
echo -e "--------------------------\n"
sleep 2
echo "**********   Retroarch scraping finished   **********"

echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

