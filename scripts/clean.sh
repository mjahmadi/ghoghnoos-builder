#!/bin/bash


if [[ $UID == 0 ]]; then
	echo -e "\nCleaning project directory tree..."
	rm -rf ./bin
	rm -rf ./boot
	rm -rf ./build
	rm -rf ./dev
	rm -rf ./etc
	rm -rf ./home
	rm -rf ./iso
	rm -rf ./lib
	rm -rf ./lib64
	rm -rf ./media
	rm -rf ./mnt
	rm -rf ./opt
	rm -rf ./proc
	rm -rf ./root
	rm -rf ./run
	rm -rf ./sbin
	rm -rf ./srv
	rm -rf ./sys
	rm -rf ./tmp
	rm -rf ./tools
	rm -rf ./usr
	rm -rf ./var
	rm -rf ./init
	echo -e "done."

	echo -e "\nChanging project directory ownership..."
	chown -R $USER $(pwd)
	echo -e "done.\n\n"
else
	echo -e "You need to be root or use sudo.\n"
fi

