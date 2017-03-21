#!/bin/bash


username=$USER
group=$(id -g -n $username)

echo -e "\nUnmounting..."
sudo umount -v ./dev/pts
sudo umount -v ./dev
sudo umount -v ./run
sudo umount -v ./proc
sudo umount -v ./sys

echo -e "\nCleaning project directory tree..."
sudo rm -rf ./bin ./boot ./build ./dev ./etc ./home ./iso ./lib ./lib64 ./media ./mnt ./opt ./proc ./root \
./run ./sbin ./srv ./sys ./tmp ./usr ./var ./init
echo -e "done."

echo -e "\nChanging project directory ownership..."
sudo chown -R $username:$group $(pwd)
echo -e "done.\n"

