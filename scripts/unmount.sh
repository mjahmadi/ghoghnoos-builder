#!/bin/bash


sudo echo -e "\nUnmounting..."

sudo umount -v ./dev/pts
sudo umount -v ./dev
sudo umount -v ./run
sudo umount -v ./proc
sudo umount -v ./sys

