#!/data/data/com.termux/files/usr/bin/bash -e

# Licensed under GPLv3
# NetHunter Termux
# Author: revWhiteShadow (@revWhiteShadow on Telegram, @White9Shadow on GitHub)
# Credits: Kali Linux Source
# Support: @godTspeed on Telegram, @godspeedmode on Telegram
# Telegram Add List: https://t.me/addlist/g2eR29-lI4M1ZmVl
# If you use any part of this script, give proper credit.

VERSION=20250620
BASE_URL=https://kali.download/nethunter-images/current/rootfs
IMAGE_NAME=kali-nethunter-rootfs-nano-arm64.tar.xz
SHA_NAME=kali-nethunter-rootfs-nano-arm64.sha512sum
USERNAME=kali
CHROOT=/data/data/com.termux/files/home/kali-arm64-nano

# Colors
red='\033[1;31m'
green='\033[1;32m'
yellow='\033[1;33m'
blue='\033[1;34m'
light_cyan='\033[1;96m'
reset='\033[0m'

EXTRA_ARGS=""
if [[ ! -z $1 ]]; then
    EXTRA_ARGS=$1
    if [[ $EXTRA_ARGS != "--insecure" ]]; then
        EXTRA_ARGS=""
    fi
fi

function ask() {
    while true; do
        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi
        printf "${light_cyan}\n[?] "
        read -p "$1 [$prompt] " REPLY
        if [ -z "$REPLY" ]; then
            REPLY=$default
        fi
        printf "${reset}"
        case "$REPLY" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac
    done
}

