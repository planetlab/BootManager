#!/bin/bash
#
# Builds bootmanager.sh[.sgn], which is the PlanetLab Boot Manager script.
#
# The bootmanager.sh script contains in it a uuencoded tarball of the
# Boot Manager, customized for this PLC installation.
#
# Aaron Klingaman <alk@absarokasoft.com>
# Mark Huang <mlhuang@cs.princeton.edu>
# Marc E. Fiuczynski <mef@cs.princeton.edu>
# Copyright (C) 2004-2007 The Trustees of Princeton University
#
# $Id: build.sh,v 1.5 2006/04/03 19:40:55 mlhuang Exp $
#

# Source PLC configuration
if [ -f /etc/planetlab/plc_config ] ; then
    . /etc/planetlab/plc_config
else
    PLC_BOOT_HOST=boot.planet-lab.org
    PLC_API_HOST=www.planet-lab.org
    PLC_API_PATH=PLCAPI
fi

# Do not tolerate errors
set -e

NODEGROUP=$1

BOOTSTRAPDIR="/boot"
if [ -n "$NODEGROUP" ] ; then
	BOOTSTRAPDIR="/boot/$NODEGROUP"
fi


# Change to our source directory
srcdir=$(cd $(dirname $0) && pwd -P)

# Translate configuration file
sed -i -e "s|SUPPORT_FILE_DIR=.*|SUPPORT_FILE_DIR=$BOOTSTRAPDIR|" $srcdir/source/configuration

# Source bootmanager configuration
. $srcdir/source/configuration

# Write boot script. plc_www/boot/index.php writes this script out
# after a nonce check.

DEST_SCRIPT=bootmanager.sh
if [ -n "$NODEGROUP" ] ; then
	DEST_SCRIPT="${NODEGROUP}_bootmanager.sh"
	# Remove the old version or any sym links prior to re-writing
	rm -f ${DEST_SCRIPT}
	rm -f ${DEST_SCRIPT}.sgn
fi

cat > $DEST_SCRIPT <<EOF
#!/bin/bash
#
# PlanetLab Boot Manager $VERSION
#
# DO NOT EDIT. Generated by $USER@$HOSTNAME at
# $(date) 
#

# Do not tolerate errors
set -e

UUDECODE=/usr/bin/uudecode

# once we get the beta cds out of use, this can be removed
if [ ! -x \$UUDECODE ]; then
  UUDECODE=/tmp/uudecode
  curl -s http://$PLC_BOOT_HOST/boot/uudecode.gz | gzip -d -c > \$UUDECODE
  chmod +x \$UUDECODE
fi

EOF

echo '($UUDECODE | /bin/tar -C /tmp -xj) << _EOF_' >> $DEST_SCRIPT

# XXX Currently, the value of PLC_API_PORT is set to 80 by default, so
# that the portions of the web site that still use oldapi can continue
# to work. However, the Boot Manager supports HTTPS access, which we
# want to remain the default, so hard code 443 here.
sed -i -e "s@^BOOT_API_SERVER.*@BOOT_API_SERVER=https://$PLC_API_HOST:443/$PLC_API_PATH/@" \
    $srcdir/source/configuration

# Replace the default debug SSH key
if [ -f "$PLC_DEBUG_SSH_KEY_PUB" ] ; then
    install -D -m 644 "$PLC_DEBUG_SSH_KEY_PUB" $srcdir/source/debug_files/debug_root_ssh_key
fi

# Add pypcilib and pyplnet
extra_libs=`mktemp -d "/tmp/.bootmanager.XXXXXX"`
mkdir $extra_libs/source
cp -p $(rpm -ql pypcilib pyplnet | grep -v '\.py[co]$') $extra_libs/source

# Embed the uuencoded tarball in the script
tar -cj -C $srcdir source/ -C $extra_libs source/ | uuencode -m - >> $DEST_SCRIPT

# Remove temp directory
rm -fr $extra_libs

echo '_EOF_' >> $DEST_SCRIPT
echo 'cd /tmp/source' >> $DEST_SCRIPT
echo 'chmod +x BootManager.py && ./BootManager.py' >> $DEST_SCRIPT

# Sign the whole script, if the keyring is on this machine.
if [ -f "$PLC_ROOT_GPG_KEY" -a -f "$PLC_ROOT_GPG_KEY_PUB" ] ; then
    gpg --homedir=/root \
	--no-default-keyring \
	--keyring "$PLC_ROOT_GPG_KEY_PUB" \
	--secret-keyring "$PLC_ROOT_GPG_KEY" \
	--yes --sign --output $DEST_SCRIPT.sgn \
	$DEST_SCRIPT
else
    echo "Warning: Remember to sign $PWD/$DEST_SCRIPT!" >&2
fi
