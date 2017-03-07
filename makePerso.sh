#!/bin/bash
# Script to build perso image
#

export PS4="+ [\t] "
set -o errexit

usage() {
  echo "Usage: `readlink -f $0` -p TARGET_PRODUCT -t TOP folder -s ORIGIN_SYSTEM_IMAGE_PATH -u ORIGIN_USERDATA_IMAGE_PATH -m TARGET_THEME -v PERSO_VERSION -n IFSIGNAL"
  echo "Example: `readlink -f $0` -p pixi45 -t . -s system.img -u userdata.img -m DNA -v Y3H1ZZ40BG00"
  exit 1
}

traperror () {
    local errcode=$?
    local lineno="$1"
    local funcstack="$2"
    local linecallfunc="$3"

    echo "ERROR: line ${lineno} - command exited with status: ${errcode}"
    if [ "${funcstack}" != "" ]; then
        echo -n "Error at function ${funcstack[0]}() "
        if [ "${linecallfunc}" != "" ]; then
            echo -n "called at line ${linecallfunc}"
        fi
        echo
    fi
}

# Get the exact value of a build variable.
function get_build_var()
{
    CALLED_FROM_SETUP=true BUILD_SYSTEM=build/core \
      command make --no-print-directory -f build/core/config.mk dumpvar-$1
}

function override_exist_folder {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    # $1 target file folder
    # $2 source file folder
    local target_folder=$1
    if [ ! -d $target_folder ] ; then
        mkdir -p $target_folder
    fi
    # Only copy files that already present at media folder before.
    for target_file in `ls $target_folder`
    do
        local source_file=$2/$target_file
        if [ ! -L $target_folder/$target_file ] && [ -f $target_folder/$target_file ] && [ -f $source_file ] ; then
            cp -f $source_file $target_folder
        fi
    done
    trap - ERR
}

function override_exist_file {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    # $1 target file
    # $2 source file
    local target_file=$1
    local source_file=$2
    if [ -f $source_file ] ; then
        cp -f $source_file $target_file
    fi
    trap - ERR
}

function prepare_parseAloneApp {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "now parseAloneApp"
    allAloneApp=`find $TOP/vendor/jrdchz/proprietary/aloneApp -name '*.apk'`
    for aloneApp in $allAloneApp
    do
       aloneAppPath=`dirname $aloneApp`
       apktool d -f $aloneApp $JRD_ALONE_TEMP
       cp -rf $JRD_ALONE_TEMP/* $aloneAppPath
    done
    trap - ERR
}

keyXmls=(donottranslate-cldr.xml donottranslate.xml)
function prepare_copyOriginResource {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "now copy origin resource"
    local_config=$JRD_WIMDATA/$JRD_PRODUCT/perso/local.config
    entrylocal=`cat $local_config | grep "^[^#]" | cut -d ',' -f3 | sed 's/[[:space:]]//g'`
    for modulePath in $MY_RES_DIR
    do
	echo "modulePath=$modulePath"
	if [ -d "$TOP/$modulePath" ]; then
	mkdir -p $JRD_CUSTOM_RES/$modulePath
	#allValues=`find $TOP/$modulePath -type d -name "values-*"`
        for keyXml in ${keyXmls[@]}
	do
	   if [ -f "$TOP/$modulePath/values/$keyXml" ]; then
	   mkdir -p $JRD_CUSTOM_RES/$modulePath/values
	   cp -f $TOP/$modulePath/values/$keyXml $JRD_CUSTOM_RES/$modulePath/values/$keyXml
	   fi
	   for entryValue in $entrylocal
	   do
		if [ -f "$TOP/$modulePath/values-$entryValue/$keyXml" ]; then
		mkdir -p $JRD_CUSTOM_RES/$modulePath/values-$entryValue
		cp -f $TOP/$modulePath/values-$entryValue/$keyXml $JRD_CUSTOM_RES/$modulePath/values-$entryValue/$keyXml
		fi
	   done
	done
	fi
	
    done
    trap - ERR
}

function prepare_translations {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "now creating the strings.xml from the strings.xls"
    if [ ! -d $JRD_CUSTOM_RES ] ; then
        mkdir -p $JRD_CUSTOM_RES
    fi
    if [ -f $JRD_WIMDATA/$JRD_PRODUCT/perso/string_res.ini ] && [ -f $JRD_WIMDATA/common/perso/wlanguage/src/strings.xls ] ; then
        $JRD_TOOLS_ARCT w -LM -I $JRD_WIMDATA/$JRD_PRODUCT/perso/string_res.ini -c $JRD_WIMDATA/$JRD_PRODUCT/perso/local.config -o $JRD_CUSTOM_RES $JRD_WIMDATA/common/perso/wlanguage/src/strings.xls $TOP > /dev/null
    else
        echo "Can't find string.xls file."
    fi
    trap - ERR
}

function prepare_mtkBtResource {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "now create mtkBtResource"
    set -x
    local mtkBTPath=$TOP/vendor/mediatek/proprietary/packages/apps/Bluetooth
    local mtkTool=$mtkBTPath/build/blueangel.py
    local manifest=$mtkBTPath/build/AndroidManifest.xml
    local manifestConfig=$mtkBTPath/build/AndroidManifest.tpl
    local moduleManifests=`find $mtkBTPath -name AndroidManifest.xml`
    local manifestOutputPath=$JRD_CUSTOM_RES/vendor/mediatek/proprietary/packages/apps/Bluetooth
    rm -rf $manifestOutputPath/build/res
    mkdir -p $manifestOutputPath/build/res

    for mtkBtMoude in `ls $manifestOutputPath | grep -v 'build'`
    do
	for x in `ls $manifestOutputPath/$mtkBtMoude`
	do
	    allvaluedirs=`find $manifestOutputPath/$mtkBtMoude/$x/res -type d -name 'values-*'`
	    for eachItemdir in $allvaluedirs
	    do
		entryvalue=`basename $eachItemdir`
		mkdir -p $manifestOutputPath/build/res/$entryvalue
		for eachItemFile in `find $eachItemdir -type f -name '*.xml'`
		do
		   cp -f $eachItemFile $manifestOutputPath/build/res/$entryvalue
		done
	    done
	done
	
    done
    
    generateMtkBtManifest
    set +x
    trap - ERR
}

function generateMtkBtManifest {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "now generateMtkBtManifest"
    rm -rf $manifest
    if [ -f $mtkTool ] && [ -f $manifestConfig ]; then
    python $mtkTool $mtkBTPath/build
    fi
    trap - ERR
}

function prepare_photos {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "now building the customized icons..."
    if [ -f "$JRD_WIMDATA/$JRD_PRODUCT/perso/Photos/images.zip" ] ; then
        unzip -o -q $JRD_WIMDATA/$JRD_PRODUCT/perso/Photos/images.zip -d $JRD_CUSTOM_RES
    fi
    trap - ERR
}

function prepare_ringtone {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "now building the customized audio..."
    local audio_folder=$JRD_OUT_SYSTEM/media/audio
    if [ ! -d $audio_folder ] ; then
        mkdir -p $audio_folder
    else
        clean_intermediates_folder $audio_folder
    fi
    mkdir -p $audio_folder/alarms
    mkdir -p $audio_folder/notifications
    mkdir -p $audio_folder/ringtones
    mkdir -p $audio_folder/switch_on_off
    mkdir -p $audio_folder/ui
    mkdir -p $audio_folder/cb_ring

    #delete the origin ringtone files firstly
    pushd $audio_folder > /dev/null
    if [ `find . -type f | xargs rm` ] ; then
        echo "Didn't find any audio files, go on ..."
    fi
    popd > /dev/null

    #unzip audio.zip to target path
    unzip -o -q $JRD_WIMDATA/$JRD_PRODUCT/perso/Audios/audios.zip -d $JRD_CUSTOM_RES
    echo "xxxxxxxxxxxxxxxxxxxx,$JRD_WIMDATA/$JRD_PRODUCT/perso/Audios/audios.zip,xxxxxxxxxx$JRD_CUSTOM_RES"
    cp $JRD_CUSTOM_RES/frameworks/base/data/sounds/Alarm/*          $audio_folder/alarms
    cp $JRD_CUSTOM_RES/frameworks/base/data/sounds/Notification/*   $audio_folder/notifications
    cp $JRD_CUSTOM_RES/frameworks/base/data/sounds/Ringtones/*      $audio_folder/ringtones
    cp $JRD_CUSTOM_RES/frameworks/base/data/sounds/Switch_On_Off/*  $audio_folder/switch_on_off
    cp $JRD_CUSTOM_RES/frameworks/base/data/sounds/UI/*             $audio_folder/ui
    cp $JRD_CUSTOM_RES/frameworks/base/data/sounds/CB_Ring/*        $audio_folder/cb_ring
    trap - ERR
}

function prepare_fonts {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "now building the customized fonts..."
    #TODO: customize fonts

    trap - ERR
}

function prepare_3rd_party_apk {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "process 3rd apk..."
    #local apk_path
    #local apk_cmd
    #local all_gms_apks

    set -x

    #remove all apk in /system/custpack/app
    clean_intermediates_folder $JRD_OUT_CUSTPACK/app
    #parse command from jrd_build_apps.mk and run command one by one
    #cat $JRD_BUILD_PATH_DEVICE/perso/buildres/jrd_build_apps.mk | sed -e 's/#.*//g' | while read -r line
    #do
    #    if ( echo $line | grep -q "mkdir" ) ; then
    #        apk_path=$(echo $line | awk '{print "mkdir -p "$4}' | sed -e s'/(//g' -e s'/)//g')
    #        if [ -n "$apk_path" ] ; then
    #            eval $apk_path
    #        fi
    #    elif ( echo $line | grep -q "cp" ) ; then
    #        apk_cmd=$(echo $line | awk '{print $2 " " $3 " " $4}' | sed -e s'/(//g' -e s'/)//g')
    #        eval $apk_cmd
    #    fi
    #done
###########################################################################################################
    	
    $SCRIPTS_DIR/process_thirdapk.sh $JRD_PRODUCT

    set +x

    trap - ERR
}

