#!/bin/bash


username=$USER
group=$(id -g -n $username)

sudo echo -e "\nCleaning project directory tree..."
sudo rm -rf ./bin ./boot ./build ./dev ./etc ./home ./iso ./lib ./lib64 ./media ./mnt ./opt ./proc ./root \
./run ./sbin ./srv ./sys ./tmp ./usr ./var ./init
echo -e "done."

echo -e "\nChanging project directory ownership..."
sudo chown -R $username:$group $(pwd)
echo -e "done.\n"

