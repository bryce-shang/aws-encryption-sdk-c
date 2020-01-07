#!/bin/bash

# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
# http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing permissions and
# limitations under the License.

# This script installs non-AWS dependencies. Currently this is openssl and libcurl.

# We install openssl primarily to control the version being used, but also to turn on
# -DPURIFY to silence some valgrind warnings.

# We install libcurl because we need a version that links against the version of openssl
# in use, to avoid version conflicts.

# env variables used:
# $OPENSSL_PLATFORM: The openssl platform name (e.g. linux-generic32)
# CC, CXX, CFLAGS, CXXFLAGS, LDFLAGS: The usual compiler flags (as used by the respective package
#                                     configure scripts)
# OPENSSL_TAG: The tag or branch of openssl to build
GCC_MAJ_VER="${GCC_MAJ_VER:-NONE}"
PATH=$PATH:/sbin

set -euxo pipefail

mkdir -p /deps

install_gcc(){
    if [ "$GCC_MAJ_VER" == 4 ]; then
        apt-get update 
        # GCC-4.8 has packaging issues- complains about not being able to configure the package.
        apt-get install -y gcc-4.8 g++-4 g++-4.8-multilib || true
        # for ubuntu18, gcc-7 is standard- install 4.8 and make it the default.
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 700 --slave /usr/bin/g++ g++ /usr/bin/g++-7
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 4800 --slave /usr/bin/g++ g++ /usr/bin/g++-4.
    fi
    if [ "$GCC_MAJ_VER" == 6 ]; then
        apt-get update && apt-get install -y gcc-6 g++-6 g++-6-multilib
        # for ubuntu18, gcc-7 is standard- install 6 and make it the default.
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 700 --slave /usr/bin/g++ g++ /usr/bin/g++-7
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-6 6000 --slave /usr/bin/g++ g++ /usr/bin/g++-6
    fi

}

install_gcc
git clone --depth 1 --branch $OPENSSL_TAG https://github.com/openssl/openssl.git /deps/openssl_src
cd /deps/openssl_src
# -DPURIFY tries to avoid confusing valgrind (e.g. avoiding using uninitialized memory as entropy)
./Configure --prefix=/deps/install shared -DPURIFY $OPENSSL_PLATFORM
make depend
make -j8
make install
cd /
rm -rf /deps/openssl_src

# We need a libcurl compatible with our version of openssl as well
mkdir /deps/curl
cd /deps/curl
wget https://curl.haxx.se/download/curl-7.61.1.tar.gz
tar xzf curl-*.tar.gz
cd curl-*/
./configure --with-ssl=/deps/install --prefix=/deps/install \
    --without-gnutls --without-nss --without-gssapi
make -j8
make install
cd /
rm -rf /deps/curl
