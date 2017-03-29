#!/bin/bash

username=$USER
group=$(id -g -n $username)


sudo echo -e "\nChanging ownership..."

sudo chown -R $username:$group ./builder.sh ./assets ./packages ./desc ./scripts

