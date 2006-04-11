#!/bin/bash
#
# Build PlanetLab-Bootstrap.tar.bz2, the reference image for PlanetLab
# nodes.
#
# Mark Huang <mlhuang@cs.princeton.edu>
# Copyright (C) 2005-2006 The Trustees of Princeton University
#
# $Id: buildnode.sh,v 1.8 2006/04/11 15:42:04 mlhuang Exp $
#

PATH=/sbin:/bin:/usr/sbin:/usr/bin

# In both a normal CVS environment and a PlanetLab RPM
# build environment, all of our dependencies are checked out into
# directories at the same level as us.
if [ -d ../../build ] ; then
    PATH=$PATH:../../build
    srcdir=../..
else
    echo "Error: Could not find $(cd ../.. && pwd -P)/build/"
    exit 1
fi

export PATH

# Release and architecture to install
releasever=2
basearch=i386

usage()
{
    echo "Usage: build.sh [OPTION]..."
    echo "	-r release	Fedora release number (default: $releasever)"
    echo "	-a arch		Fedora architecture (default: $basearch)"
    echo "	-h		This message"
    exit 1
}

# Get options
while getopts "r:a:h" opt ; do
    case $opt in
	r)
	    releasever=$OPTARG
	    ;;
	a)
	    basearch=$OPTARG
	    ;;
	h|*)
	    usage
	    ;;
    esac
done

# Do not tolerate errors
set -e

VROOT=$PWD/PlanetLab-Bootstrap
install -d -m 755 $VROOT

# Some of the PlanetLab RPMs attempt to (re)start themselves in %post,
# unless the installation is running inside the BootCD environment. We
# would like to pretend that we are.
export PL_BOOTCD=1

# Install the "PlanetLab" group. This requires that the PlanetLab
# build system install the appropriate yumgroups.xml file (currently
# build/groups/v3_yumgroups.xml) in $RPM_BUILD_DIR/../RPMS/ and that
# mkfedora runs either yum-arch or createrepo on that directory. dev
# is specified explicitly because of a stupid bug in its %post script
# that causes its installation to fail; see the mkfedora script for a
# full explanation. coreutils and python are specified explicitly
# because groupinstall does not honor Requires(pre) dependencies
# properly, most %pre scripts require coreutils to be installed first,
# and some of our %post scripts require python.
mkfedora -v -r $releasever -a $basearch -p dev -p coreutils -p python -g PlanetLab $VROOT

# Disable unnecessary services
echo "* Disabling unnecessary services"
for service in netfs rawdevices cpuspeed smartd ; do
    /usr/sbin/chroot $VROOT /sbin/chkconfig $service off
done

# Build tarball
echo "* Building bootstrap tarball"
tar -cpjf PlanetLab-Bootstrap.tar.bz2 -C $VROOT .
rm -rf $VROOT

exit 0
