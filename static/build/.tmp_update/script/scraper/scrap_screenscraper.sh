#!/bin/sh
#echo $0 $*    # for debugging

if [ -z "$1" ]
then
  echo -e "\nusage : scrap_screenscraper.sh emu_folder_name [rom_name]\nexample : scrap_screenscraper.sh SFC\n"
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
allowed_threads=1

Screenscraper_information () {
    clear 

    cat << 	EOF

===================================
      = Screenscraper.fr =
===================================

Maximum number of requests per day:

-----------------------------------

Non-registered : 10.000 requests per day

level 0 to 19  : 20.000 requests per day
level 19 to 29 : 50.000 requests per day
level > 29     : 100.000 requests per day

1 or 2€  donation : 50.000  requests per day
5 or 10€ donation : 100.000 requests per day
moderator/Admin     : 200.000 requests per day

-----------------------------------





EOF

    read -n 1 -s -r -p "Press A to continue"
    clear 

    cat << 	EOF

===================================
      = Screenscraper.fr =
===================================

Additional information :

-----------------------------------

Increase your level requires to participate in the
evolution of the Screenscraper database and media. 

Quota counters are reset every day at midnight 
(French time - UTC+2) 

Download speed also increase with participation 
to database or with donations.

All is detailed at : 
https://www.screenscraper.fr/faq.php

-----------------------------------

EOF

    read -n 1 -s -r -p "Press A to continue"
    clear
}

# Function to search on screenscraper with retry logic
search_on_screenscraper() {
    local retry_count=0
    local max_retries=5

    while true; do		
        api_result=$(curl -k -s "$url")
		Head_api_result=$(echo "$api_result" | head -n 1)
        
        # Don't check art if max threads for leechers is used
        if echo "$Head_api_result" | grep -q "The maximum threads"; then
            if [ "$retry_count" -ge "$max_retries" ]; then
                echo "The Screenscraper API is too busy for non-users. Please try again later (or register)."
                echo "Press any key to finish"
                read dummy
                break
            else
                let retry_count++
                echo "Retrying API call ($retry_count / $max_retries)..."
				echo "Registering a Screenscraper account can help !"
                sleep_duration=$((5 + retry_count))
                sleep "$sleep_duration"
            fi
        else
            # we have a result, we exit 
            break
        fi
    done

    # Don't check art if screenscraper is closed
    if echo "$Head_api_result" | grep -q "API closed"; then
        echo -e "${RED}The Screenscraper API is currently down, please try again later.{NONE}"
        let Scrap_Fail++
        read -n 1 -s -r -p "Press A to exit"
        return
    fi

    # Don't check art after a failed curl request
    if [ -z "$Head_api_result" ]; then
        echo -e "${RED}Request failed${NONE}"
        echo "Request failed for $romNameNoExtensionTrimmed" >> /mnt/SDCARD/.tmp_update/logs/scrap.log
        let Scrap_Fail++
        return
    fi
    
    # Don't check art if screenscraper can't find a match
    if echo "$Head_api_result" | grep -q "^Erreur"; then
        echo -e "${RED}No match found${NONE}"
        echo "Couldn't find a match for $romNameNoExtensionTrimmed" >> /mnt/SDCARD/.tmp_update/logs/scrap.log
        return
    fi

    gameIDSS=$(echo "$api_result" | jq -r '.response.jeu.id')
	if ! [ "$gameIDSS" -eq "$gameIDSS" ] 2> /dev/null; then
		gameIDSS=$(echo "$api_result" | jq -r '.jeu.id')
	fi
}

