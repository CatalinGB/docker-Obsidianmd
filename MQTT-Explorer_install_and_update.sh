#!/bin/bash
set -e

#-----------------------------------------------------
# Variables
#-----------------------------------------------------
COLOR_RED=`tput setaf 1`
COLOR_GREEN=`tput setaf 2`
COLOR_YELLOW=`tput setaf 3`
COLOR_BLUE=`tput setaf 4`
COLOR_RESET=`tput sgr0`
SILENT=false
ALLOW_ROOT=false
SHOW_CHANGELOG=false
INCLUDE_PRE_RELEASE=false

print() {
    if [[ "${SILENT}" == false ]] ; then
        echo -e "$@"
    fi
}

showLogo() {
    print "${COLOR_BLUE}"
    print "MQTT explorer"
    print "Linux Installer and Updater"
    print "${COLOR_RESET}"
}

showHelp() {
    showLogo
    print "Available Arguments:"
    print "\t" "--help" "\t" "Show this help information" "\n"
    print "\t" "--allow-root" "\t" "Allow the install to be run as root"
    print "\t" "--changelog" "\t" "Show the changelog after installation"
    print "\t" "--force" "\t" "Always download the latest version"
    print "\t" "--silent" "\t" "Don't print any output"
    print "\t" "--prerelease" "\t" "Check for new Versions including Pre-Releases" 

    if [[ ! -z $1 ]]; then
        print "\n" "${COLOR_RED}ERROR: " "$*" "${COLOR_RESET}" "\n"
    else
        exit 0
    fi

}

#-----------------------------------------------------
# PARSE ARGUMENTS
#-----------------------------------------------------

optspec=":h-:"
while getopts "${optspec}" OPT; do
  [ "${OPT}" = " " ] && continue
  if [ "${OPT}" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi
  case "${OPT}" in
    h | help )     showHelp ;;
    allow-root )   ALLOW_ROOT=true ;;
    silent )       SILENT=true ;;
    force )        FORCE=true ;;
    changelog )    SHOW_CHANGELOG=true ;;
    prerelease )   INCLUDE_PRE_RELEASE=true ;;
    [^\?]* )       showHelp "Illegal option --${OPT}"; exit 2 ;;
    \? )           showHelp "Illegal option -${OPTARG}"; exit 2 ;;
  esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list

## Check and warn if running as root.
if [[ $EUID = 0 ]] && [[ "${ALLOW_ROOT}" != true ]]; then
    showHelp "It is not recommended (nor necessary) to run this script as root. To do so anyway, please use '--allow-root'"
    exit 1
fi

#-----------------------------------------------------
# START
#-----------------------------------------------------
showLogo

#-----------------------------------------------------
print "Checking architecture..."
## uname actually gives more information than needed, but it contains all architectures (hardware and software)
ARCHITECTURE=$(uname -m -p -i || echo "NO CHECK")

if [[ $ARCHITECTURE = "NO CHECK" ]] ; then
  print "${COLOR_YELLOW}WARNING: Can't get system architecture, skipping check${COLOR_RESET}"
elif [[ $ARCHITECTURE =~ .*aarch.*|.*arm.* ]] ; then
  showHelp "Arm systems are not officially supported by MQTT-Explorer, please search the forum (https://discourse.MQTT-Explorerapp.org/) for more information"
  exit 1
elif [[ $ARCHITECTURE =~ .*i386.*|.*i686.* ]] ; then
  showHelp "32-bit systems are not supported by MQTT-Explorer, please search the forum (https://discourse.MQTT-Explorerapp.org/) for more information"
  exit 1
fi

#-----------------------------------------------------
# Download MQTT-Explorer
#-----------------------------------------------------

# Get the latest version to download
if [[ "$INCLUDE_PRE_RELEASE" == true ]]; then
  RELEASE_VERSION=$(wget -qO - "https://api.github.com/repos/thomasnordquist/MQTT-Explorer/releases" | grep -Po '"tag_name": ?"v\K.*?(?=")' | head -1)
else
  RELEASE_VERSION=$(wget -qO - "https://api.github.com/repos/thomasnordquist/MQTT-Explorer/releases/latest" | grep -Po '"tag_name": ?"v\K.*?(?=")')
fi

# Check if it's in the latest version
if [[ -e ~/.MQTT-Explorer/VERSION ]] && [[ $(< ~/.MQTT-Explorer/VERSION) == "${RELEASE_VERSION}" ]]; then
    print "${COLOR_GREEN}You already have the latest version${COLOR_RESET} ${RELEASE_VERSION} ${COLOR_GREEN}installed.${COLOR_RESET}"
    ([[ "$FORCE" == true ]] && print "Forcing installation...") || exit 0
else
    [[ -e ~/.MQTT-Explorer/VERSION ]] && CURRENT_VERSION=$(< ~/.MQTT-Explorer/VERSION)
    print "The latest version is ${RELEASE_VERSION}, but you have ${CURRENT_VERSION:-no version} installed."
fi

