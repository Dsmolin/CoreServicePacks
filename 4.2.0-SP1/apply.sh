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

real_apply=""
skip_apply=""
patch_apply() {
	local errval=$1
	shift
	local fail=""
	local optional
	if [ "$1" = "dry-run" ]; then
		extra_args="--dry-run"
		my_apply=`cat patches/series`
	else
		my_apply="$real_apply"
	fi
	for x in $my_apply; do 
		optional=no
		# patches with "opt-" prefix are optional -- someone may not have core ZenPacks installed, for example.
		# we attempt to apply them but don't fail 
		if [ "${x##-*}" = "opt" ]; then
			optional=yes
		fi
		cat patches/$x | ( cd $ZENHOME; try patch -p3 -b -B $BACKUPDIR/ $extra_args )
		if [ "$optional" = "no" ] && [ $? -gt $errval ]; then
			fail=$x
			if [ "$1" = "dry-run" ]; then
				skip_apply="$skip_apply $x"
			fi
			break
		fi
		# add to our list to apply later.
		if [ "$1" = "dry-run" ]; then
			real_apply="$real_apply $x"
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
