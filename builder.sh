set -e
set +h

umask 022

export USERNAME=$USER
export USERGROUP=$(id -g -n $username)

# COLORS
NORMAL="\e[39m"
WHITE="\e[37m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
RED="\e[31m"

BOLD_TXT=$(tput bold)
NORMAL_TXT=$(tput sgr0)

# START EXECUTION TIME IN SEC
exec__start_time=$(date +%s)

# CHECK IF XML DESC FILE IS PASSED
if [[ -z $1 ]]; then
	echo -e "${RED}ERROR: Build descriptor file is missing.${NORMAL}"
	exit -1
elif [[ ! -s $1 ]]; then
	echo -e "${RED}ERROR: Build descriptor file does not exist or access denied.${NORMAL}"
	exit -1
fi

# CHECK IF XML DESC FILE IS PASSED
config_filename="$(dirname $1)/config.xml"
if [[ ! -s $config_filename ]]; then
	echo -e "${RED}ERROR: Config file does not exist or access denied.${NORMAL}"
	exit -1
fi

# GET CONFIG XML STRING INTO A VAR
XML_CONF_STRING=$(cat $config_filename)

# GET DESC XML STRING INTO A VAR
XML_DESC_STRING=$(cat $1)

# FUNCTION TO GET XML DATA
function xml_get_val
{
	echo "$1" | xmlstarlet sel -t -v "$2" | xmlstarlet unesc
}

# FUNCTION TO EXEC COMMANDS AS ROOT
function do_as_root
{
	if [[ $EUID = 0 ]]; then
		$*
	elif [[ -x /usr/bin/sudo ]]; then
		sudo $*
	else
		su -c \\"$*\\"
	fi
}

# CHECK IF RUNING IN CHROOT MODE AS ROOT
chroot=$(xml_get_val "$XML_DESC_STRING" "/build/@chroot")
runbysudo=$(xml_get_val "$XML_DESC_STRING" "/build/@runbysudo")
if [[ $runbysudo != "yes" && $chroot != "yes" && $(id -u) == 0 ]]; then
	echo -e "${RED}ERROR: Sorry, user root is not allowed to execute '$0'.${NORMAL}"
	exit -1
fi

# SET USEFUL GLOBAL VARIABLES
export PROJECT__HOST_ARCH=$(uname -m)
export PROJECT__NAME=$(xml_get_val "$XML_CONF_STRING" "/config/project/name")
export PROJECT__TYPE=$(xml_get_val "$XML_CONF_STRING" "/config/project/type")
export PROJECT__ARCH=$(xml_get_val "$XML_CONF_STRING" "/config/project/arch")
export PROJECT__VERSION=$(xml_get_val "$XML_CONF_STRING" "/config/project/version")
export PROJECT__CODENAME=$(xml_get_val "$XML_CONF_STRING" "/config/project/codename")
export PROJECT__SUBJECT=$(xml_get_val "$XML_DESC_STRING" "/build/@subject")
export PROJECT__TIMEZONE=$(xml_get_val "$XML_CONF_STRING" "/config/system/timezone")
export PROJECT__HOSTNAME=$(xml_get_val "$XML_CONF_STRING" "/config/system/hostname")
export PROJECT__CONTROLLER=$(xml_get_val "$XML_CONF_STRING" "/config/system/controller")
export PROJECT__TGT=$PROJECT__ARCH-$PROJECT__NAME-linux-gnu
export PROJECT__PASWD=$(xml_get_val "$XML_CONF_STRING" "/config/system/password")
export PROJECT__VENDOR=$(xml_get_val "$XML_CONF_STRING" "/config/project/vendor")
export PROJECT__ISONAME="$PROJECT__NAME-$PROJECT__VERSION-$PROJECT__TYPE-$PROJECT__ARCH.iso"
export PROJECT__ISODIR=$(xml_get_val "$XML_CONF_STRING" "/config/isodir")
export PROJECT__LICENSE=$(xml_get_val "$XML_CONF_STRING" "/config/license")

export PROJECT__WEBSITE="https://github.com/mjahmadi/ghoghnoos-builder"
export PROJECT__AUTHOR_NAME="M.J.Ahmadi"
export PROJECT__AUTHOR_EMAIL="mohammad.j.ahmadi@gmail.com"

