#!/bin/bash


/tools/bin/find $(pwd)/usr/lib -type f -name \*.a \
-exec /tools/bin/strip --strip-debug {} ';'
/tools/bin/find $(pwd)/lib $(pwd)/usr/lib -type f -name \*.so* \
-exec /tools/bin/strip --strip-unneeded {} ';'
/tools/bin/find $(pwd)/{bin,sbin} $(pwd)/usr/{bin,sbin,libexec} -type f \
-exec /tools/bin/strip --strip-all {} ';'

