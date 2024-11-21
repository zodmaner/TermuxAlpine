#!/data/data/com.termux/files/usr/bin/bash -e
# Copyright ©2019 by Hax4Us. All rights reserved.
#
# Email : lkpandey950@gmail.com
################################################################################

ALPINE_PROOT=${HOME}/.local/share/proot/alpine

addprofile()
{
	cat > ${ALPINE_PROOT}/etc/profile <<- EOM
	export CHARSET=UTF-8
	export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
	export PAGER=less
	export PS1='[\u@\h \W]\\$ '
	umask 022
	for script in /etc/profile.d/*.sh ; do
	if [ -r \$script ] ; then
	. \$script
	fi
	done
	EOM
}

addmotd() {
	cat > ${ALPINE_PROOT}/etc/profile.d/motd.sh  <<- EOM
	printf "\n\033[1;34mWelcome to Alpine Linux in Termux!  Enjoy!\033[0m\033[1;34m
	Chat:    \033[0m\033[mhttps://gitter.im/termux/termux/\033[0m\033[1;34m
		Help:    \033[0m\033[34minfo <query> \033[0m\033[mand \033[0m\033[34mman <query> \033[0m\033[1;34m
			Portal:  \033[0m\033[mhttps://wiki.termux.com/wiki/Community\033[0m\033[1;34m

		Install a package: \033[0m\033[34mapk add <package>\033[0m\033[1;34m
			More  information: \033[0m\033[34mapk --help\033[0m\033[1;34m
				Search   packages: \033[0m\033[34mapk search <query>\033[0m\033[1;34m
					Upgrade  packages: \033[0m\033[34mapk upgrade \n\033[0m \n"
						EOM
}

updrepos() {
	cp ${ALPINE_PROOT}/etc/apk/repositories ${ALPINE_PROOT}/etc/apk/repositories.bak
	cat > ${ALPINE_PROOT}/etc/apk/repositories <<- EOM
	http://dl-cdn.alpinelinux.org/alpine/latest-stable/main/
	http://dl-cdn.alpinelinux.org/alpine/latest-stable/community/
	http://dl-cdn.alpinelinux.org/alpine/edge/testing/
	EOM
}

# thnx to @j16180339887 for DNS picker 
addresolvconf ()
{
	printf "nameserver 8.8.8.8\nnameserver 8.8.4.4" > ${ALPINE_PROOT}/etc/resolv.conf
}

finaltouchup()
{    
    android=$(getprop ro.build.version.release)

    addprofile

    if [ "${1-}" = "--add-motd" ]; then
	    addmotd
    fi

    if [ ${android%%.*} -ge 8 ]; then
	    addresolvconf
    fi

    updrepos
}

set -eux

# colors

red='\033[1;31m'
yellow='\033[1;33m'
blue='\033[1;34m'
reset='\033[0m'

# Destination Path

DESTINATION=${HOME}/.local/share/proot/alpine
LOGIN_FILE=${HOME}/.local/bin/proot-login-alpine

CHOICE=""
if [ -d ${DESTINATION} ]; then
    printf "${red}[!] ${yellow}Alpine is already installed\nDo you want to reinstall ? (type \"y\" for yes or \"n\" for no) :${reset} "
    read CHOICE
    if [ "${CHOICE}" = "y" ]; then
        rm -rf ${DESTINATION}
    elif [ "${CHOICE}" = "n" ]; then
        exit 1
    else
        printf "${red}[!] Wrong input${reset}"
        exit 1
    fi

fi

mkdir -p ${DESTINATION}
cd ${DESTINATION}

# Utility function for Unknown Arch

unknownarch() {
    printf "$red"
    echo "[*] Unknown Architecture :("
    printf "$reset"
    exit 1
}

# Utility function for detect system

checksysinfo() {
    printf "$blue [*] Checking host architecture ..."
    case $(getprop ro.product.cpu.abi) in
        arm64-v8a)
            SETARCH=aarch64
            ;;
        armeabi|armeabi-v7a)
            SETARCH=armhf
            ;;
        x86|i686)
            SETARCH=x86
            ;;
        x86_64)
            SETARCH=x86_64
            ;;
        *)
            unknownarch
            ;;
    esac
}

# Check if required packages are present

checkdeps() {
    printf "${blue}\n"
    echo " [*] Updating apt cache..."
    apt update -y &> /dev/null
    echo " [*] Checking for all required tools..."

    for i in proot bsdtar curl; do
        if [ -e ${PREFIX}/bin/$i ]; then
            echo " • $i is OK"
        else
            echo "Installing ${i}..."
            apt install -y $i || {
                printf "$red"
                echo " ERROR: check your internet connection or apt\n Exiting..."
                printf "$reset"
                exit 1
            }
        fi
    done
}

# URLs of all possibls architectures

seturl() {
    ALPINE_VER=$(curl -s http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/$SETARCH/latest-releases.yaml | grep -m 1 -o version.* | sed -e 's/[^0-9.]*//g' -e 's/-$//')
    if [ -z "$ALPINE_VER" ] ; then
        exit 1
    fi
    ALPINE_URL="http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/$SETARCH/alpine-minirootfs-$ALPINE_VER-$SETARCH.tar.gz"
}