function prepare_standalone_apk {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR

    trap - ERR
}

function prepare_media {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    #$(hide) cp $(JRD_WIMDATA)/wcustores/Media/$(TARGET_PRODUCT)/* $(PRODUCT_OUT)/system/media
    echo "now copy boot/shutdown animation.gif..."
    override_exist_folder $PRODUCT_OUT/system/media $JRD_WIMDATA/$JRD_PRODUCT/perso/Media
    trap - ERR
}

function prepare_plfs {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "now process plf to xml..."
    local $PLF_FILES

    PLF_PARSE_TOOL=$TOP/vendor/jrdchz/build/tools/prd2xml

    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PLF_PARSE_TOOL

    set -x

    pushd $TOP > /dev/null

    for folder in ${MY_PLF_FILE_FOLDER[@]}
    do
	echo "parse plf fold : $folder"
        if [ -d "$folder" ] ; then
            PLF_FILES=($(find $folder -type f -name '*.plf'))
        fi
        for plf in ${PLF_FILES[@]}
        do
	    echo "parse plf file : $plf"
            PLF_TARGET_XML_FOLDER=$JRD_CUSTOM_RES/$(dirname $plf)/res/values
            mkdir -p $PLF_TARGET_XML_FOLDER
            PLF_TARGET_XML_TMP=$(basename $TOP/$plf)
            PLF_TARGET_XML=${PLF_TARGET_XML_TMP%.*}_android.xml
            echo "xxx$PLF_TARGET_XML"
            
            python $PLF_PARSE_TOOL/writeSdmToXML.py $PLF_TARGET_XML_FOLDER/$PLF_TARGET_XML $TOP/$plf
        done
    done

    popd > /dev/null

    set +x
    trap - ERR
}

function prepare_launcher_workspace {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "now building launcher workspace..."
    # copy launcher workspace to out $JRD_CUSTOM_RES folder
    # TODO: the path of workspace.xml file are different for some projects which not use the standalone launcher
    #local workspace=device/tct/$TARGET_PRODUCT/perso/jrd_default_workspace.xml
    #local workspace=vendor/tctalone/TctAppPackage/Launcher/res/xml/jrd_default_workspace.xml
    #local attrs=vendor/tctalone/TctAppPackage/Launcher/res/values/attrs.xml
    #if [ -f $TOP/$workspace ]; then
    #    mkdir -p $(dirname $JRD_CUSTOM_RES/$workspace)
        #mkdir -p $(dirname $JRD_CUSTOM_RES/$attrs)
    #    cp -f $TOP/$workspace $JRD_CUSTOM_RES/$workspace
    #    cat $JRD_CUSTOM_RES/$workspace | grep -E "<\s*favorites" | sed -i -E 's|/com.[^"]*|&.overlay|' $JRD_CUSTOM_RES/$workspace
        #cp -f $TOP/$attrs $JRD_CUSTOM_RES/$attrs
    #else
    #    echo "Can't find Launcher workspace file, exiting now..."
    #    exit
    #fi
    local respath=$JRD_WIMDATA/$JRD_PRODUCT/perso/LanucherRes

    if [ -f $respath/extra_wallpapers.xml ] && [ -f $respath/jrd_default_workspace.xml ]; then
        mkdir -p $JRD_CUSTOM_RES/vendor/jrdchz/proprietary/packages/apps/LauncherM/res/xml
	mkdir -p $JRD_CUSTOM_RES/vendor/jrdchz/proprietary/packages/apps/LauncherM/res/values
	#mkdir -p $JRD_CUSTOM_RES/packages/apps/SimpleHomeScreen/res/xml
	#mkdir -p $JRD_CUSTOM_RES/packages/apps/SimpleHomeScreen/res/values
        cp -f $respath/jrd_default_workspace.xml $JRD_CUSTOM_RES/vendor/jrdchz/proprietary/packages/apps/LauncherM/res/xml/jrd_default_workspace.xml
	#cat $JRD_CUSTOM_RES/vendor/jrdchz/proprietary/packages/apps/Launcher3/res/xml/jrd_default_workspace.xml | grep -E "<\s*favorites" | \
	#sed -i -E 's|/com.[^"]*|&.overlay|' $JRD_CUSTOM_RES/vendor/jrdchz/proprietary/packages/apps/LauncherM/res/xml/jrd_default_workspace.xml
	#cp -f $respath/default_toppackage_launcher3.xml $JRD_CUSTOM_RES/packages/apps/Launcher3/res/xml/default_toppackage_launcher3.xml
	#cat $JRD_CUSTOM_RES/packages/apps/Launcher3/res/xml/default_toppackage_launcher3.xml | grep -E "<\s*toppackages" | \
	#sed -i -E 's|/com.[^"]*|&.overlay|' $JRD_CUSTOM_RES/packages/apps/Launcher3/res/xml/default_toppackage_launcher3.xml
        cp -f $TOP/vendor/jrdchz/proprietary/packages/apps/LauncherM/res/values/attrs.xml $JRD_CUSTOM_RES/vendor/jrdchz/proprietary/packages/apps/LauncherM/res/values/attrs.xml
        cp -f $respath/extra_wallpapers.xml $JRD_CUSTOM_RES/vendor/jrdchz/proprietary/packages/apps/LauncherM/res/values/extra_wallpapers.xml
	#cp -f $respath/default_toppackage.xml $JRD_CUSTOM_RES/packages/apps/SimpleHomeScreen/res/xml/default_toppackage.xml
	#cat $JRD_CUSTOM_RES/packages/apps/SimpleHomeScreen/res/xml/default_toppackage.xml | grep -E "<\s*toppackages" | \
	#sed -i -E 's|/com.[^"]*|&.overlay|' $JRD_CUSTOM_RES/packages/apps/SimpleHomeScreen/res/xml/default_toppackage.xml
	#cp -f $TOP/packages/apps/SimpleHomeScreen/res/values/attrs.xml $JRD_CUSTOM_RES/packages/apps/SimpleHomeScreen/res/values/attrs.xml
    fi
    trap - ERR
}

function project_support_nfc_remove {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "project_support_nfc_remove"
    rm -fr $JRD_OUT_SYSTEM/etc/permissions/com.nxp.mifare.xml 
    rm -fr $JRD_OUT_SYSTEM/etc/permissions/com.android.nfc_extras.xml 
    rm -fr $JRD_OUT_SYSTEM/etc/permissions/android.hardware.nfc.xml 
    rm -fr $JRD_OUT_SYSTEM/etc/permissions/android.hardware.nfc.hce.xml 
    rm -fr $JRD_OUT_SYSTEM/etc/permissions/android.hardware.nfc.hcef.xml 
    rm -fr $JRD_OUT_SYSTEM/etc/permissions/org.simalliance.openmobileapi.xml 
    rm -fr $JRD_OUT_SYSTEM/etc/nfcee_access.xml 
    rm -fr $JRD_OUT_SYSTEM/app/NfcNci
    rm -fr $JRD_OUT_SYSTEM/app/SmartcardService
    rm -fr $JRD_OUT_SYSTEM/framework/org.simalliance.openmobileapi.jar 
    rm -fr $JRD_OUT_SYSTEM/app/UiccTerminal 
    rm -fr $JRD_OUT_SYSTEM/etc/permissions/com.gsma.services.nfc.xml
    trap - ERR
}

function prepare_sign_tool {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "prepare test-key tool"
    mkdir -p $TOP/out/host/linux-x86/framework
    cp $SCRIPTS_DIR/persoTools/signapk.jar $TOP/out/host/linux-x86/framework
    chmod 755 $TOP/out/host/linux-x86/framework/signapk.jar
    trap - ERR
}

function prepare_wifi {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "now building the wifi files"
    override_exist_file $JRD_OUT_SYSTEM/etc/wifi/wpa_supplicant.conf $TOP/device/tct/$JRD_PRODUCT/wpa_supplicant.conf
    trap - ERR
}

function prepare_agps {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "now prepare the apgs_config"
    override_exist_file $JRD_OUT_SYSTEM/vendor/etc/agps_profiles_conf2.xml $TOP/device/jrdchz/$JRD_PRODUCT/perso/agps_profiles_conf2.xml 
    trap - ERR
}

function prepare_appmanager {
    if [ -f $TOP/device/jrdchz/$JRD_PRODUCT/appmanager.conf ]; then
        echo "now copy appmanager.conf"
        cp $TOP/device/jrdchz/$JRD_PRODUCT/appmanager.conf $JRD_OUT_SYSTEM/etc
    fi
}

