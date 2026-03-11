#!/usr/bin/env bash

dpkg -b ./pkg/ ./ 
echo "请自行继续执行后续代码……"
# 这里放你真正需要继续执行的命令
# dpkg-deb -b "$PKG_DIR" "${PKG_DIR}.deb"