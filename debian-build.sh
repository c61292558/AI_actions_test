#!/bin/bash
pushd $(dirname $(realpath $0))
sudo apt install debootstrap systemd-container sudo file fakeroot -y
cp -vr src pkg
bash build-pkg.sh pkg
fakeroot dpkg-deb -Z gzip -b pkg/ ./
popd