function prepare_plmn {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "now building the plmn files"
    override_exist_file $JRD_OUT_CUSTPACK/plmn-list.conf $JRD_WIMDATA/$JRD_PRODUCT/perso/plmn-list.conf
    trap - ERR
}

function prepare_apn {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "now building the apn files"
    #mixed the apns-conf.xml apns-conf-ia.xml
    if [ -f $JRD_WIMDATA/$JRD_PRODUCT/perso/apns-conf.xml ] && [ -f $JRD_WIMDATA/$JRD_PRODUCT/perso/apns-conf-ia.xml ]; then
	cat $JRD_WIMDATA/$JRD_PRODUCT/perso/apns-conf.xml > $JRD_WIMDATA/$JRD_PRODUCT/perso/apns-conf-temp.xml
	sed -i -e '/<\/apns>/d' $JRD_WIMDATA/$JRD_PRODUCT/perso/apns-conf-temp.xml
	cat $JRD_WIMDATA/$JRD_PRODUCT/perso/apns-conf-ia.xml >> $JRD_WIMDATA/$JRD_PRODUCT/perso/apns-conf-temp.xml
	echo "</apns>" >> $JRD_WIMDATA/$JRD_PRODUCT/perso/apns-conf-temp.xml
	mv $JRD_WIMDATA/$JRD_PRODUCT/perso/apns-conf-temp.xml $JRD_WIMDATA/$JRD_PRODUCT/perso/apns-conf.xml
    fi
    override_exist_file $JRD_OUT_SYSTEM/etc/apns-conf.xml $JRD_WIMDATA/$JRD_PRODUCT/perso/apns-conf.xml
    trap - ERR
}

function get_product_aapt_config {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    default_aapt_config="normal,xxhdpi,xhdpi,hdpi,nodpi,anydpi"
    if [ -f $1 ] ; then
        language_list=$(read_variable_from_makefile "PRODUCT_LOCALES" $1)
        echo $(echo ${language_list[@]} | tr -s [:space:] ',')$default_aapt_config
    else
        echo "Can't find jrd_build_properties.mk, exiting now ... "
        exit 1
    fi

    trap - ERR
}