# Utility function to get tar file

gettarfile() {
    printf "$blue [*] Getting tar file...$reset\n\n"
    seturl $SETARCH
    curl --progress-bar -L --fail --retry 4 -O "$ALPINE_URL"
    ROOTFS="alpine-minirootfs-$ALPINE_VER-$SETARCH.tar.gz"
}

# Utility function to get SHA

getsha() {
    printf "\n${blue} [*] Getting SHA ... $reset\n\n"
    curl --progress-bar -L --fail --retry 4 -O "${ALPINE_URL}.sha256"
}

# Utility function to check integrity

checkintegrity() {
    printf "\n${blue} [*] Checking integrity of file...\n"
    echo " [*] The script will immediately terminate in case of integrity failure"
    printf ' '
    sha256sum -c ${ROOTFS}.sha256 || {
        printf "$red Sorry :( to say your downloaded linux file was corrupted or half downloaded, but don't worry, just rerun my script\n${reset}"
        exit 1
    }
}

# Utility function to extract tar file

extract() {
    printf "$blue [*] Extracting... $reset\n\n"
    proot --link2symlink -0 bsdtar -xpf ${ROOTFS} 2> /dev/null || :
}

# Utility function for login file

createloginfile() {
    mkdir -p ${HOME}/.local/bin
    cat > ${LOGIN_FILE} <<-EOF
#!/data/data/com.termux/files/usr/bin/bash -e
unset LD_PRELOAD

EOF

    # thnx to @j16180339887 for DNS picker
    if [ $(getprop ro.build.version.release) ]
    then
        cat >> ${LOGIN_FILE} <<-EOF
[ \$(command -v getprop) ] && getprop | sed -n -e 's/^\[net\.dns.\]: \[\(.*\)\]/\1/p' | sed '/^\s*$/d' | sed 's/^/nameserver /' > \${HOME}/.local/share/proot/termux/etc/resolv.conf

EOF
    fi

    cat >> ${LOGIN_FILE} <<-EOF
exec proot --link2symlink -0 -r \${HOME}/.local/share/proot/alpine/ -b /dev/ -b /sys/ -b /proc/ -b /sdcard -b /storage -b \$HOME -w /root /usr/bin/env TMPDIR=/tmp HOME=/root PREFIX=/usr SHELL=/bin/sh TERM="\$TERM" LANG=\$LANG PATH=/bin:/usr/bin:/sbin:/usr/sbin /bin/sh --login
EOF

    chmod 700 ${LOGIN_FILE}

    cat > ${HOME}/.bashrc <<-EOF

export PATH="$PATH:/${HOME}/.local/bin"
EOF

    export PATH="$PATH:/${HOME}/.local/bin"
}

remove_installation_files() {
    rm ${DESTINATION}/${ROOTFS}
    rm ${DESTINATION}/${ROOTFS}.sha256
}

# Utility function to touchup Alpine

finalwork() {
    if [ "${MOTD}" = "ON" ]; then
        finaltouchup --add-motd
    else
        finaltouchup
    fi
}

# Utility function for cleanup

cleanup() {
    if [ -d ${DESTINATION} ]; then
        rm -rf ${DESTINATION}
    else
        printf "$red not installed so not removed${reset}\n"
        exit
    fi
    if [ -e ${LOGIN_FILE} ]; then
        rm ${LOGIN_FILE}
        printf "$yellow uninstalled :) ${reset}\n"
        exit
    else
        printf "$red not installed so not removed${reset}\n"
    fi
}

printline() {
    printf "${blue}\n"
    echo " #------------------------------------------#"
}

usage() {
    printf "${yellow}\nUsage: ${green}bash TermuxAlpine.sh [option]\n${blue}  --uninstall		uninstall alpine\n  --add-motd		create motd file\n${reset}\n"
}

# Start

MOTD="OFF"
EXTRAARGS="default"
if [ ! -z "${1-}" ]
    then
    EXTRAARGS=$1
fi
if [ "$EXTRAARGS" = "--uninstall" ]; then
    cleanup
    exit 1
elif [ "$EXTRAARGS" = "--add-motd"  ]; then
    MOTD="ON"
elif [ $# -ge 1 ]
then
    usage
    exit 1
fi
printf "\n${yellow} You are going to install Alpine in termux ;) Cool\n press ENTER to continue\n"
read enter

checksysinfo
checkdeps
gettarfile
getsha
checkintegrity
extract
createloginfile
remove_installation_files


printf "$blue [*] Configuring Alpine For You ..."
finalwork
printline
printf "\n${yellow} Now you can enjoy a very small (just 1 MB!) Linux environment in your Termux :)\n Don't forget to star my work\n"
printline
printline
printf "\n${blue} [*] Email   :${yellow}    lkpandey950@gmail.com\n"
printf "$blue [*] Website :${yellow}    https://hax4us.com\n"
printf "$blue [*] YouTube :${yellow}    https://youtube.com/hax4us\n"
printline
printf "$red \n NOTE : $yellow use ${red}--uninstall${yellow} option for uninstall\n"
printline
printf "$reset"
