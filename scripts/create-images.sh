#!/bin/bash

set -e

source ~/.hadk.env

# defaults
VERSION=testing
DEVICES="xqcq54 xqct54"
ISMIC="no"
RELEASE=""

while :; do
    case $1 in
	--mic)
	    ISMIC=yes
	    ;;

	--release)
	    RELEASE=$2
	    shift
	    ;;

	--version)
	    VERSION=$2
	    shift
	    ;;

	--device)
	    DEVICES=$2
	    shift
	    ;;

	*)
	    break
    esac
    shift
done

EXTRA_NAME=

# check if all is specified
[ -z "$RELEASE" ] && (echo "Release has to be specified with --release option" && exit -1)

RELMAJORMINOR=${RELEASE%.*.*}

case $VERSION in
    testing)
	URL=https://repo.sailfishos.org/obs/nemo:/testing:/hw:/sony:/nagara:/${RELMAJORMINOR}/sailfishos_${RELMAJORMINOR}_${PORT_ARCH}/$PORT_ARCH/
	;;
    devel)
	URL=https://repo.sailfishos.org/obs/nemo:/devel:/hw:/sony:/nagara/sailfish_latest_$PORT_ARCH/$PORT_ARCH/
	;;
    *)
	echo "Version (devel or testing) is not specified using --testing option"
	exit -2
	;;
esac

if [ "$ISMIC" == "no" ]; then
    scriptdir=`dirname "$(readlink -f "$0")"`
    RELEASE_DIR=$ANDROID_ROOT/releases/$RELEASE
    mkdir -p $RELEASE_DIR
    cd $RELEASE_DIR

    for device in $DEVICES
    do
		rm Jolla-@RELEASE@-$device-@ARCH@.ks || echo No old KS file, continuing
		"$scriptdir/get_ks.sh" $URL $device
		sudo $PLATFORM_SDK_ROOT/sdks/sfossdk/sdk-chroot \
			"$scriptdir/create-images.sh" \
			--mic \
			--release $RELEASE --version $VERSION --device $device
    done
    exit
fi

device=$DEVICES

case "$device" in
  xqct54)
    PRETTY_DEVICE="Xperia-1-IV"
    ;;
  xqcq54)
    PRETTY_DEVICE="Xperia-5-IV"
    ;;
  *)
	echo "Unknown device: $device"
	exit 1
    ;;
esac

DEVICE_UPPER=${device^^}

echo
echo Building for $RELEASE $PRETTY_DEVICE $DEVICE_UPPER

source ~/.hadk.pre-$device
source ~/.hadk.post

RELEASE_DIR=$ANDROID_ROOT/releases/$RELEASE
cd $RELEASE_DIR

# Workaround KS generation bug. Looks like generated KS has a wrong
# Currently generated `repo` commands for testing replace version with
# "latest". Let's replace them back. This is fixed in Jolla's PR, but for now
# the fix is needed
#
# to be replaced:
#  repo --name=adaptation-community-xqct54-@RELEASE@ --baseurl=https://repo.sailfishos.org/obs/nemo:/testing:/hw:/sony:/nagara:/latest/sailfishos_latest_@ARCH@/
#  repo --name=adaptation-community-common-xqct54-@RELEASE@ --baseurl=https://repo.sailfishos.org/obs/nemo:/testing:/hw:/common/sailfishos_latest_@ARCH@/
if [ "$VERSION" == "testing" ]; then
	sed -i "s|/latest/|/${RELMAJORMINOR}/|g" Jolla-@RELEASE@-$device-@ARCH@.ks
	sed -i "s|/sailfishos_latest|/sailfishos_${RELMAJORMINOR}|g" Jolla-@RELEASE@-$device-@ARCH@.ks
fi

if [ -d "mic" ]; then
	echo "Remove previous build"
	rm -rf mic
fi

sudo mic create fs --arch=$PORT_ARCH \
	--pack-to=sfe-$device-$RELEASE$EXTRA_NAME.tar.gz \
	--tokenmap=ARCH:$PORT_ARCH,RELEASE:$RELEASE,EXTRA_NAME:$EXTRA_NAME,DEVICEMODEL:$device \
	--record-pkgs=name,url \
	--outdir=mic Jolla-@RELEASE@-$device-@ARCH@.ks

sudo chown -R "$(id -un):$(id -gn)" mic

mv mic/sailfishos-$device-release-$RELEASE.zip \
   sailfishos-$PRETTY_DEVICE-$DEVICE_UPPER-$RELEASE-$VERSION.zip
