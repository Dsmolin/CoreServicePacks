#!/bin/sh
##############################################################################
# 
# Copyright (C) Zenoss, Inc. 2010, all rights reserved.
# 
# This content is made available according to terms specified in
# License.zenoss under the directory where your Zenoss product is installed.
# 
##############################################################################

# ERROR CODES
MISSING_JDK_1_6=4
CANNOT_MAKE_TEMP_DIR=5
MISSING_WGET_AND_CURL=6
MISSING_UNZIP=7
UNZIP_ERROR=8
ERROR_MOVING_JARFILE=9


do_exit(){
    echo $1
    exit $2
}

JAVA_CHECK=`java -version 2>&1 | grep "java version \"1.[6-9]"`
if [ -z "$JAVA_CHECK" ]; then
    which java
    do_exit "This script requires the Sun JDK 1.6 or greater." $MISSING_JDK_1_6
fi

if [ -z "$JSBUILDER" ]; then
    JSBUILDER=$ZENHOME/JSBuilder2.jar
    echo "\$JSBUILDER not set. Defaulting to $JSBUILDER."
fi

if [ ! -f "$JSBUILDER" ]; then
    echo "$JSBUILDER not found.  Attempting to download..."
    if [ ! -d ./jsbuildertmp ]; then
        mkdir jsbuildertmp || do_exit 'Unable to make temp directory. No permission?' $CANNOT_MAKE_TEMP_DIR
    fi
    WGET_COMMAND=`which wget`
    if [ -z "$WGET_COMMAND" ]; then
        CURL_COMMAND=`which curl`
        if [ -z "$CURL_COMMAND" ]; then
            do_exit 'wget or curl required for buildjs.sh' $MISSING_WGET_AND_CURL
        fi
        curl -L http://www.extjs.com/deploy/JSBuilder2.zip -o ./jsbuildertmp/JSBuilder2.zip
    else
        wget -O ./jsbuildertmp/JSBuilder2.zip http://www.extjs.com/deploy/JSBuilder2.zip
    fi
    UNZIP=`which unzip`
    if [ -z "$UNZIP" ]; then
        do_exit "Unzip not available to unzip JSBuilder2.zip" $MISSING_UNZIP
    fi
    unzip -o ./jsbuildertmp/JSBuilder2.zip -d ./jsbuildertmp || \
        do_exit "Error unzipping JSBuilder2.zip" $UNZIP_ERROR
    mv ./jsbuildertmp/JSBuilder2.jar $JSBUILDER || \
        do_exit "Error moving JSBuilder2.jar to $JSBUILDER" $ERROR_MOVING_JARFILE
    rm -rf ./jsbuildertmp
fi

JSHOME=$DESTDIR$ZENHOME/Products/ZenUI3/browser
java -jar $JSBUILDER -p $JSHOME/zenoss.jsb2 -d $JSHOME -v