function replace_properties {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    local prop=$1
    local new_value=$2
    local origin=$3
    local target=$4

    origin_prop_value_pair=`echo "$origin" | grep -e "^$prop=" | head -n 1`
    origin_value=${origin_prop_value_pair#$prop=}
    if [ "$origin_value" != "$new_value" ] ; then
        set -x
        echo "replace value for $prop"
        origin_prop_value_pair=${origin_prop_value_pair//\//\\\/}
        new_value=${new_value//\//\\\/}
        #TODO: the prop value can't contain '/', '\'.
        sed -i -e 's/'"$origin_prop_value_pair"'/'$prop'='"$new_value"'/' $target
        set +x
    fi
    trap - ERR
}

# build.prop is combined by four parts:
#   1. from build/tools/buildinfo.sh
#   2. from device/tct/$product/system.prop
#   3. from Jrd_sys_properties.prop
#   4. from ADDITIONAL_BUILD_PROPERTIES defined in *.mk
function prepare_build_prop {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR

    echo "Now buiding build.prop ... "
    local build_prop=$JRD_OUT_SYSTEM/build.prop
    local jrd_build_prop_mk=$JRD_CUSTOM_RES/jrd_build_properties.mk
    local jrd_sys_prop=$JRD_CUSTOM_RES/jrd_sys_properties.prop
    if [ ! -f $build_prop ] || [ ! -f $jrd_build_prop_mk ] || [ ! -f $jrd_sys_prop ] ; then
        echo "can't find build.prop file, exiting now ..."
        exit
    fi
    # replace properties from jrd_build_properties.mk, which generated by buildinfo.sh generally
    local PRODUCT_MODEL=$(read_variable_from_makefile "PRODUCT_MODEL" $jrd_build_prop_mk)
    local PRODUCT_BRAND=$(read_variable_from_makefile "PRODUCT_BRAND" $jrd_build_prop_mk)
    local PRODUCT_MANUFACTURER=$(read_variable_from_makefile "PRODUCT_MANUFACTURER" $jrd_build_prop_mk)
    local TCT_PRODUCT_DEVICE=$(read_variable_from_makefile "TCT_PRODUCT_DEVICE" $jrd_build_prop_mk)
    local TCT_PRODUCT_NAME=$(read_variable_from_makefile "TCT_PRODUCT_NAME" $jrd_build_prop_mk)

    local PROJECT_SUPPORT_NFC=$(read_variable_from_makefile "PROJECT_SUPPORT_NFC" $jrd_build_prop_mk)
    echo "PROJECT_SUPPORT_NFC=$PROJECT_SUPPORT_NFC"
    if [ $PROJECT_SUPPORT_NFC != "YES"  ] ; then
        project_support_nfc_remove 
    fi

    
    local svn_ori=`grep "ro.def.software.svn" $jrd_sys_prop | cut -d'=' -f2`
    local svn=${svn_ori:0:3}
    local cvn=${svn_ori:3:4}
    local oldfingerprint=`grep "ro.build.fingerprint" $build_prop | cut -d'=' -f2`
    local temp1=`echo $oldfingerprint | cut -d':' -f2`
    local temp2=`echo $oldfingerprint | cut -d':' -f3`
    #PRODUCT_MODEL->TCT_PRODUCT_NAME
    local newfingerprint=$PRODUCT_BRAND/`echo $TCT_PRODUCT_NAME | sed -e 's/ //g'`/$TCT_PRODUCT_DEVICE:$temp1:$temp2

    origin_build_prop=$(cat $build_prop)
    replace_properties "ro.product.model" "$PRODUCT_MODEL" "$origin_build_prop" $build_prop
    #replace_properties "ro.product.name" "`echo $PRODUCT_MODEL | sed -e 's/ //g'`" "$origin_build_prop" $build_prop
    replace_properties "ro.product.name" "$TCT_PRODUCT_NAME" "$origin_build_prop" $build_prop
    replace_properties "ro.product.brand" "$PRODUCT_BRAND" "$origin_build_prop" $build_prop
    #replace_properties "ro.product.device" "$TARGET_PRODUCT" "$origin_build_prop" $build_prop
    replace_properties "ro.product.device" "$TCT_PRODUCT_DEVICE" "$origin_build_prop" $build_prop
    replace_properties "ro.build.product" "$JRD_PRODUCT" "$origin_build_prop" $build_prop
    replace_properties "ro.product.manufacturer" "$PRODUCT_MANUFACTURER" "$origin_build_prop" $build_prop
    replace_properties "ro.build.date" "`date`" "$origin_build_prop" $build_prop
    replace_properties "ro.build.date.utc" "`date +%s`" "$origin_build_prop" $build_prop
    replace_properties "ro.build.user" "$USER" "$origin_build_prop" $build_prop
    replace_properties "ro.build.host" "`hostname`" "$origin_build_prop" $build_prop
    replace_properties "ro.build.fingerprint" "$newfingerprint" "$origin_build_prop" $build_prop
    #replace_properties "ro.tct.product" "$JRD_PRODUCT" "$origin_build_prop" $build_prop
    #replace_properties "ro.build.vbd" "$PRODUCT_MANUFACTURER/$svn/$cvn" "$origin_build_prop" $build_prop
    #replace_properties "ro.def.software.svn" "${svn_ori}" "$origin_build_prop" $build_prop
    #TODO: check fingerprint
    #replace_properties "ro.build.fingerprint" `date +%s` $origin_build_prop $build_prop
    #replace_properties "ro.build.description" `date +%s` $origin_build_prop $build_prop
    #replace_properties "ro.build.display.id" `date +%s` $origin_build_prop $build_prop

    # replace properties from jrd_sys_properties.prop
    cat $jrd_sys_prop | while read -r readline
    do
        if [ $(echo $readline | grep -o -e "^[^#]*=") ] ; then
            local prop=$(echo $readline | cut -d'=' -f1)
            local value=${readline#$prop=}
            value=$(echo $value | tr -d '\r\n')
            sed -i -e /$prop=.*/d $build_prop ;
        fi
    done
    cat $jrd_sys_prop | tee -a $build_prop

    trap - ERR
}

function prepare_theme {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    #TODO: build theme packages.
    echo "now copy the theme"
    clean_intermediates_folder $THEME_OUT_PATH/theme
    mkdir -p $THEME_OUT_PATH/theme
    cp -rf $THEME_RESOUCE_PATH/* $THEME_OUT_PATH/theme
    trap - ERR
}

function prepare_usermanual {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "now building the customized user manuals..."
    override_exist_folder $JRD_OUT_CUSTPACK/JRD_custres/user_manual $JRD_WIMDATA/$JRD_PRODUCT/perso/UserManual
    trap - ERR
}

function get_package_name {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    if [ -d $2/$3 ] ; then
        if [ -f $1/$3/AndroidManifest.xml ] ; then
            cat $1/$3/AndroidManifest.xml | grep -o -e 'package="[_0-9a-zA-Z.]*"' | cut -d'=' -f2 | tr -d \" | sed 's/\.overlay//'
        else
            apklist=($(find $1/$3 -type f -name '*.apk'))
            if [ ${#apklist[@]} -eq 1 ] ; then
                echo $($MY_AAPT_TOOL d --values permissions $apklist | head -n 1 | cut -d" " -f2)
            elif [ ${#apklist[@]} -lt 1 ] ; then
                echo "WARNNING:NO APK exist."
            else
                echo "ERROR:Duplicated APK exist."
                exit 1
            fi
        fi
    fi
    trap - ERR
}

function get_core_app {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
        if [ -f $1/$2/AndroidManifest.xml ] ; then
            echo $(cat $1/$2/AndroidManifest.xml | grep -o -e 'coreApp="true"')
        else
            apklist=($(find $1/$2 -type f -name '*.apk'))
            if [ ${#apklist[@]} -eq 1 ] ; then
                echo $($MY_AAPT_TOOL l -v -a -M AndroidManifest.xml $apklist | grep coreApp=\(type\ 0x12\)0xffffffff\ \(Raw:\ \"true\"\))
            elif [ ${#apklist[@]} -lt 1 ] ; then
                echo "WARNNING:NO APK exist."
            else
                echo "ERROR:Duplicated APK exist."
                exit 1
            fi
        fi
    trap - ERR
}

function get_local_package_name {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    if [ -f $1/Android.mk ] ; then
	if [[ "$1" =~ "aloneApp" ]] ; then
	    name=$(read_variable_from_makefile "LOCAL_MODULE" $1/Android.mk)
	    echo $name
	    return
	fi
        name=$(read_variable_from_makefile "LOCAL_PACKAGE_NAME" $1/Android.mk)
        # if more than one package name found, remove override package
        if [ $(echo $name | wc -w) -gt 1 ] ; then
            override=$(read_variable_from_makefile "LOCAL_OVERRIDES_PACKAGES" $1/Android.mk)
            if [ -n "$override" ] && [ "$(echo $name | grep $override)" ] ; then
                echo ${name/$override/}
            fi
        elif [ -z "$name" ] || [[ "$1" =~ "TctAppPackage" ]] ; then
            name=$(read_variable_from_makefile "LOCAL_MODULE" $1/Android.mk)
            echo $name
        else
            echo $name
        fi
    fi
    trap - ERR
}

function get_local_certificate {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    local is_privileged_module=""
    if [ -f $1/Android.mk ] ; then
        name=$(read_variable_from_makefile LOCAL_CERTIFICATE $1/Android.mk)

        if [ "$name" == "PRESIGNED" ] && [[ "$1" =~ "aloneApp" ]] ; then
            is_privileged_module=$(read_variable_from_makefile "LOCAL_PRIVILEGED_MODULE" $1/Android.mk)
            if [ "$is_privileged_module" == "true" ] ; then
                name=platform
            else
                name=releasekey
            fi
        fi

        if [ $(echo $name | wc -w) -gt 1 ] ; then
            override=$(read_variable_from_makefile LOCAL_OVERRIDES_PACKAGES $1/Android.mk)
            if [ -n "$override" ] && [ "$(echo $name | grep $override)" ] ; then
                echo ${name/$override/}
            fi
        else
            if [ -n "$name" ] ; then
                echo $name
            else
                echo "releasekey"
            fi
        fi
    fi
    trap - ERR
}

function process_sys_plf {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    #generate the jrd_sys_properties.prop & jrd_build_properties.mk
    echo "parse system plf..."
    $JRD_BUILD_PATH/common/process_sys_plf.sh $JRD_TOOLS_ARCT $JRD_PROPERTIES_PLF $JRD_MAKEFILE_PLF $JRD_CUSTOM_RES 1>/dev/null
    trap - ERR
}

function read_variable_from_makefile {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    # read in the makefile, and find out the value of the give variable
    # $1 target variable to found
    # $2 target file to search
    #if [ -f "$JRD_LOG/read_variable_error.log" ] ; then
    #    rm $JRD_LOG/read_variable_error.log
    #fi
    if [ -z "$1" ] || [ -z "$2" ] ; then
        echo "input parameters cannot be null" >> $JRD_LOG/read_variable_error.log
        return
    fi
    local result=
    local variable=$1
    local findit="false"
    if [ -f $2 ] ; then
        local count=($(grep -E -n "$variable\s*:=" $2 | cut -d":" -f1))
        local linenum=${count[${#count[@]}-1]}

        if [ ${#count[@]} -eq 0 ] ; then
            echo "Cannot find $variable in $2" >> $JRD_LOG/read_variable_error.log
            echo ""
            return
        else
            linenum=${count[${#count[@]}-1]}
        fi

        #cat $2 | grep -v "^#" | while read -r readline
        sed -n "$linenum,\$p" $2 | grep -v "^#" | grep -v "^\s*$" | while read -r readline
        do
            if [ "$1" == 'PRODUCT_MODEL' ]; then
               echo $readline | tr -d '\r\n' | cut -d '=' -f2 >> result.txt
               break
            fi
            readline=$(echo $readline | tr -d [:space:]) # remove space
            if [ "$findit" == "false" ] ; then
                if [[ "$readline" =~ ^\s*$variable\s*:=.* ]] ; then
                    findit="true"
                    if [ "${readline: -1}" == "\\" ] ; then
                        readline=$(echo $readline | tr -d '\\')
                        if [ $(echo $readline | grep -o -e "=") ] ; then
                            echo $readline | cut -d '=' -f2 >> result.txt
                        fi
                    else
                        if [ $(echo $readline | grep -o -e "=") ] ; then
                            echo $readline | cut -d '=' -f2 >> result.txt
                            findit="false"
                            break
                        fi
                    fi
                fi
            else
                #echo $readline
                if [ "${readline: -1}" == "\\" ] ; then
                    readline=$(echo $readline | tr -d '\\')
                    echo $readline >> result.txt
                else
                    echo $readline >> result.txt
                    findit="false"
                    break
                fi
            fi
        done
    fi

    if [ -f result.txt ] ; then
        result=$(cat result.txt | sed 's/#[^#]*//g')
        rm -f result.txt
    fi
    echo $result
    trap - ERR
}


function generate_androidmanifest_xml {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "Generate AndroidManifest.xml..."
    sdkversion=$(cat $JRD_OUT_SYSTEM/build.prop |  grep "ro.build.version.sdk=" |  cut -d '=' -f2)
    if [ -n "$1" ] && [ -d $2 ] ; then
	if [ -n "$3" ] ; then
            echo '<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="'$1'.overlay"
    coreApp="true">
    <uses-sdk android:minSdkVersion="'$sdkversion'" android:targetSdkVersion="'$sdkversion'" />
    <overlay android:targetPackage="'$1'" android:priority="16"/>
</manifest>' > $2/AndroidManifest.xml
	else
            echo '<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="'$1'.overlay">
    <uses-sdk android:minSdkVersion="'$sdkversion'" android:targetSdkVersion="'$sdkversion'" />
    <overlay android:targetPackage="'$1'" android:priority="16"/>
</manifest>' > $2/AndroidManifest.xml
	fi
    fi
    trap - ERR
}

function prepare_audio_param {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    #TODO
    trap - ERR
}

function get_custo_apk_path {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    local is_privileged_module=
    local my_module_path=
    #echo "Try to get overlay package installation path"
    if [ -f $2/Android.mk ] ; then
        is_privileged_module=$(read_variable_from_makefile "LOCAL_PRIVILEGED_MODULE" $2/Android.mk)
        is_proprietary_module=$(read_variable_from_makefile "LOCAL_PROPRIETARY_MODULE" $2/Android.mk)
        if [[ ! "$2" =~ "aloneApp" ]] ; then
            my_module_path=$(read_variable_from_makefile "LOCAL_MODULE_PATH" $2/Android.mk)
            if [ -n "$my_module_path" ] ; then
                my_module_path=$(echo $my_module_path | sed -e 's/(//g' -e 's/)//g' | grep -o "\$[A-Z_]*[-/a-z]*")
                my_module_path=$(eval "echo $my_module_path")
                if [[ ! "$my_module_path" =~ "system/framework" ]] && [[ ! "$my_module_path" =~ "system/app" ]] && \
			[[ ! "$my_module_path" =~ "system/priv-app" ]] && [[ ! "$my_module_path" =~ "system/vendor/app" ]] && \
			[[ ! "$my_module_path" =~ "system/plugin" ]] && [[ ! "$my_module_path" =~ "system/vendor/framework" ]] && \
            [[ ! "$my_module_path" =~ "system/vendor/priv-app" ]] ; then
                    my_module_path=
                fi
            else
                my_module_path=
            fi
        fi
    fi
    
    if [ -n "$my_module_path" -a -d "$my_module_path" ] ; then
        echo $my_module_path
    elif [ "$is_proprietary_module" == "true" ] && [ "$is_privileged_module" == "true" ] ; then
        echo $JRD_OUT_SYSTEM/vendor/priv-app
    elif [ "$is_proprietary_module" == "true" ] ; then
        echo $JRD_OUT_SYSTEM/vendor/app
    elif [ "$is_privileged_module" == "true" ] ; then
        echo $JRD_OUT_SYSTEM/priv-app
    else
        echo $JRD_OUT_SYSTEM/app
    fi
    trap - ERR
}

function prepare_overlay_res {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    if [ ! -d $JRD_CUSTOM_RES ] ; then
        mkdir -p $JRD_CUSTOM_RES
    fi
    find_res_dir $JRD_WIMDATA/$JRD_PRODUCT/perso/string_res.ini
    #prepare_parseAloneApp
    prepare_copyOriginResource
    if [ -z "$DEBUG_ONLY" ] ; then
        prepare_translations
    fi
    prepare_mtkBtResource
    prepare_photos
    prepare_media
    prepare_ringtone
    #prepare_fonts
    #if [ ! "${PERSO_VERSION:4:2}" == "ZZ" ]; then
    #prepare_3rd_party_apk
    #fi
    prepare_usermanual
    prepare_apn
    prepare_agps
    prepare_plmn
    prepare_appmanager
    #prepare_wifi
    #prepare_theme
    #find_res_dir $JRD_WIMDATA/$JRD_PRODUCT/perso/string_res.ini
    prepare_launcher_workspace
    prepare_plfs
    process_sys_plf # process isdm_sys_properties.plf
    prepare_build_prop
    #prepare_sign_tool
    prepare_3rd_party_apk
    trap - ERR
}

function remove_extra_apk {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "remove apks in /system/app or /system/priv-app, when apk isdm value is 0 in isdm_sys_properties.plf "
    local apk_dirname=""
    local apk_fullpath=""
    if [ -f "$JRD_LOG/remove_apks.log" ] ; then
        rm $JRD_LOG/remove_apks.log
    fi
    # remove apks in /system/app or /system/priv-app, when apk isdm value is "0" in isdm_sys_properties.plf
    for apk in ${JRD_PRODUCT_PACKAGES[@]}
    do
        if [ -d $JRD_OUT_SYSTEM/app/$apk ] ; then
            apk_dirname=$JRD_OUT_SYSTEM/app/$apk
            apk_fullpath=$JRD_OUT_SYSTEM/app/$apk/$apk.apk
        elif [ -d $JRD_OUT_SYSTEM/priv-app/$apk ] ; then
            apk_dirname=$JRD_OUT_SYSTEM/priv-app/$apk
            apk_fullpath=$JRD_OUT_SYSTEM/priv-app/$apk/$apk.apk
        elif [ -d $JRD_OUT_SYSTEM/app/$apk ] ; then
            apk_dirname=$JRD_OUT_SYSTEM/app/$apk
            apk_fullpath=$JRD_OUT_SYSTEM/app/$apk/$apk.apk
        elif [ -d $JRD_OUT_SYSTEM/priv-app/$apk ] ; then
            apk_dirname=$JRD_OUT_SYSTEM/priv-app/$apk
            apk_fullpath=$JRD_OUT_SYSTEM/priv-app/$apk/$apk.apk
        elif [ -d $JRD_OUT_SYSTEM/vendor/priv-app/$apk ] ; then
            apk_dirname=$JRD_OUT_SYSTEM/vendor/priv-app/$apk
            apk_fullpath=$JRD_OUT_SYSTEM/vendor/priv-app/$apk/$apk.apk
        elif [ -d $JRD_OUT_SYSTEM/vendor/app/$apk ] ; then
            apk_dirname=$JRD_OUT_SYSTEM/vendor/app/$apk
            apk_fullpath=$JRD_OUT_SYSTEM/vendor/app/$apk/$apk.apk
        else
            echo "WARNING:CANNOT find $apk in /system $JRD_OUT_SYSTEM/vendor/priv-app/$apk"
            apk_dirname=""
            apk_fullpath=""
            continue
        fi
        if [ -n "$apk_dirname" ] ; then
            rm -rf $apk_dirname
            echo "apkfile_name: $apk_fullpath" >> $JRD_LOG/remove_apks.log
        else
            echo "do nothing"
        fi
    done
    trap - ERR
}

function generate_overlay_packages {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "generate_overlay_packages..."
    # parse string_res.ini, to find out all packages that need generate overlay apk
    # TODO: string_res.ini only include packages need to be translated, but still there is some pacages use google default translation.

    #create folders for overlay apk
    local my_apk_path=$TARGET_OUT_VENDOR_OVERLAY
    local my_package_name
    local my_apk_file_name
    local my_apk_certificate
    local main_apk_path
    local extra_res

    clean_intermediates_folder $TARGET_OUT_VENDOR_OVERLAY

    if [ ! -d "$my_apk_path" ] ; then
        mkdir -p $my_apk_path
    fi

    #JRD_PRODUCT_PACKAGES=$(read_variable_from_makefile "JRD_PRODUCT_PACKAGES" $JRD_CUSTOM_RES/jrd_build_properties.mk)
    PRODUCT_AAPT_CONFIG=$(get_product_aapt_config $JRD_CUSTOM_RES/jrd_build_properties.mk)

    if [ -f "$JRD_LOG/missing_package.log" ] ; then
        rm $JRD_LOG/missing_package.log
    fi
    if [ -f "$JRD_LOG/overlay-failed.log" ] ; then
        rm $JRD_LOG/overlay-failed.log
    fi
    if [ -f "$JRD_LOG/sign-failed.log" ] ; then
        rm $JRD_LOG/sign-failed.log
    fi
    if [ -f "$JRD_LOG/mainversion_ungene_package.log" ] ; then
        rm $JRD_LOG/mainversion_ungene_package.log
    fi

    local MY_ASSET_OPT=

    set -x
    echo "MY_RES_DIR: $MY_RES_DIR" >> $JRD_LOG/overlay_process.log
    for res in $MY_RES_DIR
    do
        res=$(dirname $res)
        echo "Start to process ---- $res ----" >> $JRD_LOG/overlay_process.log
        my_apk_file_name=$(get_local_package_name $TOP/$res)
        main_apk_path=$(get_custo_apk_path $my_apk_file_name $TOP/$res)
	echo "my_apk_file_name:$my_apk_file_name" >> $JRD_LOG/overlay_process.log
	echo "main_apk_path: $main_apk_path" >> $JRD_LOG/overlay_process.log

        if [ ! -f "$main_apk_path/$my_apk_file_name/${my_apk_file_name}.apk" ] && [ ! -f "$main_apk_path/${my_apk_file_name}.apk" ] ; then
	    echo "main version does not generate blow apk:" >> $JRD_LOG/mainversion_ungene_package.log
            echo "$res/res" >> $JRD_LOG/mainversion_ungene_package.log
            echo "main_apk_path: $main_apk_path" >> $JRD_LOG/mainversion_ungene_package.log
            echo "apkfile_name: $my_apk_file_name" >> $JRD_LOG/mainversion_ungene_package.log
            continue
        fi

        my_package_name=$(get_package_name $TOP $JRD_CUSTOM_RES $res)
	echo "my_package_name:$my_package_name"  >> $JRD_LOG/overlay_process.log
	is_core_app=$(get_core_app $TOP $res)
	echo "is_core_app: $is_core_app" >> $JRD_LOG/overlay_process.log
	
        if [ -n "$my_package_name" ] && [ -n "$my_apk_file_name" ] ; then

            my_tmp_path=$JRD_CUSTOM_RES/$res
            if [ ! -d "$my_tmp_path" ] ; then
                mkdir -p $my_tmp_path
            fi

            generate_androidmanifest_xml $my_package_name $my_tmp_path $is_core_app

	    if [ -f $JRD_WIMDATA/$JRD_PRODUCT/perso/package_list.xml ]; then
		package_list_xml=$JRD_WIMDATA/$JRD_PRODUCT/perso/package_list.xml
	    else
		package_list_xml=$SCRIPTS_DIR/package_list.xml
	    fi
            if ( grep "<package name=\"$my_apk_file_name\">" $package_list_xml ) ; then
                extra_res=$(xmlstarlet sel -t -m "/package_list/package[@name='$my_apk_file_name']/res" -o " -S $JRD_CUSTOM_RES/" -v "@path" $package_list_xml)
                if [ -n "$extra_res" ] ; then
                    extra_res="--auto-add-overlay $extra_res"
                fi
            else
                extra_res=""
            fi

            #aapt p -f -S res -I /media/Ubuntu/dev/android-sdk-linux_x86/platforms/android-17/android.jar -A assets -M AndroidManifest.xml -F Settings-overlay.apk
            #1，android.jar需要使用平台的
            #2，如果没有asset文件夹，可以移除掉-A参数
            #3，替换资源包命名需要使用“APKNAME-Overlay.apk”方式
            #TODO: product_config
            if [ -d $JRD_CUSTOM_RES/$res/assets ] ; then
                MY_ASSET_OPT="-A $JRD_CUSTOM_RES/$res/assets"
            else
                MY_ASSET_OPT= 
            fi

            if [ -f $JRD_CUSTOM_RES/$res/AndroidManifest.xml ] ; then
                # TODO: check if overlay package generated or not?
                $MY_AAPT_TOOL p -f -I $MY_ANDROID_JAR_TOOL \
                    -S $JRD_CUSTOM_RES/$res/res \
		    $extra_res \
                    -M $JRD_CUSTOM_RES/$res/AndroidManifest.xml \
                    -c $PRODUCT_AAPT_CONFIG \
                    -F $my_tmp_path/$my_apk_file_name-overlay.apk $MY_ASSET_OPT

                if [ ! -f "$my_tmp_path/$my_apk_file_name-overlay.apk" ] ; then
                    echo "$my_tmp_path/$my_apk_file_name-overlay.apk generate failed" >> $JRD_LOG/overlay-failed.log
                fi

                my_apk_certificate=$(get_local_certificate $TOP/$res)

                if [ -n "$my_apk_certificate" ] ; then
                    java -Xmx512m -jar $TOP/out/host/linux-x86/framework/signapk.jar \
                        $TOP/build/target/product/security/$my_apk_certificate.x509.pem \
                        $TOP/build/target/product/security/$my_apk_certificate.pk8 \
                        $my_tmp_path/$my_apk_file_name-overlay.apk \
                        $my_apk_path/$my_apk_file_name-overlay.apk

                    if [ ! -f "$my_apk_path/$my_apk_file_name-overlay.apk" ] ; then
                        echo "$my_apk_path/$my_apk_file_name-overlay.apk sign failed" >> $JRD_LOG/sign-failed.log
                    else
                        zipalign -c 4 $my_apk_path/$my_apk_file_name-overlay.apk
                        if [ $? -ne 0 ] ; then
                            zipalign -f 4 $my_apk_path/$my_apk_file_name-overlay.apk $my_apk_path/$my_apk_file_name-overlay.apk_aligned
                            if [ $? -eq 0 ] && [ -f "$my_apk_path/$my_apk_file_name-overlay.apk_aligned" ] ; then
                                rm $my_apk_path/$my_apk_file_name-overlay.apk
                                mv $my_apk_path/$my_apk_file_name-overlay.apk_aligned $my_apk_path/$my_apk_file_name-overlay.apk
                            fi
                        fi
                    fi
                fi
            fi
        else
            echo $res/res >> $JRD_LOG/missing_package.log
            echo "package_name: $my_package_name" >> $JRD_LOG/missing_package.log
            echo "apkfile_name: $my_apk_file_name" >> $JRD_LOG/missing_package.log
        fi
    done

    if [ -f $JRD_OUT_SYSTEM/vendor/overlay/MmsService-overlay.apk ];then
        rm -fr $JRD_OUT_SYSTEM/vendor/overlay/MmsService-overlay.apk
    fi

    set +x
    trap - ERR
}

function change_system_ver {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo $PERSO_VERSION > $JRD_OUT_SYSTEM/system.ver
    trap - ERR
}

function release_key {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "prepare release key and sign 3rd apk..."
    $SCRIPTS_DIR/checkapk_perso.sh $JRD_PRODUCT
    pushd $TOP > /dev/null
    $SCRIPTS_DIR/releasekey.sh "TCL_1010" $JRD_PRODUCT
    popd > /dev/null
    trap - ERR
}

function generate_userdata_image {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    PATH=$PATH:$TOP/out/host/linux-x86/bin
    USERDATA_SIZE=($(read_variable_from_makefile "BOARD_USERDATAIMAGE_PARTITION_SIZE" $PARTITION_SIZE_TABLE))
    #local USERDATA_SIZE=$(get_build_var BOARD_USERDATAIMAGE_PARTITION_SIZE)
    echo "USERDATA_SIZE : $USERDATA_SIZE"
    make_ext4fs -s -l $USERDATA_SIZE -a data $PRODUCT_OUT/userdata.img $PRODUCT_OUT/data
    trap - ERR
}

function generate_modem_image {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    if [ -d "$TOP/modem/out_modem" ]; then
	cp -f $TOP/modem/out_modem/modem_1*.img $JRD_OUT_SYSTEM/etc/firmware/
	cp -f $TOP/modem/out_modem/catcher_filter_*.bin $JRD_OUT_SYSTEM/etc/firmware/
    fi
    trap - ERR
}

function generate_nv_raw {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
#    local PRIVATE_JRD_PROPERTIES_PLF=$JRD_WIMDATA/$JRD_PRODUCT/perso/isdm_sys_properties.plf
#    local PRIVATE_JRD_MAKEFILE_PLF=$JRD_WIMDATA/$JRD_PRODUCT/perso/isdm_sys_makefile.plf
#    local ENUM_FILE_CUSTOM_APPSRC_FILE=`echo modem/build/*/*/dhl/database/enumFileCustomAppSrc`
#    local CUSTOM_NVRAM_LID_CAT_FILE=`echo modem/build/*/*/nvram_auto_gen/custom_nvram_lid_cat.xml`
#    $JRD_TOOLS/arct/prebuilt/plf2raw \
#       --nvram-perso $JRD_WIMDATA/$JRD_PRODUCT/perso/nv_perso_data_structure.xml \
#       --nvram-cat $CUSTOM_NVRAM_LID_CAT_FILE  \
#       --enum-id $ENUM_FILE_CUSTOM_APPSRC_FILE \
#       --output $JRD_OUT_CUSTPACK/raw \
#       $PRIVATE_JRD_PROPERTIES_PLF \
#       $PRIVATE_JRD_MAKEFILE_PLF
     local PRIVATE_JRD_SYS_PLF_DIR=$JRD_WIMDATA/common/perso/
     local PRIVATE_NV_PERSO_DATA=$JRD_WIMDATA/$JRD_PRODUCT/perso/nv_perso_data_structure.xml
        mkdir -p $JRD_OUT_CUSTPACK
	$JRD_TOOLS/arct/prebuilt/arct \
       r \
       $PRIVATE_NV_PERSO_DATA \
       $PRIVATE_JRD_SYS_PLF_DIR \
       $JRD_OUT_CUSTPACK/raw
    trap - ERR
}

function generate_logo {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "Generate a logo.bin from the picture"
    echo "now comparing the logo image..."
    perl $JRD_BUILD_PATH/common/checkLogo.pl $JRD_WIMDATA/$JRD_PRODUCT/perso/logo/$BOOT_LOGO $TOP/vendor/mediatek/proprietary/bootable/bootloader/lk/dev/logo/$BOOT_LOGO
    # generate the boot_logo
    $JRD_BUILD_PATH/common/update_logo.sh $BOOT_LOGO $TOP $JRD_WIMDATA/$JRD_PRODUCT/perso/logo $JRD_CUSTOM_RES
    # generate the logo.bin
    IMG_HDR_CFG=$TOP/vendor/mediatek/proprietary/bootable/bootloader/lk/dev/logo/img_hdr_logo.cfg
    $TOP/vendor/mediatek/proprietary/bootable/bootloader/lk/scripts/mkimage $JRD_CUSTOM_RES/$BOOT_LOGO.raw $IMG_HDR_CFG > $PRODUCT_OUT/logo.bin
    trap - ERR
}

function umount_system_image {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    local keyword=$1
    mounted=($(df | grep $keyword | awk '{print $1}'))

    for device in ${mounted[@]}
    do
        sudo umount $device
        if [ $? -eq 0 ] ; then
            echo "umount $device succeed"
        else
            echo "umount $device failed"
            exit 1
        fi
    done

    local raw_file_name=$2
    if [ -n $raw_file_name ] && [ -f $raw_file_name ] ; then
        rm -f $raw_file_name
    fi
    trap - ERR
}

function sign_image {
	if [ $IFSIGNAL -eq 1 ] ; then
        echo "signed img"
		command make tctsignperso
        mv $PRODUCT_OUT/signed_bin/logo-sign.bin $PRODUCT_OUT/signed_bin/logo.bin
        mv $PRODUCT_OUT/signed_bin/simlock-sign.img $PRODUCT_OUT/signed_bin/simlock.img
        mv $PRODUCT_OUT/signed_bin/system-sign.img $PRODUCT_OUT/signed_bin/system.img
        mv $PRODUCT_OUT/signed_bin/userdata-sign.img $PRODUCT_OUT/signed_bin/userdata.img
        cp $PRODUCT_OUT/signed_bin/logo.bin $PRODUCT_OUT
        cp $PRODUCT_OUT/signed_bin/simlock.img $PRODUCT_OUT
        cp $PRODUCT_OUT/signed_bin/system.img $PRODUCT_OUT
        cp $PRODUCT_OUT/signed_bin/userdata.img $PRODUCT_OUT
        rm -fr $PRODUCT_OUT/signed_bin
        
	fi
}

function prepare_system_folder {
    #mount the system image, and change file owner and group to current user, remove lost+found folder
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    local origin_system_image=$1
    local dest_path=$2
    local dest_raw_path=$3
    local dest_raw_file=$1.raw
    local suffix
    local mygroup

    if [ -a $dest_raw_file ] ; then
        rm -f $dest_faw_file
    fi

    if [ ! -f "$JRD_TOOLS/simg2img" ]; then
        cp $SCRIPTS_DIR/persoTools/simg2img $JRD_TOOLS/simg2img
        chmod 755 $JRD_TOOLS/simg2img
    fi

    set -x
    mkdir -p $dest_path
    if [ -f $origin_system_image ] ; then
        suffix=${origin_system_image##*.}
        #if the system image is ext4 mbn file, not compressed
        if [ "$suffix" == "mbn" ] || [ "$suffix" == "img" ] ; then
            $JRD_TOOLS_SIMG2IMG $origin_system_image $dest_raw_file
        #if the system image is compressed zip file
        elif [ "$suffix" == "zip" ] ; then
            ziped_file=$(unzip -l $origin_system_image | grep raw | awk '{print $4}')
            dest_raw_file=$dest_raw_path/$ziped_file
            unzip -o -q $origin_system_image -d $dest_raw_path
        #if the format of system image is not the both above, then exit
        else
            echo "The format of origin system image is incorrect."
            exit 1
        fi
        #mount the system image
        sudo mount -o loop $dest_raw_file $dest_path
        if [ $? -eq 0 ] ; then
            echo "mount $dest_raw_file succeed"
        else
            echo "mount $dest_raw_file failed"
            exit 1
        fi
        #get the name of current user group
        mygroup=$(echo $(groups) | awk '{print $1}')
        #change file owner and group to current user
        sudo chown -hR $USER:$mygroup $dest_path
        #remove lost+found folder
        if [ -d "$dest_path/lost+found" ] ; then
            rm -rf $dest_path/lost+found
        fi
        rm -f $dest_raw_file
    else
        echo "Can't find origin system image. exit now ... "
        exit 1
    fi
    mkdir -p $TOP/out/host
    cp -rf $SCRIPTS_DIR/persoTools/linux-x86 $TOP/out/host/linux-x86
    chmod 755 $TOP/out/host/linux-x86/bin/mkuserimg.sh
    chmod 755 $TOP/out/host/linux-x86/bin/make_ext4fs
    chmod 755 $TOP/out/host/linux-x86/bin/zipalign
    chmod 755 $TOP/out/host/linux-x86/bin/apktool
    chmod 755 $TOP/out/host/linux-x86/bin/apktool.jar
    chmod 755 $TOP/out/host/linux-x86/bin/append2simg
    chmod 755 $TOP/out/host/linux-x86/bin/build_verity_tree
    chmod 755 $TOP/out/host/linux-x86/bin/fs_config
    chmod 755 $TOP/out/host/linux-x86/bin/verity_signer
    chmod 755 $TOP/out/host/linux-x86/framework/signapk.jar
    set +x
    trap - ERR
}

function prepare_userdata_folder1 {
    local mygroup=$(echo $(groups) | awk '{print $1}')
    local origin_userdata_image=$1
    local dest_path=$2
    local dest_raw_path=$3
    local dest_raw_file=$1.raw
    local suffix
    local mygroup

    if [ -a $dest_raw_file ] ; then
        rm -f $dest_raw_file
    fi

    mkdir -p $dest_path
}

function prepare_userdata_folder {
    #mount the userdata image, and change file owner and group to current user, remove lost+found folder
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    local mygroup=$(echo $(groups) | awk '{print $1}')
    local origin_userdata_image=$1
    local dest_path=$2
    local dest_raw_path=$3
    local dest_raw_file=$1.raw
    local suffix
    local mygroup

    if [ -a $dest_raw_file ] ; then
        rm -f $dest_raw_file
    fi

    set -x
    mkdir -p $dest_path
    if [ -f $origin_userdata_image ] ; then
        suffix=${origin_userdata_image##*.}
        #if the system image is ext4 mbn file, not compressed
        if [ "$suffix" == "mbn" ] || [ "$suffix" == "img" ] ; then
            $JRD_TOOLS_SIMG2IMG $origin_userdata_image $dest_raw_file
        #if the format of system image is not the ext4 mbn file, then exit
        else
            echo "The format of origin system image is incorrect."
            exit 1
        fi
        #mount the userdebug image
        sudo mount -o loop $dest_raw_file $dest_path
        if [ $? -eq 0 ] ; then
            echo "mount $dest_raw_file succeed"
        else
            echo "mount $dest_raw_file failed"
            exit 1
        fi
        #get the name of current user group
        mygroup=$(echo $(groups) | awk '{print $1}')
        #change file owner and group to current user
        sudo chown -hR $USER:$mygroup $dest_path
        #remove lost+found folder
        if [ -d "$dest_path/lost+found" ] ; then
            rm -rf $dest_path/lost+found
        fi
        rm -f $dest_raw_file
    else
        echo "Can't find origin userdata image. exit now ... "
        exit 1
    fi
    set +x
    trap - ERR
}

function prepare_tct_meta {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    mkdir -p $JRD_OUT_META_PERSO
    if [ -f "$JRD_OUT_SYSTEM/build.prop" ] ; then
	cp -f $JRD_OUT_SYSTEM/build.prop $JRD_OUT_META_PERSO
    fi
    if [ -f "$JRD_OUT_SYSTEM/system.ver" ] ; then
	cp -f $JRD_OUT_SYSTEM/system.ver $JRD_OUT_META_PERSO
    fi
    if [ -f "$PRODUCT_OUT/system.map" ] ; then
	cp -f $PRODUCT_OUT/system.map $JRD_OUT_META_PERSO
    fi
    zip -rjq $PRODUCT_OUT/$(basename $JRD_OUT_META_PERSO).zip $JRD_OUT_META_PERSO
    trap - ERR
}

function prepare_selinux_tag {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    local origin_root_image=$1
    local dest_path=$2
    if [ -f $origin_root_image ] ; then
        mkdir -p $dest_path
        pushd $dest_path > /dev/null
        gunzip -c $origin_root_image | cpio -i
        popd > /dev/null
    fi
    trap - ERR
}

function generate_system_image {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "Now start to generate system image ... "
    set -x
    PATH=$PATH:$TOP/out/host/linux-x86/bin
    system_image_size=($(read_variable_from_makefile "BOARD_SYSTEMIMAGE_PARTITION_SIZE" $PARTITION_SIZE_TABLE))
    #local system_image_size=$(get_build_var BOARD_SYSTEMIMAGE_PARTITION_SIZE)
    #local extra_config=""
    #local system_map=""
    #if [ -f "$TARGET_ROOT_OUT/file_contexts" ] ; then
    #    extra_config="$TARGET_ROOT_OUT/file_contexts"
    #fi
    #mkdir -p $PRODUCT_OUT/tct_fota_meta_perso
    #system_map="$PRODUCT_OUT/tct_fota_meta_perso/system.map"
    #echo "mkuserimg.sh -s $JRD_OUT_SYSTEM $PRODUCT_OUT/system.img ext4 system $system_image_size -B $system_map $extra_config"
    #mkuserimg.sh -s $JRD_OUT_SYSTEM $PRODUCT_OUT/system.img ext4 system $system_image_size -B $system_map $extra_config
    #if [ $? -ne 0 ] ; then
    #    echo "make system image failed, now exiting ..."
    #    exit
    #fi
    python $SCRIPTS_DIR/build_system_image.py "system" $system_image_size $TOP

    set +x
    trap - ERR
}

function generate_simlock_image {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    echo "Now start to generate secro image ... "
    set -x
    mkdir -p $JRD_OUT_SIMLOCK
    cp -f $TOP/vendor/jrdchz/proprietary/simlock/* $JRD_OUT_SIMLOCK
    PATH=$PATH:$TOP/out/host/linux-x86/bin
    simlock_image_size=($(read_variable_from_makefile "BOARD_SIMLOCKIMAGE_PARTITION_SIZE" $PARTITION_SIZE_TABLE))
    local extra_config=""
    if [ -f "$TARGET_ROOT_OUT/file_contexts.bin" ] ; then
        extra_config="$TARGET_ROOT_OUT/file_contexts.bin"
    fi
    echo "mkuserimg.sh -s $JRD_OUT_SIMLOCK $PRODUCT_OUT/simlock.img ext4 $PRODUCT_OUT/simlock $simlock_image_size $extra_config"
    mkuserimg.sh -s $JRD_OUT_SIMLOCK $PRODUCT_OUT/simlock.img ext4 simlock $simlock_image_size $extra_config
    if [ $? -ne 0 ] ; then
        echo "make simlock image failed, now exiting ..."
        exit
    fi
    set +x
    trap - ERR
}

function addroot_flag {
   trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
   echo "add root flag log"
   /usr/bin/perl $JRD_BUILD_PATH/jrdmagic/jrd_magic.pl $JRD_PRODUCT
   trap - ERR
}

function clean_build_log {
   trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
   echo "Now clean build log"
   if [ -d $JRD_LOG ]; then
      rm -rf $JRD_LOG
   fi
   mkdir -p $JRD_LOG
   if [ -d $JRD_ALONE_TEMP ]; then
      rm -rf $JRD_ALONE_TEMP
   fi
   mkdir -p $JRD_ALONE_TEMP
   trap - ERR
}

function clean_intermediates_folder {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    pushd $TOP > /dev/null
    while true
    do
        if [ -d $1 ] ; then
            rm -rf $1
        else
            echo "$1 not exist"
        fi

        if [[ "$#" -gt 0 ]] ; then
            # creat this folder for future using
            mkdir -p $1
            shift
        else
            break
        fi
    done
    popd > /dev/null
    trap - ERR
}

function clean_intermediates_files {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    pushd $TOP > /dev/null
    if [ -d $1 ] ; then
        echo "##$1##"
        find $1 -type f | while read -r line
        do
            rm -f $line
        done
    else
        echo "$1 not exist"
    fi
    popd > /dev/null
    trap - ERR
}

function find_res_dir {
    trap 'traperror ${LINENO} ${FUNCNAME} ${BASH_LINENO}' ERR
    local my_strings_dir
    local my_icons_dir
    local my_plffile_dir
    #TODO: read string_res.ini file and find out all packages that need to be overlayed
    #      this may missing some important packages that not list in this file,
    MY_RES_DIR=''

    pushd $TOP > /dev/null

    if [ -f $1 ] ; then
        my_strings_dir=$(cat $1 | grep -o -e '^[^\#].*res' | sed 's/\.\///g')
    fi

    my_icons_dir=$(unzip -l $JRD_WIMDATA/$JRD_PRODUCT/perso/Photos/images.zip | grep -E "png|jpg" | awk '{print $4}' | sed 's:res.*:res:')
    my_plffile_dir=$(for path in ${MY_PLF_FILE_FOLDER[@]}; do find $path -type f -name '*.plf' | sed 's:isdm.*plf:res:';done)

    MY_RES_DIR=$(echo "$my_strings_dir $my_icons_dir $my_plffile_dir" | sed 's:\s:\n:g' | sort | uniq)

    popd > /dev/null

    if [ -n "$MY_RES_DIR" ] ; then
        echo "MY_RES_DIR=$MY_RES_DIR"
    else
        echo "Can't get res dir list, exit now ... "
        exit -1
    fi
    trap - ERR
}



while getopts p:t:s:u:d:m:v:n: o
do
    case "$o" in
    p) TARGET_PRODUCT="$OPTARG";;
    t) TOP="$OPTARG";;
    s) ORIGIN_SYSTEM_IMAGE="$OPTARG";;
    u) ORIGIN_USERDATA_IMAGE="$OPTARG";;
    m) TARGET_THEME="$OPTARG";;
    v) PERSO_VERSION="$OPTARG";;
    n) IFSIGNAL="$OPTARG";;
    d) DEBUG_ONLY="$OPTARG";;
    [?]) usage ;;
    esac
done

if [ -z "$TARGET_PRODUCT" ]; then
    echo "Please specify target product."
    usage
fi

if [ -z "$TOP" ]; then
    echo "Please specify TOP folder."
    usage
else
    TOP=$(readlink -e $TOP)
fi

if [ -z "$ORIGIN_SYSTEM_IMAGE" ]; then
    echo "Please specify where to find ORIGIN_SYSTEM_IMAGE."
    usage
else
    ORIGIN_SYSTEM_IMAGE=$(readlink -e $ORIGIN_SYSTEM_IMAGE)
    echo "ORIGIN_SYSTEM_IMAGE=$ORIGIN_SYSTEM_IMAGE"
fi

if [ -z "$ORIGIN_USERDATA_IMAGE" ]; then
    echo "Please specify where to find ORIGIN_USERDATA_IMAGE."
    usage
else
    ORIGIN_USERDATA_IMAGE=$(readlink -e $ORIGIN_USERDATA_IMAGE)
    echo "ORIGIN_USERDATA_IMAGE=$ORIGIN_USERDATA_IMAGE"
fi

if [ -z "$TARGET_THEME" ] ; then
    echo "Please specify TARGET_THEME type."
    usage
else
    echo "TARGET_THEME=$TARGET_THEME"
fi

if [ -z "$PERSO_VERSION" ] ; then
    echo "Please specify PERSO version."
    usage
else
    echo "PERSO_VERSION=$PERSO_VERSION"
fi

if [ -z "IFSIGNAL" ] ; then
    echo "Please specitfy IF SIGNAL"
    usage
else
    echo "IFSIGNAL=$IFSIGNAL"
fi

JRD_PRODUCT=${TARGET_PRODUCT#full_}
echo "JRD_PRODUCT: $JRD_PRODUCT"

ORIGIN_ROOT_IMAGE=$(dirname $ORIGIN_SYSTEM_IMAGE)/ramdisk.img
SCRIPTS_DIR=$(dirname $0)

#indicat the perso log fold
JRD_LOG=$TOP/persoLog
#indicat the alone temp fold
JRD_ALONE_TEMP=$TOP/aloneTemp
#indicate the fold of wimdata in the source code
JRD_WIMDATA=$TOP/device/jrdchz
#indicate the path of the jrd tools
JRD_TOOLS=$TOP/vendor/jrdchz/build/tools
#indicate the arct
JRD_TOOLS_ARCT=$JRD_TOOLS/arct/prebuilt/arct
#indicate the simg2img tool
#*****************
JRD_TOOLS_SIMG2IMG=$JRD_TOOLS/simg2img
#indicate the main path for the build system of jrdcom
JRD_BUILD_PATH=$TOP/vendor/jrdchz/build
#indicate the main path for the build system of a certain project
#JRD_BUILD_PATH_DEVICE=$JRD_BUILD_PATH/$TARGET_PRODUCT
#the path of the system properties plf
JRD_PROPERTIES_PLF=$JRD_WIMDATA/common/perso/isdm_sys_properties.plf
JRD_MAKEFILE_PLF=$JRD_WIMDATA/common/perso/isdm_sys_makefile.plf
#JRD_PROPERTIES_COMMONO_PLF=$JRD_WIMDATA/common/perso/isdm_sys_properties.plf

#indicate the jrd custom resource path in /out
JRD_CUSTOM_RES=$TOP/out/target/common/perso/$JRD_PRODUCT/jrdResAssetsCust
#indicate the product out path
PRODUCT_OUT=$TOP/out/target/product/$JRD_PRODUCT
#indicate the custpack path
JRD_OUT_CUSTPACK=$PRODUCT_OUT/system/custpack

TARGET_ROOT_OUT=$PRODUCT_OUT/root
#TARBALL_OUT_DIR=$PRODUCT_OUT/tarball
JRD_OUT_SYSTEM=$PRODUCT_OUT/system
JRD_OUT_USERDATA=$PRODUCT_OUT/data
JRD_OUT_SIMLOCK=$PRODUCT_OUT/simlock
JRD_OUT_META_PERSO=$PRODUCT_OUT/tct_fota_meta_perso
TARGET_OUT_VENDOR_JAVA_LIBRARIES=$PRODUCT_OUT/system/vendor/framework

THEME_RESOUCE_PATH=$JRD_WIMDATA/common/perso/theme/output_zip/$TARGET_THEME
THEME_OUT_PATH=$PRODUCT_OUT/system
#the path of overlay apk
TARGET_OUT_VENDOR_OVERLAY=$PRODUCT_OUT/system/vendor/overlay

MY_ANDROID_JAR_TOOL=$TOP/prebuilts/sdk/current/android.jar
MY_AAPT_TOOL=$TOP/prebuilts/sdk/tools/linux/bin/aapt
if [ -f $TOP/partition_size.mk ] ; then
	PARTITION_SIZE_TABLE=$TOP/partition_size.mk
else
	PARTITION_SIZE_TABLE=$TOP/persoTools/partition_size.mk
fi

TARGET_OUT_APP_PATH="$TOP/$(get_build_var TARGET_OUT_APP_PATH)"

TARGET_OUT_PRIV_APP_PATH="$TOP/$(get_build_var TARGET_OUT_PRIV_APP_PATH)"

TARGET_OUT_JAVA_LIBRARIES="$TOP/$(get_build_var TARGET_OUT_JAVA_LIBRARIES)"

TARGET_OUT_VENDOR_APPS="$TOP/$(get_build_var TARGET_OUT_VENDOR_APPS)"

#get apk list which isdm "JRD_PRODUCT_PACKAGES" value is set to "0" in isdm_sys_properties.plf
#**************************
JRD_PRODUCT_PACKAGES=$(get_build_var JRD_PRODUCT_PACKAGES)
BOOT_LOGO=$(get_build_var BOOT_LOGO)

#plf file search path
MY_PLF_FILE_FOLDER=(frameworks/base/core \
                    frameworks/base/packages \
                    packages/apps \
                    packages/providers \
                    packages/services \
		    packages/inputmethods \
                    vendor/jrdchz/proprietary/aloneApp \
                    vendor/jrdchz/proprietary/packages/apps)

if [ -z "$DEBUG_ONLY" ] ; then
    umount_system_image $JRD_OUT_SYSTEM
    umount_system_image $JRD_OUT_USERDATA
    clean_intermediates_folder $TOP/out
    clean_build_log
    prepare_system_folder $ORIGIN_SYSTEM_IMAGE $JRD_OUT_SYSTEM $PRODUCT_OUT
    prepare_userdata_folder $ORIGIN_USERDATA_IMAGE $JRD_OUT_USERDATA $PRODUCT_OUT
fi

#generate_userdata_image
#umount_system_image $JRD_OUT_USERDATA

#generate_modem_image
generate_nv_raw
prepare_overlay_res
prepare_audio_param
remove_extra_apk
generate_overlay_packages
change_system_ver
if [ "$TARGET_BUILD_VARIANT" == "user" ] ; then
    release_key
fi
if [ -f "$ORIGIN_ROOT_IMAGE" ] ; then
    prepare_selinux_tag $ORIGIN_ROOT_IMAGE $TARGET_ROOT_OUT
fi
generate_system_image
generate_simlock_image
generate_logo
#addroot_flag
prepare_tct_meta
generate_userdata_image
umount_system_image $JRD_OUT_USERDATA
umount_system_image $JRD_OUT_SYSTEM
sign_image

echo "Finished build customization package."
