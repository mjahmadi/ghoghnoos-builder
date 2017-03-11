#!/bin/bash


find ./usr/lib -type f -name \*.a \
-exec strip --strip-debug {} ';'
find ./lib ./usr/lib -type f -name \*.so* \
-exec strip --strip-unneeded {} ';'
find ./{bin,sbin} ./usr/{bin,sbin,libexec} -type f \
-exec strip --strip-all {} ';'

