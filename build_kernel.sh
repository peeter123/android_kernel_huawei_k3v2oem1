#!/bin/bash

###############################################################################
# To all DEV around the world :)                                              #
#                                                                             #
# 1.) use the "bash"                                                          #
# chsh -s /bin/bash `whoami`                                                  #
#                                                                             #
# 2.) load the ".config"                                                      #
# ./load_config.sh                                                            #
#                                                                             #
# 3.) clean the sources                                                       #
# ./clean_kernel.sh                                                           #
#                                                                             #
# 4.) now you can build my kernel                                             #
# ./build_kernel.sh                                                           #
#                                                                             #
# Have fun and update me if something nice can be added to my source.         #
###############################################################################

##################################################################
#
## export local variables
#
##################################################################

# location
if [ "${1}" != "" ]; then
	export KERNELDIR=`readlink -f ${1}`;
else
	export KERNELDIR=`readlink -f .`;
fi;

export PARENT_DIR=`readlink -f ${KERNELDIR}/../..`;
export INITRAMFS_SOURCE=`readlink -f ${KERNELDIR}/../initramfs`;
export INITRAMFS_TMP=/tmp/initramfs_source;
export CMDLINE='console=ttyS0 vmalloc=384M k3v2_pmem=1 mmcparts=mmcblk0:p1(xloader),p3(nvme),p4(misc),p5(splash),p6(oeminfo),p7(reserved1),p8(reserved2),p9(recovery2),p10(recovery),p11(boot),p12(modemimage),p13(modemnvm1),p14(modemnvm2),p15(system),p16(cache),p17(cust),p18(userdata);mmcblk1:p1(ext_sdcard)';


# kernel
export ARCH=arm;
export USE_SEC_FIPS_MODE=true;

# build script
export USER=`whoami`;
export HOST=`uname -n`;
export TMPFILE=`mktemp -t`;

chmod -R 777 /tmp;

# system compiler
# gcc x.x.x
# export CROSS_COMPILE=$PARENT_DIR/toolchain/bin/arm-none-eabi-;

# gcc 4.4.3 (CM9)
# export CROSS_COMPILE=/media/Source-Code/android/system/prebuilt/linux-x86/toolchain/arm-eabi-4.4.3/bin/arm-eabi-;

# gcc 4.6 (CM10)
#export CROSS_COMPILE=$PARENT_DIR/cm-11/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.6/bin/arm-linux-androideabi-;

# gcc 4.7 (CM11)
export CROSS_COMPILE=$PARENT_DIR/cm-11/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.7/bin/arm-linux-androideabi-;

# gcc 4.7 (Linaro 12.04)
# export CROSS_COMPILE=$PARENT_DIR/linaro/bin/arm-eabi-;

# gcc 4.7.2 (Linaro 12.07)
#export CROSS_COMPILE=$KERNELDIR/android-toolchain/bin/arm-eabi-;

## importing PATCH for GCC depend on GCC version
#GCCVERSION=`./scripts/gcc-version.sh ${CROSS_COMPILE}gcc`;


##################################################################
#
## check files and clean previous built
#
##################################################################


# check xml-config for "STweaks"-app
#XML2CHECK="${INITRAMFS_SOURCE}/res/customconfig/customconfig.xml";
#xmllint --noout $XML2CHECK;
#if [ $? == 1 ]; then
#	echo "xml-Error: $XML2CHECK";
#	exit 1;
#fi;

