#!/bin/bash
set -e
if [ `which debootstrap` = "" ];then
echo "Need to install debootstrap!"
exit
fi

if [ `which systemd-nspawn` = "" ];then
echo "Need to install systemd-container!"
exit
fi
if [ "$2" = "" ];then
echo "Usage: $0 ARCHITECTURE CODENAME"
exit
fi

sudo cp  /usr/share/debootstrap/scripts/sid /usr/share/debootstrap/scripts/crimson -v
sudo cp  /usr/share/debootstrap/scripts/sid /usr/share/debootstrap/scripts/beige -v

CODENAME=$2

# Set distroname and components based on codename
if [ "$CODENAME" = "beige" ] || [ "$CODENAME" = "crimson" ]; then
    DISTRONAME="deepin/beige"
    COMPONENTS="main,community,commercial"
    GPG_CHECK="--no-check-gpg"
else
    DISTRONAME="debian"
    COMPONENTS="main,contrib,non-free,non-free-firmware"
    GPG_CHECK=""
fi

if [ "$1" = "amd64" ] || [ "$1" = "x86_64" ];then
ARCH="amd64"
ARCH_ANOTHERWAY="x64"
cd "`dirname $0`"
sudo debootstrap $GPG_CHECK --components=$COMPONENTS --include=libnotify-bin,apt-utils,bash-completion,bc,curl,dialog,diffutils,findutils,less,libnss-myhostname,libvte-common,lsof,ncurses-base,passwd,pinentry-curses,procps,sudo,time,util-linux,wget,libegl1,libvulkan1,mesa-vulkan-drivers,locales,libglib2.0-bin --arch=${ARCH} $2 ./ace-env https://mirrors.cernet.edu.cn/${DISTRONAME}/

elif [ "$1" = "arm64" ] || [ "$1" = "arm" ]|| [ "$1" = "aarch64" ];then
ARCH="arm64"
ARCH_ANOTHERWAY="arm64"
cd "`dirname $0`"
sudo debootstrap $GPG_CHECK --components=$COMPONENTS --include=libnotify-bin,apt-utils,bash-completion,bc,curl,dialog,diffutils,findutils,less,libnss-myhostname,libvte-common,lsof,ncurses-base,passwd,pinentry-curses,procps,sudo,time,util-linux,wget,libegl1,libvulkan1,mesa-vulkan-drivers,locales,libglib2.0-bin --arch=${ARCH} $2 ./ace-env https://mirrors.cernet.edu.cn/${DISTRONAME}/

elif [ "$1" = "loong64" ] || [ "$1" = "loongarch64" ];then
    if [ "$CODENAME" = "beige" ] || [ "$CODENAME" = "crimson" ]; then
        ARCH="loong64"
        ARCH_ANOTHERWAY="loongarch64"
        cd "`dirname $0`"
        sudo debootstrap $GPG_CHECK --components=$COMPONENTS --include=libnotify-bin,apt-utils,bash-completion,bc,curl,dialog,diffutils,findutils,less,libnss-myhostname,libvte-common,lsof,ncurses-base,passwd,pinentry-curses,procps,sudo,time,util-linux,wget,libegl1,libvulkan1,mesa-vulkan-drivers,locales,libglib2.0-bin --arch=${ARCH} $2 ./ace-env https://mirrors.cernet.edu.cn/${DISTRONAME}/
    else
        echo "LoongArch64 is only supported on Deepin (beige/crimson)"
        exit 1
    fi
fi

sudo rm -rf ace-env/var/cache/apt/archives/*.deb
sudo rm -vfr ace-env/dev/*
sudo tar -I 'xz -T0' -cvf ace-env.tar.xz ace-env/*
sudo rm -rf ace-env