# CHECK IF NECESSARY GLOBAL VARIABLE EXISTS OR NOT
if [[ -z $PROJECT__NAME || -z $PROJECT__TYPE || -z $PROJECT__SUBJECT || -z $PROJECT__TGT || -z $PROJECT__ARCH || -z $PROJECT__VERSION ]]; then
	echo -e "${RED}ERROR: Project 'name/type/subject/target/arch/version' is missing.${NORMAL}"
	exit -1
fi

# CHECK HOST AND BUILD ARCH
if [[ $PROJECT__ARCH != "x86" && $PROJECT__ARCH != $PROJECT__HOST_ARCH ]]; then
	echo -e "${RED}ERROR: Unsupported build arch.${NORMAL}"
	exit -1
fi

# CHECK IF BUILD NEED'S SUDO
if [[ $UID != 0 && $(xml_get_val "$XML_DESC_STRING" "/build/@sudo") == 'yes' ]]; then
	set +e
	
	echo -e "\n${BOLD_TXT}We ask for root credential because of your configurations.${NORMAL_TXT}\nroot's password: "
	read -rs HOST_ROOT_PASS
	
	#sudo -k
	
	echo "$HOST_ROOT_PASS" | sudo -S echo "hello" &> /dev/null
	
	if ! [[ "$(sudo -n echo hello 2>&1)" == "hello" ]]; then
		echo -e "${RED}ERROR: Incorrect password was entered.${NORMAL}"
		exit -1
	else
		echo -e "${GREEN}OK!${NORMAL}\n"
	fi
	
	set -e
fi

# IMPILIMEN BUILD SEGMENTAION
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

if [[ -n $4 ]]; then
    action_begin_from=$4
else
    action_begin_from=1
fi

if [[ -n $5 ]]; then
    line_begin_from=$5
else
    line_begin_from=1
fi

# SET GLOBAL PATH VARIABLES AND CREATE DIRECTORIES
if [[ $(xml_get_val "$XML_CONF_STRING" "/config/system/constructor") = 'yes' ]]; then
	export PROJECT__RFS=$(pwd)
	export PROJECT__BLD=$PROJECT__RFS/build
	export PROJECT__TOL=$PROJECT__RFS/tools
	export PROJECT__PKG=$PROJECT__RFS/packages
	export PROJECT__SCR=$PROJECT__RFS/scripts
	export PROJECT__DEC=$PROJECT__RFS/desc
	export PROJECT__AST=$PROJECT__RFS/assets
		
	mkdir -pv $PROJECT__PKG
	mkdir -pv $PROJECT__BLD
	mkdir -pv $PROJECT__TOL
else
	export PROJECT__CUR=$(pwd)
	export PROJECT__DIR=$PROJECT__CUR/$PROJECT__TYPE-$PROJECT__ARCH
	export PROJECT__BLD=$PROJECT__DIR/build
	export PROJECT__RFS=$PROJECT__DIR/rootfs
	export PROJECT__TOL=$PROJECT__DIR/tools
	export PROJECT__PKG=$PROJECT__CUR/packages
	export PROJECT__SCR=$PROJECT__RFS/scripts
	export PROJECT__DEC=$PROJECT__RFS/desc
	export PROJECT__AST=$PROJECT__RFS/assets
	
	mkdir -pv $PROJECT__RFS
	mkdir -pv $PROJECT__PKG
	mkdir -pv $PROJECT__BLD
	mkdir -pv $PROJECT__TOL
fi

# MAXIMUM CONCURRENT MAKE JOBS
if [[ ! -z "/proc/cpuinfo " ]]; then
	export MAKEFLAGS="-j $(grep ^processor /proc/cpuinfo | wc -l)"
fi

# SET PROJECT ALTERNATIVE PATH
envpath=$(xml_get_val "$XML_DESC_STRING" "/build/@envpath")
if [[ -n $envpath ]]; then
	export OLD_PATH=$PATH
	export PATH=$(eval "echo -e "$envpath"")
fi

# SET/DEFINE GLOBAL VARIABLES IN CONFIG
eval $(xml_get_val "$XML_CONF_STRING" '/config/globals')

# SET/DEFINE GLOBAL VARIABLES IN DESC
eval $(xml_get_val "$XML_DESC_STRING" '/build/globals')