#-----------------------------------------------------
print 'Downloading MQTT-Explorer...'
TEMP_DIR=$(mktemp -d)
#https://github.com/thomasnordquist/MQTT-Explorer/releases/download/0.0.0-0.4.0-beta1/MQTT-Explorer-0.4.0-beta1.AppImage
wget -qnv --show-progress -O ${TEMP_DIR}/MQTT-Explorer.AppImage https://github.com/thomasnordquist/MQTT-Explorer/releases/download/v${RELEASE_VERSION}/MQTT-Explorer-${RELEASE_VERSION}.AppImage
wget -qnv --show-progress -O ${TEMP_DIR}/MQTT-Explorer.png https://joplinapp.org/images/Icon512.png

#-----------------------------------------------------
print 'Installing MQTT-Explorer...'
# Delete previous version (in future versions MQTT-Explorer.desktop shouldn't exist)
rm -f ~/.MQTT-Explorer/*.AppImage ~/.local/share/applications/MQTT-Explorer.desktop ~/.MQTT-Explorer/VERSION

# Creates the folder where the binary will be stored
mkdir -p ~/.MQTT-Explorer/

# Download the latest version
mv ${TEMP_DIR}/MQTT-Explorer.AppImage ~/.MQTT-Explorer/MQTT-Explorer.AppImage

# Gives execution privileges
chmod +x ~/.MQTT-Explorer/MQTT-Explorer.AppImage

print "${COLOR_GREEN}OK${COLOR_RESET}"

#-----------------------------------------------------
print 'Installing icon...'
mkdir -p ~/.local/share/icons/hicolor/512x512/apps
mv ${TEMP_DIR}/MQTT-Explorer.png ~/.local/share/icons/hicolor/512x512/apps/MQTT-Explorer.png
print "${COLOR_GREEN}OK${COLOR_RESET}"

# Detect desktop environment
if [ "$XDG_CURRENT_DESKTOP" = "" ]
then
  DESKTOP=$(echo "${XDG_DATA_DIRS}" | sed 's/.*\(xfce\|kde\|gnome\).*/\1/')
else
  DESKTOP=$XDG_CURRENT_DESKTOP
fi
DESKTOP=${DESKTOP,,}  # convert to lower case

#-----------------------------------------------------
echo 'Create Desktop icon...'
if [[ $DESKTOP =~ .*gnome.*|.*kde.*|.*xfce.*|.*mate.*|.*lxqt.*|.*unity.*|.*x-cinnamon.*|.*deepin.*|.*pantheon.*|.*lxde.* ]]
then
    : "${TMPDIR:=$TEMP_DIR}"
    # This command extracts to squashfs-root by default and can't be changed...
    # So we run it in the tmp directory and clean up after ourselves
    (cd $TMPDIR && ~/.MQTT-Explorer/MQTT-Explorer.AppImage --appimage-extract MQTT-Explorer.desktop &> /dev/null)
    APPIMAGE_VERSION=$(grep "^X-AppImage-Version=" $TMPDIR/squashfs-root/MQTT-Explorer.desktop | head -n 1 | cut -d "=" -f 2)
    rm -rf $TMPDIR/squashfs-root
    # Only delete the desktop file if it will be replaced
    rm -f ~/.local/share/applications/appimagekit-MQTT-Explorer.desktop

    # On some systems this directory doesn't exist by default
    mkdir -p ~/.local/share/applications
    echo -e "[Desktop Entry]\nEncoding=UTF-8\nName=MQTT-Explorer\nComment=MQTT-Explorer for Desktop\nExec=${HOME}/.MQTT-Explorer/MQTT-Explorer.AppImage\nIcon=MQTT-Explorer\nStartupWMClass=MQTT-Explorer\nType=Application\nCategories=Office;\n#${APPIMAGE_VERSION}" >> ~/.local/share/applications/appimagekit-MQTT-Explorer.desktop
    # Update application icons
    [[ `command -v update-desktop-database` ]] && update-desktop-database ~/.local/share/applications && update-desktop-database ~/.local/share/icons
    print "${COLOR_GREEN}OK${COLOR_RESET}"
else
    print "${COLOR_RED}NOT DONE, unknown desktop '${DESKTOP}'${COLOR_RESET}"
fi

#-----------------------------------------------------
# FINISH INSTALLATION
#-----------------------------------------------------

# Informs the user that it has been installed
print "${COLOR_GREEN}MQTT-Explorer version${COLOR_RESET} ${RELEASE_VERSION} ${COLOR_GREEN}installed.${COLOR_RESET}"

# Record version
echo $RELEASE_VERSION > ~/.MQTT-Explorer/VERSION

#-----------------------------------------------------
if [[ "$SHOW_CHANGELOG" == true ]]; then
    NOTES=$(wget -qO - https://api.github.com/repos/thomasnordquist/MQTT-Explorer/releases/latest | grep -Po '"body": "\K.*(?=")')
    print "${COLOR_BLUE}Changelog:${COLOR_RESET}\n${NOTES}"
fi

#-----------------------------------------------------
print "Cleaning up..."
rm -rf $TEMP_DIR
print "${COLOR_GREEN}OK${COLOR_RESET}"