## compiler detection
#if [ "a$GCCVERSION" == "a0404" ]; then
#	cp $KERNELDIR/arch/arm/boot/compressed/Makefile_old_gcc $KERNELDIR/arch/arm/boot/compressed/Makefile;
#	echo "GCC 4.3.X Compiler Detected, building";
#elif [ "a$GCCVERSION" == "a0404" ]; then
#	cp $KERNELDIR/arch/arm/boot/compressed/Makefile_old_gcc $KERNELDIR/arch/arm/boot/compressed/Makefile;
#	echo "GCC 4.4.X Compiler Detected, building";
#elif [ "a$GCCVERSION" == "a0405" ]; then
#	cp $KERNELDIR/arch/arm/boot/compressed/Makefile_old_gcc $KERNELDIR/arch/arm/boot/compressed/Makefile;
#	echo "GCC 4.5.X Compiler Detected, building";
#elif [ "a$GCCVERSION" == "a0406" ]; then
#	cp $KERNELDIR/arch/arm/boot/compressed/Makefile_linaro $KERNELDIR/arch/arm/boot/compressed/Makefile;
#	echo "GCC 4.6.X Compiler Detected, building";
#elif [ "a$GCCVERSION" == "a0407" ]; then
#	cp $KERNELDIR/arch/arm/boot/compressed/Makefile_linaro $KERNELDIR/arch/arm/boot/compressed/Makefile;
#	echo "GCC 4.7.X Compiler Detected, building";
#elif [ "a$GCCVERSION" == "a0408" ]; then
#	cp $KERNELDIR/arch/arm/boot/compressed/Makefile_linaro $KERNELDIR/arch/arm/boot/compressed/Makefile;
#	echo "GCC 4.8.X Compiler Detected, building";
#else
#	echo "Compiler not recognized! please fix the 'build_kernel.sh'-script to match your compiler.";
#	exit 0;
#fi;


NUMBEROFCPUS=$(expr `grep processor /proc/cpuinfo | wc -l` + 1);
echo "slow system detected, setting $NUMBEROFCPUS build treads"


# read config
. $KERNELDIR/.config;

## get version from config
GETVER=`grep 'Mangusta86-.*-V' $KERNELDIR/.config | sed 's/.*".//g' | sed 's/-J.*//g'`;

# remove previous zImage files
if [ -e $KERNELDIR/zImage ]; then
	rm $KERNELDIR/zImage;
fi;
if [ -e $KERNELDIR/arch/arm/boot/zImage ]; then
	rm $KERNELDIR/arch/arm/boot/zImage;
fi;

# remove previous initramfs files
if [ -d $INITRAMFS_TMP ]; then
	echo "removing old temp initramfs_source";
	rm -rf $INITRAMFS_TMP;
fi;

# clean initramfs old compile data
rm -f $KERNELDIR/usr/initramfs_data.cpio;
rm -f $KERNELDIR/usr/initramfs_data.o;


# remove all old modules before compile
for i in `find $KERNELDIR/ -name "*.ko"`; do
	rm -f $i;
done;

##################################################################
#
## make modules and prepare ramdisk
#
##################################################################

#if [ $USER != "root" ]; then
#	make -j $NUMBEROFCPUS modules || exit 1;
#else
#	nice -n -15 make -j $NUMBEROFCPUS modules || exit 1;
#fi;
make modules || exit 1;

# copy initramfs files to tmp directory
cp -ax $INITRAMFS_SOURCE $INITRAMFS_TMP;

# create new image with version & date
#read -t 3 -p "create new kernel Image LOGO with version & date, 3sec timeout (y/n)?";
#echo "0" > $TMPFILE;
#if [ "$REPLY" == "y" ]; then
#	(
#		boot_image=$INITRAMFS_TMP/res/images/icon_clockwork.png;
#
#		convert -ordered-dither threshold,32,64,32 -pointsize 17 -fill white -draw "text 70,770 \"$GETVER [`date "+%H:%M | %d.%m.%Y"| sed -e ' s/\"/\\\"/g' `]\"" $boot_image $boot_image;
#
#		optipng -o7 -quiet $boot_image;
#
#		echo "1" > $TMPFILE;	
#	)&
#else
#	echo "1" > $TMPFILE;
#fi;    

# clear git repository from tmp-initramfs
if [ -d $INITRAMFS_TMP/.git ]; then
	rm -rf $INITRAMFS_TMP/.git;
fi;

# clear mercurial repository from tmp-initramfs
if [ -d $INITRAMFS_TMP/.hg ]; then
	rm -rf $INITRAMFS_TMP/.hg;
fi;

# remove empty directory placeholders from tmp-initramfs
for i in `find $INITRAMFS_TMP -name EMPTY_DIRECTORY`; do
	rm -f $i;
done;

# remove more from from tmp-initramfs ...
rm -f $INITRAMFS_TMP/compress-sql.sh;
rm -f $INITRAMFS_TMP/update*;

