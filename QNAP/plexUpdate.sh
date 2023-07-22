#!/bin/sh

# -- Instructions --
#
# 1. Update the "PLEX_BUILD" architecture below as needed
# 2. Create the "PLEX_UPDATE_FOLDER" directory: mkdir -m 777 /share/CE_CACHEDEV1_DATA/PlexUpdate && cd /share/CE_CACHEDEV1_DATA/PlexUpdate
# 3. Download the script: sudo wget https://raw.githubusercontent.com/PatrickDanino/Samples/main/QNAP/plexUpdate.sh
# 4. Enable script execution: sudo chmod +x plexUpdate.sh
# 5. Add an entry to crontab to run /share/CE_CACHEDEV1_DATA/PlexUpdate/plexUpdate.sh
#    daily using QNAP wiki instructions: https://wiki.qnap.com/wiki/Add_items_to_crontab
#

# Update the build architecture below as needed.
# See See https://plex.tv/api/downloads/5.json for the most recent list

# Valid values include:
#     linux-x86_64 (Intel/AMD 64-bit QTS-4.3 and newer)
#     linux-aarch64 (ARMv8 TS-x28, and TS-x32 Series)
#     linux-armv7hf (ARMv7 TS-x31, and TS-x31U Series)
#     linux-armv7neon (ARMv7 TS-x31+, TS-x31P, TS-x31P2, TS-x31X, and TS-x31XU Series)
PLEX_BUILD=linux-x86_64

# You can store this script in the folder below.
# The folder path can be changed so long as it is a valid location with > 300MB of space in order to download the Plex QPKG
# Note that /tmp and many other folders have strict quota limits or get cleared when rebooting
PLEX_UPDATE_FOLDER=/share/CE_CACHEDEV1_DATA/PlexUpdate

PLEX_UPDATE_DOWNLOAD_FOLDER=${PLEX_UPDATE_FOLDER}/Download
PLEX_UPDATE_FILE=${PLEX_UPDATE_DOWNLOAD_FOLDER}/plex.json
PLEX_UPDATE_PACKAGE_FILE=${PLEX_UPDATE_DOWNLOAD_FOLDER}/PlexMediaServer.qpkg
PLEX_UPDATE_URL=https://plex.tv/api/downloads/5.json

LOG_FOLDER=${PLEX_UPDATE_FOLDER}/Logs
LOG_FILE=${LOG_FOLDER}/PlexUpdate.log
LOG_UPDATE_FILE=${LOG_FOLDER}/PlexUpdateVersion.log

# Script start
mkdir -p -m 777 ${LOG_FOLDER}
echo "$(date) - Plex Update" > ${LOG_FILE}

echo -e "\nClearing Download folder..." >> ${LOG_FILE}
rm -rf ${PLEX_UPDATE_DOWNLOAD_FOLDER} >> ${LOG_FILE}
mkdir -m 777 ${PLEX_UPDATE_DOWNLOAD_FOLDER} >> ${LOG_FILE}

# Check Plex QPKG installation status
echo -e "\nChecking for Plex QPKG..." >> ${LOG_FILE}

PLEX_FOLDER=$(readlink -f /etc/init.d/plex.sh)
PLEX_FOLDER=$(echo ${PLEX_FOLDER/\/plex.sh})

if [[ -z $PLEX_FOLDER ]]; then
  PLEX_PACKAGE_VERSION=
  echo -e "\tPlex Package will be installed" >> ${LOG_FILE}
else
  PLEX_PACKAGE_VERSION=$(${PLEX_FOLDER}/Plex\ Media\ Server --version)
  PLEX_PACKAGE_VERSION=$(echo ${PLEX_PACKAGE_VERSION/v})
  echo -e "\tPlex Media Server v${PLEX_PACKAGE_VERSION} found" >> ${LOG_FILE}
  
  if /sbin/qpkg_cli -s PlexMediaServer >> ${LOG_FILE}; then
    echo -e "\tPlex QPKG state valid" >> ${LOG_FILE}
  else
    echo -e "\tPlex QPKG state is invalid" >> ${LOG_FILE}
  fi

fi

# Download Plex Version
echo -e "\nFetching Plex update JSON..." >> ${LOG_FILE}
if wget -nv -O ${PLEX_UPDATE_FILE} ${PLEX_UPDATE_URL} >> ${LOG_FILE}; then
  echo -e "\tPlex update JSON downloaded" >> ${LOG_FILE}
else
  echo -e "\tPlex update JSON download failed" >> ${LOG_FILE}
fi 

# Get latest Plex version and URL
echo -e "\nFinding Plex update version and url for ${PLEX_BUILD}..." >> ${LOG_FILE}
PLEX_UPDATE_PACKAGE_VERSION=$(jq ".nas.QNAP.version" ${PLEX_UPDATE_FILE})
PLEX_UPDATE_PACKAGE_VERSION=$(echo $PLEX_UPDATE_PACKAGE_VERSION | tr -d '\"')

PLEX_UPDATE_PACKAGE_URL=$(jq ".nas.QNAP.releases[] | select(.build | contains(\"${PLEX_BUILD}\")) | .url" ${PLEX_UPDATE_FILE})
PLEX_UPDATE_PACKAGE_URL=$(echo $PLEX_UPDATE_PACKAGE_URL | tr -d '\"')

echo -e "\tPlex update package version: v${PLEX_UPDATE_PACKAGE_VERSION}" >> ${LOG_FILE}
echo -e "\tPlex update package url: ${PLEX_UPDATE_PACKAGE_URL}" >> ${LOG_FILE}

echo -e "\nChecking if an update is needed..." >> ${LOG_FILE}

if ! [[ ${PLEX_UPDATE_PACKAGE_VERSION} == ${PLEX_PACKAGE_VERSION} ]]; then
  echo -e "\tUpdate from v${PLEX_PACKAGE_VERSION} to v${PLEX_UPDATE_PACKAGE_VERSION} is needed" >> ${LOG_FILE}

  echo -e "\nDownloading update package..." >> ${LOG_FILE}
  if wget -nv -O ${PLEX_UPDATE_PACKAGE_FILE} ${PLEX_UPDATE_PACKAGE_URL} >> ${LOG_FILE}; then
    echo -e "\tDownloaded update package" >> ${LOG_FILE}
    
    echo -e "\nInstalling package..." >> ${LOG_FILE}
    sh ${PLEX_UPDATE_PACKAGE_FILE} >> ${LOG_FILE}
 
    echo -e "${PLEX_UPDATE_PACKAGE_VERSION}" > ${LOG_UPDATE_FILE}
    echo -e "$(date)" >> ${LOG_UPDATE_FILE}
    
  else
    echo -e "\tDownloading of update packaged failed" >> ${LOG_FILE}
  fi
 
else
  echo -e "\tUpdate to v${PLEX_PACKAGE_VERSION} not needed." >> ${LOG_FILE}
fi

echo -e "\n$(date) - Done." >> ${LOG_FILE}
