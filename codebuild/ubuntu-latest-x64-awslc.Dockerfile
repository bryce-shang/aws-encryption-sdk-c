# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

FROM ubuntu:latest

# Needed for setup-apt-cache.sh
ADD https://mirrors.kernel.org/ubuntu/pool/main/n/net-tools/net-tools_1.60+git20180626.aebd88e-1ubuntu1_amd64.deb /tmp
ADD https://mirrors.kernel.org/ubuntu/pool/universe/n/netcat/netcat-traditional_1.10-40_amd64.deb /tmp
RUN dpkg -i /tmp/net-tools_*.deb /tmp/netcat-*.deb

ADD bin/setup-apt-cache.sh /usr/local/bin/
ADD bin/setup-apt.sh /usr/local/bin/
RUN setup-apt-cache.sh
RUN setup-apt.sh

ENV PATH=/usr/local/bin:/usr/bin:/bin

ENV CC=/usr/bin/gcc
ENV CXX=/usr/bin/g++
ENV CFLAGS=
ENV CXXFLAGS=
ENV LDFLAGS=

# We're going to install our own version of openssl at /deps/install/lib - this lets us test against multiple openssl versions.
# However, this also means we need to install our own version of curl, as curl links against libssl and the C++ SDK links
# against curl. What's more, we can't remove system libcurl, as we'd need to build and install our own version of git if we
# did so. Sigh.
#
# To deal with this mess, set up a bunch of -rpath overrides to ensure that all the binaries we build look in a different
# library directory first. We do this setup after configuring cmake, as we don't particularly need/want cmake to depend
# on our special versions of openssl/libcurl (or to depend on them at all for that matter).
ENV LDFLAGS="-Wl,-rpath -Wl,/deps/install/lib -Wl,-rpath -Wl,/deps/shared/install/lib -L/deps/install/lib -L/deps/shared/install/lib"

ADD bin/apt-install-pkgs /usr/local/bin/
ADD bin/install-shared-deps-awslc.sh /usr/local/bin/
RUN install-shared-deps-awslc.sh

ADD bin/install-aws-deps.sh /usr/local/bin
RUN install-aws-deps.sh

ADD bin/install-node.sh /usr/local/bin
RUN install-node.sh

ADD bin/codebuild-test.sh /usr/local/bin/

# Remove apt proxy configuration before publishing the dockerfile
RUN rm -f /etc/apt/apt.conf.d/99proxy

# TODO: remove below.
# Add new user for development
RUN /usr/sbin/useradd ubuntu
RUN /usr/sbin/usermod -G root ubuntu

RUN echo "" >> /etc/sudoers
RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
