#!/bin/bash

# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#     http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing permissions and
# limitations under the License.

set -euxo pipefail

export CC=gcc-7
export CXX=g++-7
export AWSLC_INSTALL_PREFIX="/home/ubuntu/awslcinstall"

PATH=$PWD/build-tools/bin:$PATH
ROOT=$PWD

# End to end tests require valid credentials (instance role, etc..)
# Disable for local runs.
if [ -f "/sys/hypervisor/uuid" ]; then
        ONEC2=$(grep -c ec2 /sys/hypervisor/uuid)
        if [ "${ONEC2}" -gt 0 ]; then
            E2E="ON";
        else
            E2E="OFF";
        fi
else
    E2E="OFF";
fi

debug() {
# If the threading test does in fact fail, it does so by crashing.
# Since this sort of bug might not be reproducible, make sure to dump
# some useful information before failing.
    ulimit -c unlimited
    if ! "$@"; then
        if [ -e core.* ]; then
            gdb -x "$ROOT/codebuild/gdb.commands" "$1" core.* 
            exit 1
        fi
    fi
}

function installgcc() {
    apt-get update && \
    apt-get -y --no-install-recommends upgrade && \
    apt-get -y --no-install-recommends install gcc-7 g++-7
}

run_test() {
    PREFIX_PATH="$1"
    shift

    rm -rf build
    mkdir build
    # (cd build
    # #TODO: EC2 metadata service fails; fix an re-enable end2end tests.
    # cmake \
    #     # TODO: investigate the build flavor - DBUILD_AWS_ENC_SDK_CPP
    #     # -DBUILD_AWS_ENC_SDK_CPP=ON \
    #     # -DAWS_ENC_SDK_END_TO_END_TESTS=${E2E} \
    #     # -DAWS_ENC_SDK_KNOWN_GOOD_TESTS=ON \
    #     # TODO: ask if this is still needed. python-1.3.8.zip no longer exists.
    #     # -DAWS_ENC_SDK_TEST_VECTORS_ZIP="$ROOT/aws-encryption-sdk-cpp/tests/test_vectors/aws-encryption-sdk-test-vectors/vectors/awses-decrypt/python-1.3.8.zip" \
    #     # -DAWS_ENC_SDK_END_TO_END_EXAMPLES=${E2E} \
    #     # -DCMAKE_C_FLAGS="$CFLAGS" \
    #     # -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
    #     # -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
    #     # -DOPENSSL_ROOT_DIR="${AWSLC_INSTALL_PREFIX}" \
    #     # -DVALGRIND_OPTIONS="--gen-suppressions=all;--suppressions=$ROOT/valgrind.suppressions" \
    #     -DCMAKE_PREFIX_PATH="$PREFIX_PATH" \
    #     -DBUILD_SHARED_LIBS="$BUILD_SHARED_LIBS" \
    #     -GNinja \
    #     .. "$@" 2>&1|head -n 1000)
    (cd build && \
    cmake -DOPENSSL_ROOT_DIR="${AWSLC_INSTALL_PREFIX}" \
        -DCMAKE_PREFIX_PATH="${AWSLC_INSTALL_PREFIX}/$PREFIX_PATH" \
        -DBUILD_SHARED_LIBS="$BUILD_SHARED_LIBS" \
        -GNinja \
        .. "$@" 2>&1|head -n 1000)
    cmake --build $ROOT/build -- -v
    (cd build; ctest --output-on-failure -j8)
    (cd build; debug ./tests/test_local_cache_threading) || exit 1
    # TODO: investigate what below is doing
    # "$ROOT/codebuild/bin/test-install.sh" "$PREFIX_PATH" "$PWD/build"
}

# installgcc

function build_awslc() {
  cd /home/ubuntu/bryce-shang/aws-lc && \
    rm -rf build && \
    mkdir -p build && \
    cd build && \
    cmake -GNinja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_SHARED_LIBS="$BUILD_SHARED_LIBS" -DCMAKE_INSTALL_PREFIX=${AWSLC_INSTALL_PREFIX} ../ && \
    ninja -j $(nproc) &&
    ninja install
}

# Print env variables for debug purposes
env

# Run the full test suite without valgrind, and as a shared library
export BUILD_SHARED_LIBS=on
# build_awslc
run_test '/deps/install;/deps/shared/install' -DCMAKE_BUILD_TYPE=RelWithDebInfo
# # Also run the test suite as a debug build (probing for -DNDEBUG issues), and as a static library
# export BUILD_SHARED_LIBS=off
# run_test '/deps/install;/deps/static/install' -DCMAKE_BUILD_TYPE=Debug
# # Run a lighter weight test suite under valgrind
# export BUILD_SHARED_LIBS=off
# run_test '/deps/install;/deps/static/install' -DCMAKE_BUILD_TYPE=RelWithDebInfo -DREDUCE_TEST_ITERATIONS=TRUE -DVALGRIND_TEST_SUITE=ON