# BUILD >> PHASE
phase_count=$(xml_get_val "$XML_DESC_STRING" "count(/build/phase)")
for phase in `seq $phase_begin_from $phase_count`; do
    
    phase_disabled=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/@disabled")
    if [[ $phase_disabled == 'yes' ]]; then
        echo -e "${BOLD_TXT}\nphase --> '$phase'"
    	echo -e "phase is disabled!\n${NORMAL_TXT}"
    	continue
    fi
    
    # BUILD >> PHASE >> ENTRY
    entry_count=$(xml_get_val "$XML_DESC_STRING" "count(/build/phase[$phase]/entry)")
    for entry in `seq $entry_begin_from $entry_count`; do

		export ENTRY__ID=$entry
    	export ENTRY__NAME=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/@name")
    	export ENTRY__TYPE=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/@type")
    	export ENTRY__VERSION=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/version")
    	export ENTRY__LINK=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/like")
    	export ENTRY__FILENAME=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/filename")
    	export ENTRY__CHECKSUM=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/checksum")
    	export ENTRY__CHECKSUM_METHOD=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/checksum/@type")
    	export ENTRY__SEQ=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/checksum/@seq")
    	
    	entry_name=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/@name")
        entry_type=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/@type")
        
        entry_disabled=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/@disabled")
        if [[ $entry_disabled == 'yes' ]]; then
        	echo -e "${BOLD_TXT}\nentry '$entry' is disabled!\n${NORMAL_TXT}"
        	continue
        else
			echo -e "${BOLD_TXT}\nphase --> '$phase'"
			echo -e "entry --> '$entry'\n$entry_name[$entry_type]\n${NORMAL_TXT}"
			sleep 2
        fi
		
        # BUILD >> PHASE >> ENTRY >> ACTION [TYPE=BEFORE]
        entry_action_count=$(xml_get_val "$XML_DESC_STRING" "count(/build/phase[$phase]/entry[$entry]/action[@when='before'])")
		for action in `seq $action_begin_from $entry_action_count`; do

		action_disabled=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/@disabled")
		if [[ $action_disabled == 'yes' ]]; then
			echo -e "${BOLD_TXT}\naction '$action' is disabled!\n${NORMAL_TXT}"
			continue
		else
			echo -e "${BOLD_TXT}action --> '$action'\n${NORMAL_TXT}"
			sleep 1
		fi

		# BUILD >> PHASE >> ENTRY >> ACTION [TYPE=AFTER] >> LINE
		entry_action_line_count=$(xml_get_val "$XML_DESC_STRING" "count(/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/line)")
        for line in `seq $line_begin_from $entry_action_line_count`; do
        	
			line_disabled=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/line[$line]/@disabled")
			if [[ $line_disabled == 'yes' ]]; then
				echo -e "${BOLD_TXT}\nline '$line' is disabled!\n${NORMAL_TXT}"
				continue
			fi
			
		        sudo=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/line[$line]/@sudo")
		        verbos=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/line[$line]/@verbos")
	        	
		        command=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/line[$line]")
		        
		        if [[ $verbos == 'yes' ]]; then
		            echo -e "${BOLD_TXT}$command${NORMAL_TXT}"
		        fi
		        
				if [[ $sudo == 'yes' && -n $HOST_ROOT_PASS ]]; then
					eval "echo $HOST_ROOT_PASS | sudo -S $command"
				else
					eval "$command"
				fi
        	done
        	line_begin_from=1
        done
        
		# BUILD >> PHASE >> ENTRY
		cdto=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/@cdto")
		download=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/@download")
		extract=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/@extract")
		link=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/link")
		filename=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/filename")
		directory=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/directory")
		directory_base=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/directory/@base")
		checksum=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/checksum")
		checksum_type=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/checksum/@type")
		
		if [[ $download == 'yes' ]]; then
			echo -e "\nDownloading '$filename'"
			wget --continue $link --directory-prefix="$PROJECT__PKG"
		fi
        
		if [[ $entry_type == 'package/src' ]]; then
		
			if [[ ! -s "$PROJECT__PKG/$filename" ]]; then
				echo -e "${RED}ERROR: The package file does not exist or access denied.${NORMAL}"
				exit -1
			fi
			
			chk_algo="${checksum_type}sum"
			checksum2=($($chk_algo $PROJECT__PKG/$filename))
			
			if [[ -n $checksum && $checksum != $checksum2 ]]; then
				echo -e "${RED}ERROR: Checksum[$checksum_type] validation failed.\n  '$checksum' != '$checksum2'${NORMAL}"
				exit -1
			fi

		    if [[ $entry_type == 'package/src' ]]; then
				if [[ $extract == 'yes' ]]; then
				
					des_dir=$(tar -tf $PROJECT__PKG/$filename | head -n 1 | cut -f1)
					des_dir=$(IFS='/' read -r -a array <<< $des_dir && echo ${array[0]})
					des_dir=$(read -r -a array <<< $des_dir && echo ${array[0]})
					
					echo -e "\nExtracting '$filename'"
					
					if [[ -n $directory ]]; then
					
						if [[ $directory_base = 'yes' ]]; then
							eval tmp_dir=$directory/$des_dir
						else
							eval tmp_dir=$directory
						fi
						
						rm -rf $tmp_dir
						mkdir -v -p $tmp_dir
						
						tar -xf $PROJECT__PKG/$filename -C $tmp_dir
					else
						rm -rf $PROJECT__BLD/$des_dir
						tar -xf $PROJECT__PKG/$filename -C $PROJECT__BLD
					fi
				fi
			fi
		fi
		
		if [[ $cdto == 'yes' ]]; then
		
			if [[ ! -s $tmp_dir && ! -s $PROJECT__BLD/$des_dir ]]; then
				echo -e "${RED}ERROR: The directory does not exist or access denied.${NORMAL}"
				exit -1
			fi
			
			if [[ -n $tmp_dir ]]; then
				cd $tmp_dir/$des_dir
			else
				cd $PROJECT__BLD/$des_dir
			fi
			
		fi
        
        # BUILD >> PHASE >> ENTRY >> ACTION [TYPE=AFTER]
        entry_action_count=$(xml_get_val "$XML_DESC_STRING" "count(/build/phase[$phase]/entry[$entry]/action[@when='after'])")
        for action in `seq $action_begin_from $entry_action_count`; do
        
			action_disabled=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/@disabled")
			if [[ $action_disabled == 'yes' ]]; then
				echo -e "${BOLD_TXT}\naction '$action' is disabled!\n${NORMAL_TXT}"
				continue
			else
				echo -e "${BOLD_TXT}action --> '$action'\n${NORMAL_TXT}"
				sleep 1
			fi
        
            # BUILD >> PHASE >> ENTRY >> ACTION [TYPE=AFTER] >> LINE
        	entry_action_line_count=$(xml_get_val "$XML_DESC_STRING" "count(/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/line)")
        	for line in `seq $line_begin_from $entry_action_line_count`; do
        	
				line_disabled=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/line[$line]/@disabled")
				if [[ $line_disabled == 'yes' ]]; then
					echo -e "${BOLD_TXT}\nline '$line' is disabled!\n${NORMAL_TXT}"
					continue
				fi
			
		        sudo=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/line[$line]/@sudo")
		        verbos=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/line[$line]/@verbos")
	        	
		        command=$(xml_get_val "$XML_DESC_STRING" "/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/line[$line]")
		        
		        if [[ $verbos == 'yes' ]]; then
		            echo -e "${BOLD_TXT}$command${NORMAL_TXT}"
		        fi
		        
				if [[ $sudo == 'yes' && -n $HOST_ROOT_PASS ]]; then
					eval "echo $HOST_ROOT_PASS | sudo -S $command"
				else
					eval "$command"
				fi
        	done
			line_begin_from=1
        done
    done
    
	# RESET ENTRY INDEX FOR EACH PHASE
	entry_begin_from=1
	action_begin_from=1
