#!/bin/bash


NORMAL="\e[39m"
WHITE="\e[37m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
RED="\e[31m"

exec__start_time=$(date +%s)

set -e
set +h

if [[ $(id -u) == 0 ]]; then
	echo -e "${RED}ERROR: Sorry, user root is not allowed to execute '$0'.${NORMAL}"
	exit -1
fi

if [[ -z $1 ]]; then
	echo -e "${RED}ERROR: Build descriptor file missing.${NORMAL}"
	exit -1
elif [[ ! -s $1 ]]; then
	echo -e "${RED}ERROR: Build descriptor file does not exists.${NORMAL}"
	exit -1
fi

XML_FILE=$1
XML_STRING=$(cat $XML_FILE)

function xml_get_val
{
    echo "$XML_STRING" | xmlstarlet sel -t -v "$1" | xmlstarlet unesc
}

#export MAKEFLAGS="-j $(grep ^processor /proc/cpuinfo | wc -l)"
export CPUS="-j $(grep ^processor /proc/cpuinfo | wc -l)"

export PROJECT__NAME=$(xml_get_val "/build/@name")
export PROJECT__TYPE=$(xml_get_val "/build/@type")
export PROJECT__ARCH=$(xml_get_val "/build/@arch")
export PROJECT__VERSION=$(xml_get_val "/build/@version")
export PROJECT__CODENAME=$(xml_get_val "/build/@codename")

export PROJECT__VENDOR="Minux"
export PROJECT__AUTHOR_NAME="M.J.Ahmadi"
export PROJECT__AUTHOR_EMAIL="mohammad.j.ahmadi@gmail.com"
export PROJECT__WEBSITE="https://github.com/mjahmadi/minux"

export PROJECT__ISONAME="$PROJECT__NAME-$PROJECT__VERSION-$PROJECT__TYPE-$PROJECT__ARCH.iso"

export PROJECT__CUR=$(pwd)
export PROJECT__DIR="$PROJECT__CUR/$PROJECT__TYPE-$PROJECT__ARCH"
export PROJECT__PKG="$PROJECT__CUR/packages"
export PROJECT__BLD="$PROJECT__DIR/build"
export PROJECT__RFS="$PROJECT__DIR/rootfs"

if [[ -z $PROJECT__NAME || -z $PROJECT__TYPE || -z $PROJECT__ARCH || -z $PROJECT__VERSION ]]; then
	echo -e "${RED}ERROR: Project 'name/type/arch/version' is missing.${NORMAL}"
	exit -1
fi

if [[ $PROJECT__ARCH != "x86" && $PROJECT__ARCH != $(uname -m) ]]; then
	echo -e "${RED}ERROR: Unsupported build arch.${NORMAL}"
	exit -1
fi

#set +e
#echo "root's password: "
#read -rs HOST_ROOT_PASS
#sudo -k
#echo "$HOST_ROOT_PASS" | sudo -S echo "hello" &> /dev/null
#if ! [[ "$(sudo -n echo hello 2>&1)" == "hello" ]]; then
#    echo -e "${RED}ERROR: Incorrect password was entered.${NORMAL}"
#    exit -1
#else
#    echo -e "${GREEN}OK!${NORMAL}"
#fi
#set -e

echo -e "\nBuilding $PROJECT__NAME-$PROJECT__ARCH-$PROJECT__TYPE ver: $PROJECT__VERSION\n"

mkdir -vp $PROJECT__DIR
mkdir -vp $PROJECT__PKG
mkdir -vp $PROJECT__BLD
mkdir -vp $PROJECT__RFS

if [[ -n $2 ]]; then
    phase_begin_from=$2
else
    phase_begin_from=1
fi

if [[ -n $3 ]]; then
    entry_begin_from=$3
else
    entry_begin_from=1
fi

