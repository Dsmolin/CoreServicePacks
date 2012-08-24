#!/bin/bash

die() {
	echo $*
	exit 1
}

try() {
	"$@"
	[ $? -ne 0 ] && exit 1
}

if [ ! -d "$ZENHOME" ]; then
	die "\$ZENHOME not set or does not exist. Please make sure you execute this script as the zenoss user."
fi

if [ "$USER" != "zenoss" ]; then
	die "Current user is $USER. Please execute as the zenoss user."
fi

TARGET_VERSION=4.2.0
SP=4.2.0-SP1
BACKUPDIR=$ZENHOME/ServicePacks/$SP
install -d $BACKUPDIR || die "Could not create backup directory $BACKUPDIR. Aborting."
export SIMPLE_BACKUP_SUFFIX=""

patch_apply() {
	local errval=$1
	shift
	local fail=""
	extra_args="$@"
	for x in `cat patches/series`; do 
		cat patches/$x | ( cd $ZENHOME; try patch -p3 -b -B $BACKUPDIR $extra_args )
		if [ $? -gt $errval ]; then
			fail=$x
			break
		fi
	done

	if [ -n "$fail" ]; then
		echo
		echo "Patch $x failed to apply."
		return 1
	fi
	return 0
}

revert() {
	echo
	echo "There was a problem applying patches. Reverting..."
	echo
	cd $BACKUPDIR || die "Couldn't change directories to $BACKUPDIR to revert patches."
	rsync -av $BACKUPDIR/ $ZENHOME/ || die "Revert failed."
	rm -rf "$BACKUPDIR"
	echo
	echo "Revert successful."
	exit 1
}

dry_run_patch_apply() {
	echo
	echo "Doing a dry-run patch application..."
	echo
	patch_apply 2 --dry-run || die "Dry-run failed. Maybe you are not running Zenoss ${TARGET_VERSION}?" 
}

real_patch_apply() {
	echo
	echo "Applying $SP..."
	echo
	patch_apply 1 
	if [ $? -ne 0 ]; then
		revert
	else
		echo "$SP" > $ZENHOME/ServicePacks/INSTALLED
	fi
}
echo "Stopping Zenoss..."
echo
try zenoss stop
dry_run_patch_apply
real_patch_apply
scripts/buildjs.sh || echo "Warning: Couldn't rebuild JavaScript."
cat << EOF

Service pack $SP applied successfully. Please type 'zenoss start' to restart Zenoss.

EOF
exit 0
