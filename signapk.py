#!/usr/bin/python
#Filename:sigapk.py

import sys
import os
import commands
import pexpect

keyfile_path = '/build/target/product/security/' 

def startsignapk(prodpath,apkfile,keyfile,keyword,platform):
	child = pexpect.spawn('java -Xmx512m -jar '+prodpath+'/out/host/linux-x86/framework/signapk.jar '+prodpath + keyfile_path + keyfile+'.x509.pem '+prodpath + keyfile_path + keyfile+'.pk8 '+prodpath+'/out/target/product/'+platform+'/system/custpack/'+apkfile+' '+prodpath+'/out/target/product/'+platform+'/system/custpack/'+apkfile+'.signed')
	child.logfile = sys.stdout
	while True:
		try:
			child.expect('Enter\s+password\s+for\s+[^\[\]]+:\s*')
			child.sendline(keyword)
		except pexpect.EOF:
			break
		except pexpect.TIMEOUT:
			continue	

if __name__ == '__main__':
	if len(sys.argv)==6:
		startsignapk(sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4],sys.argv[5])
