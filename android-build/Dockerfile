FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Tallinn

RUN apt-get update
RUN apt-get install -y \
  openjdk-11-jdk \
  abootimg binwalk \
  android-sdk-libsparse-utils \
  bc bison build-essential ccache cpio curl dwarves flex g++-multilib gcc-multilib git git-lfs \
  gnupg gperf gpg gpg-agent \
  imagemagick lib32readline-dev lib32z1-dev libelf-dev liblz4-tool libncurses5 \
  libsdl1.2-dev libssl-dev libxml2 libxml2-utils \
  lzop make pngcrush python-is-python3 rsync schedtool squashfs-tools \
  xsltproc zip zlib1g-dev bash-completion

RUN curl -o /usr/bin/repo http://commondatastorage.googleapis.com/git-repo-downloads/repo && \
    chmod +x /usr/bin/repo

RUN mkdir -p /root
COPY .gitconfig /root
RUN git lfs install && git config --global trailer.changeid.key "Change-Id"

RUN mkdir /android

ENV ANDROID_ROOT=/android

WORKDIR /android
