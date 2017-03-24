#!/bin/bash


NORMAL="\e[39m"
RED="\e[31m"

if [[ -s "$(pwd)/bin/env" ]]; then
	env_tmp=/usr/bin/env
	path_tmp=/bin:/usr/bin:/sbin:/usr/sbin
	bash_tmp=/bin/bash
else
	env_tmp=/tools/bin/env
	path_tmp=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin
	bash_tmp=/tools/bin/bash
fi

chroot "$(pwd)"                     \
$env_tmp -i                         \
HOME=/root                          \
TERM="$TERM"                        \
PS1="$RED\u@chroot:\w\$ $NORMAL"    \
PATH=$path_tmp                      \
$bash_tmp --login +h