# copy modules into tmp-initramfs
mkdir -p $INITRAMFS_TMP/system/lib/modules;
for i in `find $KERNELDIR -name '*.ko'`; do
	cp -av $i $INITRAMFS_TMP/system/lib/modules/;
done;

## do not --strip-debug from wifi module
#mv $INITRAMFS_TMP/lib/modules/dhd.ko $INITRAMFS_TMP/lib/modules/dhd.tmp;
#for i in `find $INITRAMFS_TMP/lib/modules/ -name '*.ko'`; do
#	${CROSS_COMPILE}strip --strip-debug $i;
#done;
#mv $INITRAMFS_TMP/lib/modules/dhd.tmp $INITRAMFS_TMP/lib/modules/dhd.ko;

chmod 755 $INITRAMFS_TMP/system/lib/modules/*;

# wait for the boot-image
while [ $(cat ${TMPFILE}) == 0 ]; do
	sleep 2;
	echo "wait for image ...";
done;

#md5sum PAYLOAD/res/misc/payload/STweaks.apk | awk '{print $1}' > $INITRAMFS_TMP/res/stweaks_md5;
#chmod 644 $INITRAMFS_TMP/res/stweaks_md5;


##################################################################
#
## make kernel
#
##################################################################

## make kernel!!!
#if [ "$USER" != "root" ]; then
#	time make -j $NUMBEROFCPUS zImage CONFIG_INITRAMFS_SOURCE="$INITRAMFS_TMP";
#else
#	time nice -n -15 make -j $NUMBEROFCPUS zImage CONFIG_INITRAMFS_SOURCE="$INITRAMFS_TMP";
#fi;
make zImage ;


## restore clean arch/arm/boot/compressed/Makefile_clean till next time
#cp $KERNELDIR/arch/arm/boot/compressed/Makefile_clean $KERNELDIR/arch/arm/boot/compressed/Makefile;

if [ -e $KERNELDIR/arch/arm/boot/zImage ]; then
	cp $KERNELDIR/.config $KERNELDIR/arch/arm/configs/$KERNEL_CONFIG;

#	echo "Kernel size before payload!";
	echo "Kernel size";
	stat $KERNELDIR/arch/arm/boot/zImage || exit 1;

#	$KERNELDIR/mkshbootimg.py $KERNELDIR/zImage $KERNELDIR/arch/arm/boot/zImage $KERNELDIR/payload.tar.xz $KERNELDIR/recovery.tar.xz;

	# clean old files ...
	rm $KERNELDIR/OUTPUT/boot.img;
	rm $KERNELDIR/OUTPUT/Kernel_*;

	# copy all needed to ready kernel folder
	cp $KERNELDIR/.config $KERNELDIR/OUTPUT/;

	# compress ramdisk
    	cd $INITRAMFS_TMP;
 	find . | cpio -o -H newc | gzip > $KERNELDIR/ramdisk.cpio.gz
	cd $KERNELDIR;	

	# make boot image
        ./mkbootimg --cmdline '$CMDLINE' --kernel $KERNELDIR/arch/arm/boot/zImage --ramdisk $KERNELDIR/ramdisk.cpio.gz --base 0x00000000 --ramdiskaddr 0x01000000 --pagesize 2048 -o $KERNELDIR/OUTPUT/boot.img


	# create zip-file
	cd $KERNELDIR/OUTPUT/ && zip -r Kernel_${GETVER}-`date +"[%H-%M]-[%d-%m]-U9508-PWR-CORE"`.zip .;

	# push to android
	ADB_STATUS=`adb get-state`;
	if [ "$ADB_STATUS" == "device" ]; then
		read -t 3 -p "push kernel to android, 3sec timeout (y/n)?";
		if [ "$REPLY" == "y" ]; then
			adb push $KERNELDIR/OUTPUT/Kernel_*JB*.zip /sdcard/;
			read -t 3 -p "reboot to recovery, 3sec timeout (y/n)?";
			if [ "$REPLY" == "y" ]; then
				adb reboot recovery;
			fi;		
		fi;
	fi;
else
	# with red-color
	echo -e "\e[1;31mKernel STUCK in BUILD! no zImage exist\e[m"
fi;
