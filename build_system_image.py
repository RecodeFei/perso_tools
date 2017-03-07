#!/usr/bin/python

import os
import sys
import glob
import commands
import re
import subprocess
import tempfile




def chdir(path, log=''):
	oldDir = os.getcwd()
	os.chdir(path)
	return oldDir

def pushdir(path, log=''):
	global __dirStack
	oldDir = chdir(path, log)
	__dirStack.insert(0, oldDir)
	return oldDir

def popdir(log=''):
	global __dirStack
	oldDir = ''
	if len(__dirStack) > 0:
		oldDir = chdir(__dirStack[0], log)
		__dirStack = __dirStack[1:]
	return oldDir

def get_build_var(var_name,path=False):
	'''
	Get the exact value of a build variable.
	'''
	os.environ["CALLED_FROM_SETUP"]="true"
	os.environ["BUILD_SYSTEM"]="build/core"
	var="dumpvar-"+var_name
	try:
		pushdir(TOP)
		result = subprocess.check_output("command make --no-print-directory -f build/core/config.mk "+var,shell=True,stderr=subprocess.STDOUT)
		if path:
			result = os.path.abspath(result)
		popdir()
		return result.strip('\n')
	except subprocess.CalledProcessError as err:
		print "except Exception:%s" % err
		sys.exit(-1)

def generate_system_image(image_name,image_size):
	print "Now start to generate %s image ... " % image_name

	pushdir(TOP)

	image_info = {}
	build_prop = JRD_OUT_SYSTEM + '/build.prop'
	internal_product = get_build_var("INTERNAL_PRODUCT")

	if image_name == 'system':

		if image_size == '':
			image_info['partition_size'] = get_build_var("BOARD_SYSTEMIMAGE_PARTITION_SIZE")
		else:
			image_info['partition_size'] = image_size

		image_info['mount_point'] = 'system'

		verity_partition = get_build_var("PRODUCTS."+internal_product+".PRODUCT_SYSTEM_VERITY_PARTITION")
		if verity_partition != '':
			image_info['verity_block_device'] = verity_partition

		if os.path.isfile(TARGET_ROOT_OUT+'/file_contexts.bin'):
			#global status
			#global output
			(status, output) = commands.getstatusoutput('find '+TARGET_OUT+' | while read -r line; do if [ -d "$line" ]; then line="$line/"; fi; echo $line | grep -o "system/.*"; done | fs_config -C -D '+TARGET_OUT+' -S '+TARGET_ROOT_OUT+'/file_contexts.bin > '+PRODUCT_OUT+'/filesystem_config.txt')
		if status != 0:
			print output
			print "ERROR: build filesystem_config.txt falied"
			sys.exit(-1)

		if os.path.isfile(PRODUCT_OUT+'/filesystem_config.txt'):
			image_info['fs_config'] = PRODUCT_OUT+'/filesystem_config.txt'

		image_info['block_list'] = PRODUCT_OUT+'/system.map'

	elif image_name == 'userdata':

		if image_size == '':
			image_info['partition_size'] = get_build_var("BOARD_USERDATAIMAGE_PARTITION_SIZE")
		else:
			image_info['partition_size'] = image_size

		image_info['mount_point'] = 'data'

	else:
		print "ERROR: [%s] image generation is not supported at present" % image_name
		sys.exit(-1)

	if os.path.isfile(TARGET_ROOT_OUT+'/file_contexts.bin'):
		image_info['selinux_fc'] = TARGET_ROOT_OUT+'/file_contexts.bin'

	if get_build_var("TARGET_USERIMAGES_USE_EXT2") == "true":
		image_info['fs_type'] = 'ext2'
	elif get_build_var("TARGET_USERIMAGES_USE_EXT3") == "true":
		image_info['fs_type'] = 'ext3'
	elif get_build_var("TARGET_USERIMAGES_USE_EXT4") == "true":
		image_info['fs_type'] = 'ext4'
	else:
		print "fs type error"
		sys.exit(-1)

	image_info['verity_signer_cmd'] = get_build_var("VERITY_SIGNER")

	image_info['verity_key'] = get_build_var("PRODUCTS."+internal_product+".PRODUCT_VERITY_SIGNING_KEY")

	if get_build_var("TARGET_USERIMAGES_SPARSE_EXT_DISABLED") != 'true':
		image_info['extfs_sparse_flag'] = '-s'

	image_info['skip_fsck'] = 'true'

	image_info['verity'] = get_build_var("PRODUCTS."+internal_product+".PRODUCT_SUPPORTS_VERITY")

	timestamp = re.search(r'ro.build.date.utc\s*=\s*([0-9]*)',open(build_prop).read()).group(1)
	if len(timestamp) > 0:
		image_info['timestamp'] = timestamp

	sys.path.append(TOP+'/build/tools/releasetools')
	import build_image

	if not build_image.BuildImage(PRODUCT_OUT+'/'+image_info['mount_point'], image_info, PRODUCT_OUT+'/'+image_name+'.img'):
		print "Error: failed to build %s from %s" % (PRODUCT_OUT+'/'+image_name+'.img', PRODUCT_OUT+'/'+image_info['mount_point'])
		sys.exit(1)

	popdir()

	return 0

if __name__ == '__main__':
  if len(sys.argv) != 4:
    print __doc__
    sys.exit(1)
  IMAGE_NAME = sys.argv[1]
  IMAGE_SIZE = sys.argv[2]
  TOP = sys.argv[3]
  __dirStack = []
  JRD_OUT_SYSTEM     = get_build_var('TARGET_OUT',True)
  TARGET_ROOT_OUT    = get_build_var('TARGET_ROOT_OUT',True)
  PRODUCT_OUT        = get_build_var('PRODUCT_OUT',True)
  TARGET_OUT                = get_build_var('TARGET_OUT',True)
  generate_system_image(IMAGE_NAME,IMAGE_SIZE)
