#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154

set -vx

######################################################################################################################
### Setup Build System and GitHub

##apt install -y autopoint

wget -qO- uny.nu/pkg | bash -s buildsys

### Installing build dependencies
unyp install python libxml2 libxslt ninja

pip3_bin=(/uny/pkg/python/*/bin/pip3)
"${pip3_bin[0]}" install --upgrade pip
"${pip3_bin[0]}" install meson

### Getting Variables from files
UNY_AUTO_PAT="$(cat UNY_AUTO_PAT)"
export UNY_AUTO_PAT
GH_TOKEN="$(cat GH_TOKEN)"
export GH_TOKEN

source /uny/git/unypkg/fn
uny_auto_github_conf

######################################################################################################################
### Timestamp & Download

uny_build_date

mkdir -pv /uny/sources
cd /uny/sources || exit

pkgname="xorg"
#pkggit="https://github.com/xorg/xorg.git refs/tags/*"
gitdepth="--depth=1"

### Get version info from git remote
# shellcheck disable=SC2086
#latest_head="$(git ls-remote --refs --tags --sort="v:refname" $pkggit | grep -E "v[0-9.]+$" | tail --lines=1)"
glibc_dir=(/uny/pkg/glibc/*)
latest_ver="$(basename "${glibc_dir[0]}")"
#latest_commit_id="$(echo "$latest_head" | cut --fields=1)"

version_details

# Release package no matter what:
echo "newer" >release-"$pkgname"

#git_clone_source_repo

mkdir -pv xorg/{util,proto,lib}

# ulti-macros
cd xorg/util || exit
git_repo="https://gitlab.freedesktop.org/xorg/util/macros.git"
git_tag="$(git ls-remote --refs --tags --sort="v:refname" "$git_repo" | grep -E "util-macros-[0-9.]+$" | tail -n1 | sed "s|.*/||")"
git clone $gitdepth --recurse-submodules -j8 --single-branch -b "$git_tag" "$git_repo"
cd /uny/sources || exit

# xorgproto
cd xorg/proto || exit
git_repo="https://gitlab.freedesktop.org/xorg/proto/xorgproto.git"
git_tag="$(git ls-remote --refs --tags --sort="v:refname" "$git_repo" | grep -E "xorgproto-[0-9.]+$" | tail -n1 | sed "s|.*/||")"
git clone $gitdepth --recurse-submodules -j8 --single-branch -b "$git_tag" "$git_repo"

# xcbproto
git_repo="https://gitlab.freedesktop.org/xorg/proto/xcbproto.git"
git_tag="$(git ls-remote --refs --tags --sort="v:refname" "$git_repo" | grep -E "xcb-proto-[0-9.]+$" | tail -n1 | sed "s|.*/||")"
git clone $gitdepth --recurse-submodules -j8 --single-branch -b "$git_tag" "$git_repo"
cd /uny/sources || exit

# libxdmcp
cd xorg/lib || exit
git_repo="https://gitlab.freedesktop.org/xorg/lib/libxdmcp.git"
git_tag="$(git ls-remote --refs --tags --sort="v:refname" "$git_repo" | grep -E "libXdmcp-[0-9.]+$" | tail -n1 | sed "s|.*/||")"
git clone $gitdepth --recurse-submodules -j8 --single-branch -b "$git_tag" "$git_repo"

# libxau
git_repo="https://gitlab.freedesktop.org/xorg/lib/libxau.git"
git_tag="$(git ls-remote --refs --tags --sort="v:refname" "$git_repo" | grep -E "libXau-[0-9.]+$" | tail -n1 | sed "s|.*/||")"
git clone $gitdepth --recurse-submodules -j8 --single-branch -b "$git_tag" "$git_repo"

# libxcb
git_repo="https://gitlab.freedesktop.org/xorg/lib/libxcb.git"
git_tag="$(git ls-remote --refs --tags --sort="v:refname" "$git_repo" | grep -E "libxcb-[0-9.]+$" | tail -n1 | sed "s|.*/||")"
git clone $gitdepth --recurse-submodules -j8 --single-branch -b "$git_tag" "$git_repo"

# libxtrans
git_repo="https://gitlab.freedesktop.org/xorg/lib/libxtrans.git"
git_tag="$(git ls-remote --refs --tags --sort="v:refname" "$git_repo" | grep -E "xtrans-[0-9.]+$" | tail -n1 | sed "s|.*/||")"
git clone $gitdepth --recurse-submodules -j8 --single-branch -b "$git_tag" "$git_repo"

# libx11
git_repo="https://gitlab.freedesktop.org/xorg/lib/libx11.git"
git_tag="$(git ls-remote --refs --tags --sort="v:refname" "$git_repo" | grep -E "libX11-[0-9.]+$" | tail -n1 | sed "s|.*/||")"
git clone $gitdepth --recurse-submodules -j8 --single-branch -b "$git_tag" "$git_repo"
cd /uny/sources || exit

archiving_source

######################################################################################################################
### Build

# unyc - run commands in uny's chroot environment
# shellcheck disable=SC2154
unyc <<"UNYEOF"
set -vx
source /uny/git/unypkg/fn

pkgname="xorg"

version_verbose_log_clean_unpack_cd
get_env_var_values
get_include_paths

####################################################
### Start of individual build script

unset LD_RUN_PATH

#pkgname="xorg"
#pkgver=2.39
#get_env_var_values
#get_include_paths

export XORG_PREFIX=/uny/pkg/"$pkgname"/"$pkgver"
export XORG_CONFIG="--prefix="$XORG_PREFIX" --sysconfdir=/etc/uny \
    --localstatedir=/var/uny --disable-static"

cd util/macros || exit
autoreconf -v --install || exit 1
./configure $XORG_CONFIG
make install
get_pkgconfig_paths
cd ../.. || exit

cd proto/xorgproto || exit
autoreconf -v --install || exit 1
./configure $XORG_CONFIG
mkdir build
cd build || exit
meson setup --prefix=$XORG_PREFIX ..
ninja
ninja install
get_pkgconfig_paths
cd ../../.. || exit

cd lib/libxdmcp || exit
autoreconf -v --install || exit 1
./configure $XORG_CONFIG
make -j"$(nproc)"
make -j"$(nproc)" install
get_pkgconfig_paths
cd ../.. || exit

cd proto/xcbproto || exit
autoreconf -v --install || exit 1
PYTHON=python3 ./configure $XORG_CONFIG
make install
get_pkgconfig_paths
cd ../.. || exit

cd lib/libxau || exit
autoreconf -v --install || exit 1
./configure $XORG_CONFIG
make -j"$(nproc)"
make -j"$(nproc)" install
get_pkgconfig_paths
cd ../.. || exit

cd lib/libxcb || exit
autoreconf -v --install || exit 1
./configure $XORG_CONFIG \
    --without-doxygen
LC_ALL=en_US.UTF-8 make -j"$(nproc)"
make -j"$(nproc)" install
get_pkgconfig_paths
cd ../.. || exit

cd lib/libxtrans || exit
autoreconf -v --install || exit 1
./configure $XORG_CONFIG
make -j"$(nproc)"
make -j"$(nproc)" install
get_pkgconfig_paths
cd ../.. || exit

cd lib/libx11 || exit
autoreconf -v --install || exit 1
./configure $XORG_CONFIG
make -j"$(nproc)"
make -j"$(nproc)" install
get_pkgconfig_paths
cd ../.. || exit

####################################################
### End of individual build script

add_to_paths_files
dependencies_file_and_unset_vars
cleanup_verbose_off_timing_end
UNYEOF

######################################################################################################################
### Packaging

package_unypkg
