#!/bin/bash

### This requires the following environment variables to be set:
###     S3_BUCKET
###     S3_REGION
###  Additionally, the lambda function requires an IAM role with read/write 
###  access to the bucket specified
# Lovingly crafted by Mitchell Scott 

set -o pipefail
startingYear="${STARTING_YEAR:-2020}"

pointReleases=()
currentYear=$(date +%Y)
green=`tput setaf 2`
red=`tput setaf 1`
reset=`tput sgr0`

_log() {
    local IFS=$' \n\t'
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2;
}

printXML() {
    printf "$* \n" >> /tmp/versions.xml
}
if [[ -z "${S3_BUCKET+set}" || -z "${S3_REGION}" ]]; then
    _log "${red}ERROR! Missing s3 variables!${reset}"
    exit 1
fi
_log "Downloading previous version XML from http://$S3_BUCKET.s3-website.$S3_REGION.amazonaws.com/versions.xml"
curl -s "http://$S3_BUCKET.s3-website.$S3_REGION.amazonaws.com/versions.xml" -o /tmp/oldVersions.xml
sed -i 1d /tmp/oldVersions.xml

if [[ -z "${MAJOR_VERSION_LIST+set}" ]]; then
    _log "Detecting major versions"
    majorVersions=()
    curl -s https://www.tableau.com/support/releases/server -o /tmp/server-releases.html

    for year in $(eval echo "{$startingYear..$currentYear}")
    do
        for major in {1..4}
        do
            if grep -m1 -A1 https://www.tableau.com/support/releases/server/$year.$major /tmp/server-releases.html > /dev/null; then
                majorVersions+=("$year.$major")
            fi
        done
    done
else
    _log "Using major version list supplied by env"
    majorVersions=($MAJOR_VERSION_LIST)
fi

_log "Detecting most recent point releases"
for majorVersion in "${majorVersions[@]}"
do
    version=$(grep -m1 -A1 https://www.tableau.com/support/releases/server/$majorVersion /tmp/server-releases.html | tail -n1 | xargs)
    if [ "$?" -eq 0 ]; then
        if output=$(echo "$version" | awk -F . 'NF < 3' | grep .) ; then
            version="${version}.0"
        fi
        pointReleases+=($version)
    fi
done

printXML "<Versions>"
printXML "<!-- $(date "+%B %Y") -->"

_log "Pulling info for most recent point releases..."
for each in "${pointReleases[@]}"
do
    failed="false"
    _log "   $each"
    # Split the elements up 
    year=$(echo "$each" | awk -F . '{print $1}')
    major=$(echo "$each" | awk -F . '{print $2}')
    patch=$(echo "$each" | awk -F . '{print $3}')

    # Get the buildnumber
    buildnumber=$(curl -s https://www.tableau.com/support/releases/server/$each | grep "<p>$year$major" | sed -r 's/<..?>//g' | xargs)
    if [ "$?" -eq "0" ]; then
        _log "    ${green}✓${reset} Build number"
    else
        failed="true"
        _log "    ${red}✗${reset} Build number"
    fi
    # Get hashes
    curl -s "https://downloads.tableau.com/esdalt/JSON/$each.json" -o /tmp/$each.json
    sed -i 's/jsonCallback(\[//g' /tmp/$each.json
    sed -i 's/]);//g' /tmp/$each.json

    debianHash=$(jq '.release[0].linux_installers[] | select(.name=='\"tableau-server-$year-$major-${patch}_amd64.deb\"') | .sha256_hash' /tmp/$each.json | sed 's/"//g')
    if [ "$?" -eq "0" ]; then
        _log "    ${green}✓${reset} Debian hash"
    else
        failed=true
        _log "    ${red}✗${reset} Debian hash"
    fi
 
    rhelHash=$(jq '.release[0].linux_installers[] | select(.name=='\"tableau-server-$year-$major-${patch}.x86_64.rpm\"') | .sha256_hash' /tmp/$each.json | sed 's/"//g')
    if [ "$?" -eq "0" ]; then
        _log "    ${green}✓${reset} RHEL hash"
    else
        failed=true
        _log "    ${red}✗${reset} RHEL hash"
    fi

    windowsHash=$(jq '.release[0].server_primary_installers[] | select(.name=='\"TableauServer-64but-$year-$major-${patch}.exe\"') | .sha256_hash' /tmp/$each.json | sed 's/"//g')
    if [ "$?" -eq "0" ]; then
        _log "    ${green}✓${reset} Windows hash"
    else
        failed=true
        _log "    ${red}✗${reset} Windows hash"
    fi
    rm /tmp/$each.json

    # Print to XML
    if [ $failed = "false" ]; then
        printXML "   <Version>"
        printXML "       <number>$each</number>"
        printXML "       <debian>"
        printXML "           <hash>$debianHash</hash>"
        printXML "           <build>$buildnumber</build>"
        printXML "       </debian>"
        printXML "       <fedora>"
        printXML "           <hash>$rhelHash</hash>"
        printXML "           <build>$buildnumber</build>"
        printXML "       </fedora>"
        printXML "       <windows>"
        printXML "           <hash>$windowsHash</hash>"
        printXML "           <build>$buildnumber</build>"
        printXML "       </windows>"
        printXML "    </Version>"
    fi
done

# _log "Building final versions.xml file"
cat /tmp/oldVersions.xml >> /tmp/versions.xml
_log "Copying to s3 bucket: $S3_BUCKET"
aws s3 cp /tmp/versions.xml s3://$S3_BUCKET/versions2.xml
if [ "$?" -eq "0" ]; then
        _log "♫ Script complete ♫"
else
    _log "${red}S3 upload failed!${reset}"
        exit 1
fi
