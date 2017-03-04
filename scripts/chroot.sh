#!/bin/bash


if [[ -s "/tools/bin/env" ]]; then
	env_tmp=/tools/bin/env
	path_tmp=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin
	bash_tmp=/tools/bin/bash

else
	env_tmp=/usr/bin/env
	path_tmp=/bin:/usr/bin:/sbin:/usr/sbin
	bash_tmp=/bin/bash
fi

chroot "$(pwd)"         \
$env_tmp -i             \
HOME=/root              \
TERM="$TERM"            \
PS1='\u:\w\$ '          \
PATH=$path_tmp          \
$bash_tmp --login +h

