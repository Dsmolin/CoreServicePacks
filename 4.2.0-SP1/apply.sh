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


patch_apply() {
	local fail=""
	extra_args="$@"
	for x in `cat patches/series`; do 
		cat patches/$x | ( cd $ZENHOME; try patch -p3 -b -B ServicePacks/ $extra_args )
		if [ $? -ne 0 ]; then
			fail=$x
		fi
	done

	if [ -n "$fail" ]; then
		echo
		echo "Patch $x failed to apply."
		return 1
	fi
	return 0
}

patch_apply --dry-run
