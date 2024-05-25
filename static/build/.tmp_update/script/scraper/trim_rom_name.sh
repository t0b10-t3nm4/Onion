#!/bin/sh
scraper=$1
file=$2

# Cleaning up names
romName=$(basename "$file")
romNameNoExtension=${romName%.*}

case $scraper in
screenscraper)
    # Clean up the names
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
    # echo "$romNameNoExtension"
    # echo -e "$romNameNoExtension \n   ---- $romNameNoExtensionNoSpace"  # for debugging
    romNameTrimmed=$romNameNoExtension
    ;;
esac

echo "$romNameTrimmed"