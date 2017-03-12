#!/bin/bash


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

if [[ -s "/tools/bin/env" ]]; then
	env_tmp=/tools/bin/env
	path_tmp=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin
	bash_tmp=/tools/bin/bash
else
	env_tmp=/usr/bin/env
	path_tmp=/bin:/usr/bin:/sbin:/usr/sbin
	bash_tmp=/bin/bash
fi

chroot "$(pwd)"                                         \
$env_tmp -i                                             \
HOME=/root                                              \
TERM="$TERM"                                            \
PS1="$BOLD_TXT$BLUE\u@chroot:\w\$ $NORMAL$NORMAL_TXT"    \
PATH=$path_tmp                                          \
$bash_tmp --login +h