get_ssSystemID() {
    # Get directory name from function argument
    directory_name="$1"
    json_file="/mnt/SDCARD/.tmp_update/config/systems.json"

    # Use jq to find the ScreenScraperSystem based on the DirectoryName
    screen_scraper_system=$(jq --arg dir "$directory_name" '
        .[] | select(.DirectoryName == $dir) | .ScreenScraperSystem
    ' $json_file)

    # Check if a ScreenScraperSystem was found
    if [ -z "$screen_scraper_system" ]; then
        echo "No system found for the directory: $directory_name"
        exit
    else
        echo "ScreenScraperSystem ID for $directory_name is: $screen_scraper_system"
    fi

    ssSystemID=$screen_scraper_system
}

# TODO: Retrive the number of allowed threads from screenscraper.fr
get_allowed_threads() {
    # simulate the service call        
    sleep 1
    
    # we have a result, we set allowed_threads
}

scrape_game() {
    file="$1"
    gameIDSS=""
	url=""
    let romcount++;
    
    # Cleaning up names
    romName=$(basename "$file")
    romNameNoExtension=${romName%.*}
	echo "$romNameNoExtension"
    
    eval /mnt/SDCARD/.tmp_update/script/scraper/trim_rom_name.sh screenscraper "$romNameNoExtension"
    
    #echo $romNameTrimmed # for debugging
    echo "-------------------------------------------------"

	if [ -f "/mnt/SDCARD/Roms/$CurrentSystem/Imgs/$romNameNoExtension.png" ]; then
		echo -e "$romNameNoExtension: ${YELLOW}Already Scraped!${NONE}"
		let Scrap_notrequired++;
	else
		rom_size=$(stat -c%s "$file")
		url="https://www.screenscraper.fr/api2/jeuInfos.php?devid=${u#???}&devpassword=${p%??}&softname=onion&output=json&ssid=${userSS}&sspassword=${passSS}&crc=&systemeid=${ssSystemID}&romtype=rom&romnom=${romNameTrimmed}.zip&romtaille=${rom_size}"
    	search_on_screenscraper
    	
    	# Don't check art if we didn't get screenscraper game ID
        if ! [ "$gameIDSS" -eq "$gameIDSS" ] 2> /dev/null; then
			# Last chance : we search thanks to rom checksum
			MAX_FILE_SIZE_BYTES=52428800  #50MB
			
			if [ "$rom_size" -gt "$MAX_FILE_SIZE_BYTES" ]; then
				echo -e "$romNameNoExtension: ${RED}Rom is too big to make a checksum.${NONE}"
				let Scrap_Fail++;
				continue;				
			else
				echo -n "$romNameNoExtension: CRC check..."
				CRC=$(xcrc "$file")
				echo " $CRC"
				# !!! systemid must not be specified, it impacts the search by CRC but not romtaille (must be > 2 however) or romnom. Most of other parameters than CRC are useless for the request but helps to fill SS database
				url="https://www.screenscraper.fr/api2/jeuInfos.php?devid=${u#???}&devpassword=${p%??}&softname=onion&output=json&ssid=${userSS}&sspassword=${passSS}&crc=${CRC}&systemeid=&romtype=rom&romnom=${romNameTrimmed}.zip&romtaille=${rom_size}"  
				search_on_screenscraper

				if ! [ "$gameIDSS" -eq "$gameIDSS" ] 2> /dev/null; then	
					echo -e "$romNameNoExtension: ${RED}Failed to get game ID${NONE}"
					let Scrap_Fail++;
					continue;
				fi
				
				RealgameName=$(echo "$api_result" | jq -r '.response.jeu.noms[0].text')
				echo "$romNameNoExtension: Real name found : $RealgameName"
			fi
        fi
		
        echo "gameID = $gameIDSS"
        
		api_result=$(echo $api_result | jq '.response.jeu.medias')   # we keep only media section for faster search : 0.01s instead of 0.25s after that

        # for debugging :
        # echo -e "Region1: $Region1\nRegion2: $Region2\nRegion3: $Region3\nRegion4: $Region4\nRegion5: $Region5\nRegion6: $Region6\nRegion7: $Region7\nRegion8: $Region8\n$MediaType"
        # MediaType="box-2D"
        # region1="eu"
        # echo "$api_result" | jq --arg MediaType "$MediaType"  --arg Region1 "$region1"  --arg Region2 "$region2" 'map(select(.type == $MediaType)) | sort_by(if .region == $Region1 then 0 elif .region == $Region2 then 1 else 8 end)'
        # Old way:
        # MediaURL=$(echo "$api_result" | jq --arg MediaType "$MediaType" --arg Region "$region" '.response.jeu.medias[] | select(.type == $MediaType) | select(.region == $region) | .url' | head -n 1)
        # MediaURL=$(echo "$api_result" | jq --arg MediaType "$MediaType" --arg Region "$region" '.[] | select(.type == $MediaType) | select(.region == $region) | .url' | head -n 1)



        # this jq query will search all the images of type "MediaType" and will display it by order defined in RegionOrder
        MediaURL=$(echo "$api_result" | jq --arg MediaType "$MediaType" \
                                --arg Region1 "$Region1" \
                                --arg Region2 "$Region2" \
                                --arg Region3 "$Region3" \
                                --arg Region4 "$Region4" \
                                --arg Region5 "$Region5" \
                                --arg Region6 "$Region6" \
                                --arg Region7 "$Region7" \
                                --arg Region8 "$Region8" \
                                'map(select(.type == $MediaType)) |
                                    sort_by(if .region == $Region1 then 0
                                        elif .region == $Region2 then 1
                                        elif .region == $Region3 then 2
                                        elif .region == $Region4 then 3
                                        elif .region == $Region5 then 4
                                        elif .region == $Region6 then 5
                                        elif .region == $Region7 then 6
                                        elif .region == $Region8 then 7
                                        else 8 end) |
                                .[0].url' | head -n 1)

        if [ -z "$MediaURL" ]; then 
            echo -e "${YELLOW}Game matches but no media found!${NONE}"
            let Scrap_Fail++
            continue
        fi
        
        # echo -e "Downloading Images for $romNameNoExtension \nScreenscraper ID : $gameIDSS \n url :$MediaURL\n\n"        # for debugging

        MediaURL=$(echo "$MediaURL" | sed 's/"$/\&maxwidth=250\&maxheight=360"/')
        urlcmd=$(echo "wget -q --no-check-certificate "$MediaURL" -P \"/mnt/SDCARD/Roms/$CurrentSystem/Imgs\" -O \"$romNameNoExtension.png\"")
        
        # directl download trigger an error
        #wget --no-check-certificate "$MediaURL" -P "/mnt/SDCARD/Roms/$CurrentSystem/Imgs" -O "$romNameNoExtension.png"
        #wget $urlcmd

        echo $urlcmd>/tmp/rundl.sh
        sh /tmp/rundl.sh

		if [ -f "/mnt/SDCARD/Roms/$CurrentSystem/Imgs/$romNameNoExtension.png" ]; then
			echo -e "$romNameNoExtension: ${GREEN}Scraped!${NONE}"
			let Scrap_Success++;
		else
			echo -e "$romNameNoExtension: ${RED}Download failed.${NONE}"
			let Scrap_Fail++;
		fi

        #pngscale "/mnt/SDCARD/Roms/$CurrentSystem/Imgs/$romNameNoExtension.png" "/mnt/SDCARD/Roms/$CurrentSystem/Imgs/$romNameNoExtension.png"

        #####################################################################################################################################
        #   saveMetadata=false
        #   if [ $saveMetadata == true ]; then
        #       mkdir -p /mnt/SDCARD/Roms/$CurrentSystem/info > /dev/null
        #   
        #       if [ -f "/mnt/SDCARD/Roms/$CurrentSystem/info/$romNameNoExtension.txt" ]; then
        #           echo -e "${YELLOW}Metadata already Scraped !${NONE}"
        #       else
        #           genre_array=$( echo $api_result | jq -r '[foreach .response.jeu.genres[].noms[] as $item ([[],[]]; if $item.langue == "en" then $item.text else "" end)]'  )
        #           echo "" >> "/mnt/SDCARD/Roms/$CurrentSystem/info/$romNameNoExtension.txt"
        #           echo game: $romNameNoExtension >> "/mnt/SDCARD/Roms/$CurrentSystem/info/$romNameNoExtension.txt"
        #           echo file: $romName >> "/mnt/SDCARD/Roms/$CurrentSystem/info/$romNameNoExtension.txt"
        #           echo developer: $( echo $api_result | jq -r  '.response.jeu.developpeur.text' ) >> "/mnt/SDCARD/Roms/$CurrentSystem/info/$romNameNoExtension.txt"
        #           echo publisher: $( echo $api_result | jq -r  '.response.jeu.editeur.text'  ) >> "/mnt/SDCARD/Roms/$CurrentSystem/info/$romNameNoExtension.txt"
        #           echo genre: $( echo $genre_array | jq '. - [""] | join(", ")' ) | sed 's/[\"]//g' >> "/mnt/SDCARD/Roms/$CurrentSystem/info/$romNameNoExtension.txt"
        #           echo description: $( echo $api_result | jq -r  '.response.jeu.synopsis[0].text'  ) >> "/mnt/SDCARD/Roms/$CurrentSystem/info/$romNameNoExtension.txt"
        #           echo release: $( echo $api_result | jq -r  '.response.jeu.dates[0].text'  ) >> "/mnt/SDCARD/Roms/$CurrentSystem/info/$romNameNoExtension.txt"
        #           echo players: $( echo $api_result | jq -r  '.response.jeu.joueurs.text'  ) >> "/mnt/SDCARD/Roms/$CurrentSystem/info/$romNameNoExtension.txt"
        #           echo rating: $( echo $api_result | jq -r  '.response.jeu.classifications[0].text'  ) >> "/mnt/SDCARD/Roms/$CurrentSystem/info/$romNameNoExtension.txt"
        #           echo -e "Metadata saved to :\n/mnt/SDCARD/Roms/$CurrentSystem/info/$romNameNoExtension.txt"
        #       fi
        #   fi
        #####################################################################################################################################
        
        #TODO : get manual	

    fi
}	

saveMetadata=false
clear
echo -e "\n*****************************************************"
echo -e "******************* SCREENSCRAPER *******************"
echo -e "*****************************************************\n\n"

#We check for existing credentials
ScraperConfigFile=/mnt/SDCARD/.tmp_update/config/scraper.json

if [ -f "$ScraperConfigFile" ]; then
    config=$(cat $ScraperConfigFile)
	MediaType=$(echo "$config" | jq -r '.ScreenscraperMediaType')
	SelectedRegion=$(echo "$config" | jq -r '.ScreenscraperRegion')
	echo "Scraping $CurrentSystem..."
	echo "Media Type: $MediaType"
	echo "Current Region: $SelectedRegion"
    userSS=$(echo "$config" | jq -r '.screenscraper_username')
    passSS=$(echo "$config" | jq -r '.screenscraper_password')
    ScrapeInBackground=$(echo "$config" | jq -r '.ScrapeInBackground')
	u=$(echo "U2FsdGVkX18PKpoEvELyE+5xionDX8iRxAIxJj4FN1U=" | openssl enc -aes-256-cbc -d -a -pbkdf2 -iter 10000 -salt -pass pass:"3x0tVD3jZvElZWRt3V67QQ==")
	p=$(echo "U2FsdGVkX1/ydn2FWrwYcFVc5gVYgc5kVaJ5jDOeOKE=" |openssl enc -aes-256-cbc -d -a -pbkdf2 -iter 10000 -salt -pass pass:"RuA29ch3zVoodAItmvKKmZ+4Au+5owgvV/ztqRu4NjI=")
	# Regions order management
	regionsDB="/mnt/SDCARD/.tmp_update/script/scraper/screenscraper_database/regions.db"
	RegionOrder=$(sqlite3 $regionsDB "SELECT ss_tree || ';' || ss_fallback FROM regions WHERE ss_nomcourt = '$SelectedRegion';")
# we split the RegionOrder in each region variable (do not indent)
IFS=';' read -r Region1 Region2 Region3 Region4 Region5 Region6 Region7 Region8 <<EOF
$RegionOrder
EOF

    if [ "$userSS" = "null" ] || [ "$passSS" = "null" ] || [ "$userSS" = "" ] || [ "$passSS" = "" ]; then
        userStored="false"
    else
        userStored="true"
        echo "screenscraper username: $userSS"
        echo -e "screenscraper password: xxxx (hidden)\n\n"
    fi
fi

# TODO : improve or remove this part (now in options)
if [ "$userStored" = "false" ] && ! [ "$ScrapeInBackground" = "true" ]; then
    while true; do
	    Mychoice=$( echo -e "No\nYes\nScreenscraper information" | /mnt/SDCARD/.tmp_update/script/shellect.sh -t "Add your screenscraper account ?" -b "Press A to validate your choice.")
        
        if [ "$Mychoice" = "Yes" ]; then
			clear
			echo -ne "\e[?25h"  # display the cursor
			echo -e "Press X to display the keyboard.\nPress A to enter a key.\nPress L1 for shift.\nPress R1 for backspace.\nPress Enter to validate.\n\n\n\nEnter your screenscraper username.\n\n"
			readline -m "username: "
			userSS=$(cat /tmp/readline.txt)
			userSS="${userSS// /}"  # removing spaces
			rm /tmp/readline.txt
			config=$(cat $ScraperConfigFile)
			config=$(echo "$config" | jq --arg user "$userSS" '.screenscraper_username = $user')
			echo "$config" > $ScraperConfigFile
			# read -p "username : " userSS
			sync
			clear
			echo -ne "\e[?25h"  # display the cursor
			echo -e "Press X to display the keyboard.\nPress A to enter a key.\nPress L1 for shift.\nPress R1 for backspace.\nPress Enter to validate.\n\n\n\nEnter your screenscraper password.\n\n"
			readline -m "password: "
			passSS=$(cat /tmp/readline.txt)
			passSS="${passSS// /}"  # removing spaces
			rm /tmp/readline.txt
			config=$(cat $ScraperConfigFile)
			config=$(echo "$config" | jq --arg pass "$passSS" '.screenscraper_password = $pass')
			echo "$config" > $ScraperConfigFile
			# read -p "password : " passSS
			sync
			clear
			break
        elif [ "$Mychoice" = "Screenscraper information" ]; then
			clear
			Screenscraper_information
        else
			clear
			break
        fi
    done
fi
		
clear
echo -e "\n*****************************************************"
echo -e "******************* SCREENSCRAPER *******************"
echo -e "*****************************************************\n\n"

echo "Scraping $CurrentSystem..."
echo "Media Type: $MediaType"
echo "Current Region: $SelectedRegion"

if [ "$userStored" = "true" ]; then
	echo "screenscraper username: $userSS"
	echo -e "screenscraper password: xxxx (hidden)\n\n"
else
	echo -e "screenscraper account not configured.\n\n"
fi

####################################################################################################################################
 #ls /mnt/SDCARD/Roms/$CurrentSystem
 get_ssSystemID $CurrentSystem

 #ls /mnt/SDCARD/Roms/$CurrentSystem
 mkdir -p /mnt/SDCARD/Roms/$CurrentSystem/Imgs > /dev/null

# =================
#this is a trick to manage spaces from find command, do not indent or modify
IFS='
'
set -f
# =================

#Roms loop

#if ! [ -z "$CurrentRom" ]; then
#    romfilter="-name  '*$CurrentRom*'"
#fi

if ! [ -z "$CurrentRom" ]; then
 #   CurrentRom_noapostrophe=${CurrentRom//\'/\\\'}    # replacing   '   by    \'
 #   romfilter="-name  '*$CurrentRom_noapostrophe*'"
 #   romfilter="-name  '*$CurrentRom*'"
    #romfilter="-name  '*$CurrentRom*'"
    romfilter="-name \"*$CurrentRom*\""
fi

# Call the ScreenScraper web service to get the number of allowed threads
# TODO: Get the number of allowed threads from screenscraper.fr in the get_allowed_threads function and remove hard coded value. 
allowed_threads=4

for file in $(eval "find /mnt/SDCARD/Roms/$CurrentSystem -maxdepth 2 -type f \
	! -name '.*' ! -name '*.xml' ! -name '*.miyoocmd' ! -name '*.cfg' ! -name '*.db' \
	! -path '*/Imgs/*' ! -path '*/.game_config/*' $romfilter"); do

    while [ "$(ps -ef | grep -c "$(basename "$0")")" -ge "$allowed_threads" ]; do
        sleep 1
    done

    scrape_game "$file" &
done

wait

# Execute scraping completed logic
echo -e "\n--------------------------"
echo "Total scanned roms   : $romcount"
echo "--------------------------"
echo "Successfully scraped : $Scrap_Success"
echo "Already present      : $Scrap_notrequired"
echo "Failed or not found  : $Scrap_Fail"
echo -e "--------------------------\n"	 
sleep 2
echo "********   Screenscraper scraping finished   ********"

echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor