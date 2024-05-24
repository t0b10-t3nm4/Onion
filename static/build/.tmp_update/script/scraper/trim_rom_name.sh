#!/bin/sh
scraper=$1
file=$2

case $scraper in
screenscraper)
    # Cleaning up names
    romName=$(basename "$file")
    romNameNoExtension=${romName%.*}
    echo "$romNameNoExtension"

    romNameTrimmed="${romNameNoExtension/".nkit"/}"
    romNameTrimmed="${romNameTrimmed//"!"/}"
    romNameTrimmed="${romNameTrimmed//"&"/}"
    romNameTrimmed="${romNameTrimmed/"Disc "/}"
    romNameTrimmed="${romNameTrimmed/"Rev "/}"
    romNameTrimmed="$(echo "$romNameTrimmed" | sed -e 's/ ([^()]*)//g' -e 's/ [[A-z0-9!+]*]//g' -e 's/([^()]*)//g' -e 's/[[A-z0-9!+]*]//g')"
    romNameTrimmed="${romNameTrimmed//" - "/"%20"}"
    romNameTrimmed="${romNameTrimmed/"-"/"%20"}"
    romNameTrimmed="${romNameTrimmed//" "/"%20"}"
    #echo $romNameTrimmed # for debugging
    ;;

launchbox)
    # Cleaning up names
    romName=$(basename "$file")
    romNameNoExtension=${romName%.*}
    echo "$romNameNoExtension"

    romNameTrimmed="${romNameNoExtension/".nkit"/}"
    romNameTrimmed="${romNameTrimmed//"!"/}"
    romNameTrimmed="$(echo "$romNameTrimmed" | sed -e 's/&/and/g')"
    romNameTrimmed="${romNameTrimmed/"Disc "/}"
    romNameTrimmed="${romNameTrimmed/"Rev "/}"
    romNameTrimmed="$(echo "$romNameTrimmed" | sed -e 's/ ([^()]*)//g' -e 's/ [[A-z0-9!+]*]//g' -e 's/([^()]*)//g' -e 's/[[A-z0-9!+]*]//g')"
    romNameTrimmed="${romNameTrimmed//" - "/" "}"
    romNameTrimmed="${romNameTrimmed/"-"/" "}"

    # we put "The" at the beginning of the rom name
    if echo "$romNameTrimmed" | grep -q ", The"; then
        romNameTrimmed="${romNameTrimmed/, The/}"
        romNameTrimmed="The $romNameTrimmed"
    fi

    romNameTrimmed="${romNameTrimmed//","/}"
    # For debugging
    # echo romNameNoExtension= $romNameNoExtension
    # echo romNameTrimmed= $romNameTrimmed

    romNameTrimmed=${romNameTrimmed// /%}
    romNameTrimmed=${romNameTrimmed//\'/%}

    # echo romNameTrimmed percent= $romNameTrimmed
    ;;

retroarch)
    # Cleaning up names
    romName=$(basename "$file")
    romNameNoExtension=${romName%.*}
    romNameNoExtensionNoSpace=$(echo $romNameNoExtension | sed 's/ /%20/g')

    echo "$romNameNoExtension"
    #echo -e "$romNameNoExtension \n   ---- $romNameNoExtensionNoSpace"  # for debugging
    ;;
esac

echo "noextension=$romNameNoExtension; trimmed=$romNameTrimmed"
