#!/bin/bash


# COLORS
NORMAL="\e[39m"
WHITE="\e[37m"
GREEN="\e[32m"

BOLD_TXT=$(tput bold)
NORMAL_TXT=$(tput sgr0)

function get_timezone {
	if [[ -f /etc/timezone ]]; then
		OLSONTZ=`cat /etc/timezone`
	elif [ -h /etc/localtime ]; then
		OLSONTZ=`readlink /etc/localtime | sed "s/\/usr\/share\/zoneinfo\///"`
	else
		checksum=`md5sum /etc/localtime | cut -d' ' -f1`
		OLSONTZ=`find /usr/share/zoneinfo/ -type f -exec md5sum {} \; | grep "^$checksum" | sed "s/.*\/usr\/share\/zoneinfo\///" | head -n 1`
	fi
	
	echo $OLSONTZ
}

echo $OLSONTZ
echo -e "${BOLD_TXT}This program will guide you to create a simple xml config file\nfor Ghoghnoos distro build system.\n\nhttps://github.com/mjahmadi/ghoghnoos-builder/\n\n${NORMAL_TXT}"

read -p "Project name [ghoghnoos]: " PROJECT__NAME
PROJECT__NAME=${PROJECT__NAME:-Ghoghnoos}

read -p "Project version [0.0.1]: " PROJECT__VERSION
PROJECT__VERSION=${PROJECT__VERSION:-0.0.1}

read -p "Project codename: " PROJECT__CODENAME

read -p "Project family [GNU/LINUX]: " PROJECT__FAMILY
PROJECT__FAMILY=${PROJECT__FAMILY:-GNU/LINUX}

read -p "Project type [live]: " PROJECT__TYPE
PROJECT__TYPE=${PROJECT__TYPE:-live}

read -p "Project architecture [$(uname -m)]: " PROJECT__ARCH
PROJECT__ARCH=${PROJECT__ARCH:-$(uname -m)}

read -p "Project vendor [Ghoghnoos Development Team]: " PROJECT__VENDOR
PROJECT__VENDOR=${PROJECT__VENDOR:-"Ghoghnoos Development Team"}

read -p "System hostname [$PROJECT__NAME-$PROJECT__ARCH]: " PROJECT__HOSTNAME
PROJECT__HOSTNAME=${PROJECT__HOSTNAME:-$PROJECT__NAME-$PROJECT__ARCH}

read -p "System timezone [$(get_timezone)]: " PROJECT__TIMEZONE
PROJECT__TIMEZONE=${PROJECT__TIMEZONE:-$(get_timezone)}

read -p "System init [systemd]: " PROJECT__CONTROLLER
PROJECT__CONTROLLER=${PROJECT__CONTROLLER:-systemd}

read -p "Default root password [root]: " PROJECT__ROOTPASWD
PROJECT__ROOTPASWD=${PROJECT__ROOTPASWD:-root}

read -p "Is system self constructor [Yes/no]: " PROJECT__CONSTRUCTOR
PROJECT__CONSTRUCTOR=${PROJECT__CONSTRUCTOR:-yes}

read -p "ISO directory [$(dirname $(pwd))/iso]: " PROJECT__ISODIR
PROJECT__ISODIR=${PROJECT__ISODIR:-"$(dirname $(pwd))/iso"}

read -p "Project license [GPL-3.0]: " PROJECT__LICENSE
PROJECT__LICENSE=${PROJECT__LICENSE:-GPL-3.0}

echo 
read -p "Where to save the new config file [$(pwd)]: " PROJECT__PATH
PROJECT__PATH=${PROJECT__PATH:-$(pwd)}

filename="config"
ext="xml"
if [[ -e "$PROJECT__PATH/$filename.$ext" ]] ; then
    i=0
    while [[ -e $filename-$i.$ext ]] ; do
        let i++
    done
    filename=$filename-$i
fi
filepath=$PROJECT__PATH/$filename.$ext

echo -e "<?xml version=\"1.0\"?>

<config id=\"01\" timezone=\"$(get_timezone)\" date=\"$(date)\" comment=\"\">
	
	<project>
		<name>$PROJECT__NAME</name>
		<version>$PROJECT__VERSION</version>
		<codename>$PROJECT__CODENAME</codename>
		<family>$PROJECT__FAMILY</family>
		<type>$PROJECT__TYPE</type>
		<arch>$PROJECT__ARCH</arch>
		<vendor>$PROJECT__VENDOR</vendor>
	</project>
	
	<system>
		<controller>$PROJECT__CONTROLLER</controller>
		<password hash=\"md5\">$PROJECT__ROOTPASWD</password>
		<hostname>$PROJECT__NAME-$PROJECT__ARCH</hostname>
		<timezone>$PROJECT__TIMEZONE</timezone>
		<constructor>$PROJECT__CONSTRUCTOR</constructor>
	</system>
	
	<isodir>$PROJECT__ISODIR/iso</isodir>
	<license>$PROJECT__LICENSE</license>
	
	<globals>
		<!-- All your global variables/functions/calls goes here -->
		export LC_ALL=POSIX
	</globals>
	
</config>
" > $filepath

echo -e "\nFile created in\n  ${GREEN}$filepath${NORMAL}\n"