done

unset PROJECT__ARCH PROJECT__AUTHOR_EMAIL PROJECT__AUTHOR_NAME PROJECT__BLD PROJECT__CODENAME \
 PROJECT__CONTROLLER PROJECT__HOSTNAME PROJECT__HOST_ARCH PROJECT__ISODIR PROJECT__ISONAME PROJECT__LICENSE \
 PROJECT__NAME PROJECT__PASWD PROJECT__PKG PROJECT__RFS PROJECT__SUBJECT PROJECT__TGT PROJECT__TIMEZONE \
 PROJECT__TOL PROJECT__TYPE PROJECT__VENDOR PROJECT__VERSION PROJECT__WEBSITE ENTRY__CHECKSUM ENTRY__CHECKSUM_METHOD \
 ENTRY__FILENAME ENTRY__ID ENTRY__LINK ENTRY__NAME ENTRY__SEQ ENTRY__TYPE ENTRY__VERSION LC_ALL MAKEFLAGS

# CALCULATE THE EXECUTION TIME
exec__elapsed_time=$(echo "$(date +%s) - $exec__start_time" | bc)
echo -e "${GREEN}\nExecution time:\n   $(($exec__elapsed_time / 60)) minute(s) and $(($exec__elapsed_time % 60)) second(s). ${NORMAL}\n"

