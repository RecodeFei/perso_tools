#!/bin/bash

function check_if_3rd_apk_has_lib {

    local apk=$1
    local apkdir=${apk%%.apk}

    mkdir -p $apkdir

    unzip -o -d $apkdir $apk lib/*  > /dev/null

    if [ ! -d "$apkdir/lib" ] ; then
        echo "$apk has no jni library to process, exiting now..."
        rm -rf $apkdir
    else
        pushd $apkdir/lib > /dev/null
        if [ -d "arm64-v8a" ] ; then
            mv arm64-v8a arm64
            rm -rf `ls | grep -v -e "^arm64$"`
        elif [ -d "armeabi-v7a" ] ; then
            mv armeabi-v7a arm
            rm -rf `ls | grep -v -e "^arm$"`
        elif [ -d "armeabi" ] ; then
            mv armeabi arm
            rm -rf `ls | grep -v -e "^arm$"`
        else
            echo "The apk didn't contain valid abi for arm device. exiting now ..."
            popd > /dev/null
            exit 1
        fi
        popd > /dev/null
        #zip -d $apk 'lib/*.so'
        zipalign -f 4 $apk $apkdir/$apk
        rm -f $apk
    fi

}

function optimization_one_app {
	if unzip -l $@ 'lib/*.so' >/dev/null ; then
	echo start
	rm -rf $(dir $@)uncompressedlibs && mkdir $(dir $@)uncompressedlibs;

	unzip $@ 'lib/*.so' -d $(dir $@)uncompressedlibs
	zip -d $@ 'lib/*.so'
	pushd $(dir $@)uncompressedlibs > /dev/null
	zip -D -r -0 ../$@ lib
	popd > /dev/null
	rm -rf $(dir $@)uncompressedlibs

	zipalign -f -p 4 $@ $@.tmp
	mv $@.tmp $@
	echo end
	fi
}

function search_and_optimization_all_3thd_apps {
    check_path=$(find $@ -name "*.apk" | while read -r line; do echo $(dirname $line); done | sort | uniq)
    for path in ${check_path[@]}
    do
        pushd $path > /dev/null
        ls | grep -E "*.apk" | while read -r line
        do
            optimization_one_app $line
        done
        popd > /dev/null
    done
}

rootpath=`pwd`
echo $rootpath
JRD_PRODUCT=$1
echo "JRD_PRODUCT: $JRD_PRODUCT"
ZZ_THIRD_APP_CONFIG=$rootpath/device/jrdchz/$JRD_PRODUCT/perso/zz_thirty_app.mk
REMOVEABLE_GMS_APP=$rootpath/device/jrdchz/$JRD_PRODUCT/perso/removeable_gms_app.mk
JRD_OUT_CUSTPACK_APP=$rootpath/out/target/product/$JRD_PRODUCT/system/custpack/app
JRD_OUT_SYSTEM=$rootpath/out/target/product/$JRD_PRODUCT/system
JRD_OUT_DATA=$rootpath/out/target/product/$JRD_PRODUCT/data
SRC_THIRD_APPS_DIR=$rootpath/device/jrdchz/$JRD_PRODUCT/perso/App
SRC_THIRD_APPS_DIR_UNREMOVEABLE=$rootpath/device/jrdchz/$JRD_PRODUCT/perso/App/Unremoveable
mkdir -p $rootpath/persoLog
JRD_LOG=$rootpath/persoLog
echo "$ZZ_THIRD_APP_CONFIG"
#optimization 3thd apps
search_and_optimization_all_3thd_apps $SRC_THIRD_APPS_DIR_UNREMOVEABLE
#process Removeable Apps
mkdir -p $JRD_OUT_CUSTPACK_APP/removeable
REMOVEABLE_APPS_DIRS=($(ls $SRC_THIRD_APPS_DIR/Removeable))
for REMOVEABLE_APPS_DIR in ${REMOVEABLE_APPS_DIRS[@]}
do
	APP_NAMES=($(find $SRC_THIRD_APPS_DIR/Removeable/$REMOVEABLE_APPS_DIR -type f -name "*.apk"))
	for APP_NAME in ${APP_NAMES[@]}
	do
		APP_NAME_BASE=$(basename $APP_NAME)
		if [ -n "`cat $ZZ_THIRD_APP_CONFIG | grep $APP_NAME_BASE`" ]; then
		cp $APP_NAME $JRD_OUT_CUSTPACK_APP/removeable
	fi
	done
done

#process Unremoveable Apps
mkdir -p $JRD_OUT_CUSTPACK_APP/unremoveable
UNREMOVEABLE_APPS_DIRS=($(ls $SRC_THIRD_APPS_DIR/Unremoveable | grep -v "Priv"))
for UNREMOVEABLE_APPS_DIR in ${UNREMOVEABLE_APPS_DIRS[@]}
do
	APP_NAMES=($(find $SRC_THIRD_APPS_DIR/Unremoveable/$UNREMOVEABLE_APPS_DIR -type f -name "*.apk"))
	for APP_NAME in ${APP_NAMES[@]}
	do
		APP_NAME_BASE=$(basename $APP_NAME)
		if [ -n "`cat $ZZ_THIRD_APP_CONFIG | grep $APP_NAME_BASE`" ]; then
		cp $APP_NAME $JRD_OUT_CUSTPACK_APP/unremoveable
	fi
	done
done

#process Unremoveable Priv-Apps
mkdir -p $JRD_OUT_CUSTPACK_APP/priv-app
UNREMOVEABLE_PRIV_APPS_DIRS=($(ls $SRC_THIRD_APPS_DIR/Unremoveable | grep "Priv"))
for UNREMOVEABLE_PRIV_APPS_DIR in ${UNREMOVEABLE_PRIV_APPS_DIRS[@]}
do
	APP_NAMES=($(find $SRC_THIRD_APPS_DIR/Unremoveable/$UNREMOVEABLE_PRIV_APPS_DIR -type f -name "*.apk"))
	for APP_NAME in ${APP_NAMES[@]}
	do
		APP_NAME_BASE=$(basename $APP_NAME)
		if [ -n "`cat $ZZ_THIRD_APP_CONFIG | grep $APP_NAME_BASE`" ]; then
		cp $APP_NAME $JRD_OUT_CUSTPACK_APP/priv-app
	fi
	done
done

 

#search_and_optimization_all_3thd_apps $JRD_OUT_CUSTPACK_APP
#for eachpath in $JRD_OUT_CUSTPACK_APP/priv-app $JRD_OUT_CUSTPACK_APP/unremoveable
#do
#pushd $eachpath > /dev/null
#ls | while read -r line
#do
#    check_if_3rd_apk_has_lib $line
#done
#popd > /dev/null
#done


#process GMS apk
all_gms_apks=($(find $rootpath/vendor/partner_gms/apps -type f -name "*.apk"))

if [ -f "$JRD_LOG/remove_gms_apks.log" ] ; then
     rm $JRD_LOG/remove_gms_apks.log
fi
echo "JRD_OUT_SYSTEM : $JRD_OUT_SYSTEM"
set -x
# remove apks in /system/app or /system/priv-app, when apk is not set in zz_third_app.mk 
for gms_apk in ${all_gms_apks[@]}
    
do
	gms_apk_name=$(basename $gms_apk)
	gms_apk_basename=$(echo $gms_apk_name | cut -d'.' -f1)
	gms_apk_basename=${gms_apk_basename%%_*}
	echo "$gms_apk_basename"
        if [ -d $JRD_OUT_SYSTEM/app/$gms_apk_basename ] ; then
            gms_apk_dirname=$JRD_OUT_SYSTEM/app/$gms_apk_basename
            gms_apk_fullpath=$JRD_OUT_SYSTEM/app/$gms_apk_basename/$gms_apk_basename.apk
        elif [ -d $JRD_OUT_SYSTEM/priv-app/$gms_apk_basename ] ; then
            gms_apk_dirname=$JRD_OUT_SYSTEM/priv-app/$gms_apk_basename
            gms_apk_fullpath=$JRD_OUT_SYSTEM/priv-app/$gms_apk_basename/$gms_apk_basename.apk
        elif [ -f $JRD_OUT_SYSTEM/app/$gms_apk_basename.apk ] ; then
            gms_apk_dirname=$JRD_OUT_SYSTEM/app/$gms_apk_basename.apk
            gms_apk_fullpath=$JRD_OUT_SYSTEM/app/$gms_apk_basename.apk
        elif [ -f $JRD_OUT_SYSTEM/priv-app/$gms_apk_basename.apk ] ; then
            gms_apk_dirname=$JRD_OUT_SYSTEM/priv-app/$gms_apk_basename.apk
            gms_apk_fullpath=$JRD_OUT_SYSTEM/priv-app/$gms_apk_basename.apk
        else
            echo "WARNING:CANNOT find $gms_apk_basename in /system"
            gms_apk_dirname=""
            gms_apk_fullpath=""
            continue
        fi
        if [ -n "$gms_apk_dirname" ] ; then
	    #grep $gms_apk_name $ZZ_THIRD_APP_CONFIG
            echo gms apk name is : $gms_apk_name
	    if [ -z "`cat $ZZ_THIRD_APP_CONFIG | grep "^\s*$gms_apk_basename*"`" ]; then
	   	rm -rf $gms_apk_dirname
		echo "apkfile_name: $gms_apk_fullpath $gms_apk_name" >> $JRD_LOG/remove_gms_apks.log
	    fi
        else
            echo "do nothing"
        fi

done

#process GMS offline language packages
languagePackageDir=$rootpath/vendor/partner_gms/apps/Velvet/OfflineVoiceRecognitionLanguagePacks
jrdTempProperties=$rootpath/out/target/common/perso/$JRD_PRODUCT/jrdResAssetsCust/jrd_sys_properties.prop
currentLang=`cat $jrdTempProperties | grep "ro.product.locale.language" | cut -d '=' -f2 | tr -d '\r'`
currentCountry=`cat $jrdTempProperties | grep "ro.product.locale.region" | cut -d '=' -f2 | tr -d '\r'`
currentCountryLower=`tr 'A-Z' 'a-z' <<<$currentCountry`
echo "currentLang: $currentLang   currentCountry: $currentCountry   currentCountryLower: $currentCountryLower"
if [ "$currentLang" == "zh" ]; then
   if [ "$currentCountry" == "CN" ]; then
	if [ -f $languagePackageDir/cmn-hans-cn-v2.zip ]; then
	mkdir -p $JRD_OUT_SYSTEM/usr/srec/cmn-Hans-CN
	unzip -o -q  $languagePackageDir/cmn-hans-cn-v2.zip -d $JRD_OUT_SYSTEM/usr/srec/cmn-Hans-CN/
	fi
   elif [ "$currentCountry" == "HK" ]; then
	if [ -f $languagePackageDir/yue-hant-hk-v2.zip ]; then
	mkdir -p $JRD_OUT_SYSTEM/usr/srec/yue-Hant-HK
	unzip -o -q  $languagePackageDir/yue-hant-hk-v2.zip -d $JRD_OUT_SYSTEM/usr/srec/yue-Hant-HK/
	fi
   elif [ "$currentCountry" == "TW" ]; then
	if [ -f $languagePackageDir/cmn-hant-tw-v2.zip ]; then
	mkdir -p $JRD_OUT_SYSTEM/usr/srec/yue-Hant-TW
	unzip -o -q  $languagePackageDir/cmn-hant-tw-v2.zip -d $JRD_OUT_SYSTEM/usr/srec/yue-Hant-TW/
	fi
   fi
else
   if [ -f $languagePackageDir/$currentLang-$currentCountryLower*.zip ]; then
	mkdir -p $JRD_OUT_SYSTEM/usr/srec/$currentLang-$currentCountry
	unzip -o -q $languagePackageDir/$currentLang-$currentCountryLower*.zip -d $JRD_OUT_SYSTEM/usr/srec/$currentLang-$currentCountry/
   fi
fi

set +x