function fix_apt_cache() {
    printf "${blue}[*] Fixing Termux apt cache and sources ...${reset}\n"
    rm -rf /data/data/com.termux/cache/apt/archives/partial
    mkdir -p /data/data/com.termux/cache/apt/archives/partial
    apt clean

    echo "deb https://packages.termux.dev/apt/termux-main stable main" > $PREFIX/etc/apt/sources.list
    if [ -d "$PREFIX/etc/apt/sources.list.d" ]; then
        for f in $PREFIX/etc/apt/sources.list.d/*.list; do
            echo "deb https://packages.termux.dev/apt/termux-main stable main" > "$f"
        done 2>/dev/null
    fi

    if [ ! -d ~/storage ]; then
        termux-setup-storage
    fi
}

function prepare_fs() {
    unset KEEP_CHROOT
    if [ -d ${CHROOT} ]; then
        if ask "Existing rootfs directory found. Delete and create a new one?" "N"; then
            rm -rf ${CHROOT}
        else
            KEEP_CHROOT=1
        fi
    fi
}

function cleanup() {
    if [ -f ${IMAGE_NAME} ]; then
        if ask "Delete downloaded rootfs file?" "N"; then
            if [ -f ${IMAGE_NAME} ]; then
                rm -f ${IMAGE_NAME}
            fi
            if [ -f $SHA_NAME ]; then
                rm -f $SHA_NAME
            fi
            if [ -f SHA256SUMS ]; then
                rm -f SHA256SUMS
            fi
        fi
    fi
}

function check_dependencies() {
    printf "${blue}\n[*] Checking package dependencies...${reset}\n"
    apt update || apt update --fix-missing
    apt upgrade -y || apt upgrade -y --fix-missing

    for i in proot tar axel curl; do
        if [ -e $PREFIX/bin/$i ]; then
            echo "  $i is OK"
        else
            printf "Installing ${i}...\n"
            apt install -y $i --fix-missing || {
                printf "${red}ERROR: Failed to install packages.\n Exiting.\n${reset}"
                exit 1
            }
        fi
    done
}

function get_rootfs() {
    ROOTFS_URL=${BASE_URL}/${IMAGE_NAME}
    unset KEEP_IMAGE
    if [ -f ${IMAGE_NAME} ]; then
        if ask "Existing image file found. Delete and download a new one?" "N"; then
            rm -f ${IMAGE_NAME}
        else
            printf "${yellow}[!] Using existing rootfs archive${reset}\n"
            KEEP_IMAGE=1
            return
        fi
    fi
    printf "${blue}[*] Downloading rootfs...${reset}\n\n"
    axel ${EXTRA_ARGS} --alternate --num-connections=1 "${ROOTFS_URL}" || {
        printf "${red}ERROR: Failed to download rootfs.\nCheck your internet connection or the NetHunter image URL.\n${reset}"
        exit 1
    }
}

function get_sha() {
    if [ -z $KEEP_IMAGE ]; then
        printf "\n${blue}[*] Getting SHA file ... ${reset}\n\n"
        if [ -f $SHA_NAME ]; then
            rm -f $SHA_NAME
        fi
        # Try sha512sum file first
        axel ${EXTRA_ARGS} --alternate --num-connections=1 "${BASE_URL}/${SHA_NAME}" || {
            printf "${yellow}WARNING: $SHA_NAME not found, trying SHA256SUMS...${reset}\n"
            if [ -f SHA256SUMS ]; then
                rm -f SHA256SUMS
            fi
            axel ${EXTRA_ARGS} --alternate --num-connections=1 "${BASE_URL}/SHA256SUMS" || {
                printf "${yellow}WARNING: SHA256SUMS file not found, skipping verification.${reset}\n"
                SHA_NAME=""
            }
        }
    fi
}

function verify_sha() {
    if [ -z $KEEP_IMAGE ] && [ -f "$SHA_NAME" ]; then
        printf "\n${blue}[*] Verifying integrity of rootfs (SHA512)...${reset}\n\n"
        sha512sum -c $SHA_NAME || {
            printf "${red} Rootfs corrupted. Please run this installer again or download the file manually\n${reset}"
            exit 1
        }
    elif [ -z $KEEP_IMAGE ] && [ -f "SHA256SUMS" ]; then
        printf "\n${blue}[*] Verifying integrity of rootfs (SHA256)...${reset}\n\n"
        grep "$(basename $IMAGE_NAME)" SHA256SUMS > SHA256SUMS.single
        if [ -s SHA256SUMS.single ]; then
            sha256sum -c SHA256SUMS.single || {
                printf "${red} Rootfs corrupted. Please run this installer again or download the file manually\n${reset}"
                exit 1
            }
        else
            printf "${yellow}WARNING: SHA256 entry not found, skipping verification.${reset}\n"
        fi
    fi
}

function extract_rootfs() {
    if [ -z $KEEP_CHROOT ]; then
        printf "\n${blue}[*] Extracting rootfs... ${reset}\n\n"
        proot --link2symlink tar -xf $IMAGE_NAME -C /data/data/com.termux/files/home/ 2> /dev/null || {
            printf "${red}ERROR: Extraction failed. Check storage permissions!\n${reset}"
            exit 1
        }
    else
        printf "${yellow}[!] Using existing rootfs directory${reset}\n"
    fi
}

function create_launcher() {
    NH_LAUNCHER=${PREFIX}/bin/nethunter
    NH_SHORTCUT=${PREFIX}/bin/nh
    cat > $NH_LAUNCHER <<- EOF
#!/data/data/com.termux/files/usr/bin/bash -e
cd \${HOME}
unset LD_PRELOAD
if [ ! -f $CHROOT/root/.version ]; then
    touch $CHROOT/root/.version
fi

user="$USERNAME"
home="/home/\$user"
start="sudo -u kali /bin/bash"

if grep -q "kali" ${CHROOT}/etc/passwd; then
    KALIUSR="1";
else
    KALIUSR="0";
fi
if [[ \$KALIUSR == "0" || ("\$#" != "0" && ("\$1" == "-r" || "\$1" == "-R")) ]];then
    user="root"
    home="/\$user"
    start="/bin/bash --login"
    if [[ "\$#" != "0" && ("\$1" == "-r" || "\$1" == "-R") ]];then
        shift
    fi
fi

cmdline="proot \\
        --link2symlink \\
        -0 \\
        -r $CHROOT \\
        -b /dev \\
        -b /proc \\
        -b $CHROOT\$home:/dev/shm \\
        -w \$home \\
           /usr/bin/env -i \\
           HOME=\$home \\
           PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin \\
           TERM=\$TERM \\
           LANG=C.UTF-8 \\
           \$start"

cmd="\$@"
if [ "\$#" == "0" ];then
    exec \$cmdline
else
    \$cmdline -c "\$cmd"
fi
EOF

    chmod 700 $NH_LAUNCHER
    if [ -L ${NH_SHORTCUT} ]; then
        rm -f ${NH_SHORTCUT}
    fi
    if [ ! -f ${NH_SHORTCUT} ]; then
        ln -s ${NH_LAUNCHER} ${NH_SHORTCUT} >/dev/null
    fi
}

function fix_profile_bash() {
    if [ -f ${CHROOT}/root/.bash_profile ]; then
        sed -i '/if/,/fi/d' "${CHROOT}/root/.bash_profile"
    fi
}

function fix_sudo() {
    chmod +s $CHROOT/usr/bin/sudo
    chmod +s $CHROOT/usr/bin/su
    echo "kali    ALL=(ALL:ALL) ALL" > $CHROOT/etc/sudoers.d/kali
    echo "Set disable_coredump false" > $CHROOT/etc/sudo.conf
}

function print_banner() {
    clear
    printf "${blue}##################################################\n"
    printf "${blue}##                                              ##\n"
    printf "${blue}##  88      a8P         db        88        88  ##\n"
    printf "${blue}##  88    .88'         d88b       88        88  ##\n"
    printf "${blue}##  88   88'          d8''8b      88        88  ##\n"
    printf "${blue}##  88 d88           d8'  '8b     88        88  ##\n"
    printf "${blue}##  8888'88.        d8YaaaaY8b    88        88  ##\n"
    printf "${blue}##  88P   Y8b      d8''''''''8b   88        88  ##\n"
    printf "${blue}##  88     '88.   d8'        '8b  88        88  ##\n"
    printf "${blue}##  88       Y8b d8'          '8b 888888888 88  ##\n"
    printf "${blue}##                                              ##\n"
    printf "${blue}####  ############# NetHunter ####################${reset}\n\n"
}

##################################
##              Main            ##
##################################

cd $HOME
print_banner
fix_apt_cache
check_dependencies
prepare_fs
get_rootfs
get_sha
verify_sha
extract_rootfs
create_launcher
cleanup

printf "\n${blue}[*] Configuring NetHunter for Termux ...\n"
fix_profile_bash
fix_sudo

print_banner
printf "${green}[=] Kali NetHunter for Termux installed successfully${reset}\n\n"
printf "${green}[+] To start Kali NetHunter, type:${reset}\n"
printf "${green}[+] nethunter             # To start NetHunter CLI${reset}\n"
printf "${green}[+] nethunter -r          # To run NetHunter as root${reset}\n"
printf "${green}[+] nh                    # Shortcut for nethunter${reset}\n\n"