# BUILD >> PHASE
phase_count=$(xml_get_val "count(/build/phase)")
for phase in `seq $phase_begin_from $phase_count`; do

    echo -e "\nPhase --> '$phase'"
    
    # BUILD >> PHASE >> ENTRY
    entry_count=$(xml_get_val "count(/build/phase[$phase]/entry)")
    for entry in `seq $entry_begin_from $entry_count`; do
    
        echo -e "Entry ----> '$entry'\n"
        
        # BUILD >> PHASE >> ENTRY >> ACTION [TYPE=BEFORE]
        entry_action_count=$(xml_get_val "count(/build/phase[$phase]/entry[$entry]/action[@when='before'])")
        for action in `seq 1 $entry_action_count`; do
            # BUILD >> PHASE >> ENTRY >> ACTION [TYPE=BEFORE] >> LINE
        	entry_action_line_count=$(xml_get_val "count(/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/line)")
        	for line in `seq 1 $entry_action_line_count`; do
		        sudo=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/line[$line]/@sudo")
		        verbos=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/line[$line]/@verbos")
		        strap=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/line[$line]/@strap")
		        
		        command=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/line[$line]")
		        
		        if [[ $verbos == 'yes' ]]; then
		            echo -e "$command"
		        fi
		        
				if [[ $sudo == 'yes' && -n $HOST_ROOT_PASS ]]; then
					eval "echo $HOST_ROOT_PASS | sudo -S $command"
				else
					eval "$command"
				fi
        	done
        done
        
        # BUILD >> PHASE >> ENTRY [TYPE=PACKAGE/SRC]
        type=$(xml_get_val "/build/phase[$phase]/entry[$entry]/@type")
        cdto=$(xml_get_val "/build/phase[$phase]/entry[$entry]/@cdto")
        download=$(xml_get_val "/build/phase[$phase]/entry[$entry]/@download")
        extract=$(xml_get_val "/build/phase[$phase]/entry[$entry]/@extract")
        link=$(xml_get_val "/build/phase[$phase]/entry[$entry]/link")
        filename=$(xml_get_val "/build/phase[$phase]/entry[$entry]/filename")
        directory=$(xml_get_val "/build/phase[$phase]/entry[$entry]/directory")
	    checksum1=$(xml_get_val "/build/phase[$phase]/entry[$entry]/checksum [@type='md5']")
        checksum_type=$(xml_get_val "/build/phase[$phase]/entry[$entry]/checksum/@type")
        
        if [[ $download == 'yes' ]]; then
            echo -e "\nDownloading '$filename'"
            
            wget --continue $link --directory-prefix="$PROJECT__PKG"
		    checksum2=($(md5sum $PROJECT__PKG/$filename))
		    
		    if [[ $checksum1 != $checksum2 ]]; then
                echo -e "${RED}ERROR: Checksum[$checksum_type] validation failed.\n '$checksum1' != '$checksum2'${NORMAL}"
                exit -1
		    fi
        fi
        
		if [[ $extract == 'yes' ]]; then
		    des_dir=$(tar -tf $PROJECT__PKG/$filename | head -n 1 | cut -f1)
			des_dir=$(IFS='/' read -r -a array <<< $des_dir && echo ${array[0]})
			des_dir=$(read -r -a array <<< $des_dir && echo ${array[0]})
			
			echo -e "\nExtracting '$filename'"
		
			rm -rf $PROJECT__BLD/$des_dir
		
			if [[ -n $directory ]]; then
				tar -xf $PROJECT__PKG/$filename -C $PROJECT__BLD/$des_dir
			else
				tar -xf $PROJECT__PKG/$filename -C $PROJECT__BLD
			fi
		fi
		
		if [[ $cdto == 'yes' ]]; then
			cd $PROJECT__BLD/$des_dir
		fi
        
        # BUILD >> PHASE >> ENTRY >> ACTION [TYPE=AFTER]
        entry_action_count=$(xml_get_val "count(/build/phase[$phase]/entry[$entry]/action[@when='after'])")
        for action in `seq 1 $entry_action_count`; do
            # BUILD >> PHASE >> ENTRY >> ACTION [TYPE=BEFORE] >> LINE
        	entry_action_line_count=$(xml_get_val "count(/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/line)")
        	for line in `seq 1 $entry_action_line_count`; do
		        sudo=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/line[$line]/@sudo")
		        verbos=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/line[$line]/@verbos")
		        strap=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/line[$line]/@strap")
		        
		        command=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/line[$line]")
		        
		        if [[ $verbos == 'yes' ]]; then
		            echo -e "$command"
		        fi
		        
				if [[ $sudo == 'yes' && -n $HOST_ROOT_PASS ]]; then
					eval "echo $HOST_ROOT_PASS | sudo -S $command"
				else
					eval "$command"
				fi
        	done
        done
        
    done
    
    entry_begin_from=1
    
done

exec__elapsed_time=$(echo "$(date +%s) - $exec__start_time" | bc)
echo -e "${GREEN}\nBuild time: $(($exec__elapsed_time / 60)) minute(s) and $(($exec__elapsed_time % 60)) second(s). ${NORMAL}\n"

