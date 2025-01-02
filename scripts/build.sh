#!/usr/bin/env bash

set -e
if [[ $# != 1 ]]; then
	echo "Usage: $0 <init/build>"
	exit 1
fi

case "$1" in
	"init")
		mkdir -p keys
		# We don't really need a usable PK, so just generate a public key for it and discard the private key
		openssl req -new -x509 -newkey rsa:2048 -subj "/CN=Raspberry Pi Platform Key/" -keyout /dev/null -outform DER -out keys/pk.cer -days 7300 -nodes -sha256
		curl -L https://go.microsoft.com/fwlink/?LinkId=321185 -o keys/ms_kek1.cer
		curl -L https://go.microsoft.com/fwlink/?linkid=2239775 -o keys/ms_kek2.cer
		curl -L https://go.microsoft.com/fwlink/?linkid=321192 -o keys/ms_db1.cer
		curl -L https://go.microsoft.com/fwlink/?linkid=321194 -o keys/ms_db2.cer
		curl -L https://go.microsoft.com/fwlink/?linkid=2239776 -o keys/ms_db3.cer
		curl -L https://go.microsoft.com/fwlink/?linkid=2239872 -o keys/ms_db4.cer
		curl -L https://uefi.org/sites/default/files/resources/dbxupdate_arm64.bin -o keys/arm64_dbx.bin
		make -C edk2/BaseTools -j32
		shift
		;;
	"build")
		shift
		export WORKSPACE=$PWD
		export GCC5_AARCH64_PREFIX=aarch64-unknown-linux-gnu-
		export PACKAGES_PATH=$WORKSPACE/edk2:$WORKSPACE/edk2-platforms:$WORKSPACE/edk2-non-osi
		export BUILD_FLAGS="-D SECURE_BOOT_ENABLE=TRUE -D INCLUDE_TFTP_COMMAND=TRUE -D NETWORK_ISCSI_ENABLE=TRUE -D SMC_PCI_SUPPORT=1"
		export TLS_DISABLE_FLAGS="-D NETWORK_TLS_ENABLE=FALSE -D NETWORK_ALLOW_HTTP_CONNECTIONS=TRUE"
		export DEFAULT_KEYS="-D DEFAULT_KEYS=TRUE -D PK_DEFAULT_FILE=$WORKSPACE/keys/pk.cer -D KEK_DEFAULT_FILE1=$WORKSPACE/keys/ms_kek1.cer -D KEK_DEFAULT_FILE2=$WORKSPACE/keys/ms_kek2.cer -D DB_DEFAULT_FILE1=$WORKSPACE/keys/ms_db1.cer -D DB_DEFAULT_FILE2=$WORKSPACE/keys/ms_db2.cer -D DB_DEFAULT_FILE3=$WORKSPACE/keys/ms_db3.cer -D DB_DEFAULT_FILE4=$WORKSPACE/keys/ms_db4.cer -D DBX_DEFAULT_FILE1=$WORKSPACE/keys/arm64_dbx.bin"

		. edk2/edksetup.sh

		build -a AARCH64 -t GCC5 -b DEBUG -n$(nproc) -p edk2-platforms/Platform/RaspberryPi/RPi4/RPi4.dsc --pcd gEfiMdeModulePkgTokenSpaceGuid.PcdFirmwareVendor=L"https://github.com/pftf/RPi4" --pcd gEfiMdeModulePkgTokenSpaceGuid.PcdFirmwareVersionString=L"UEFI Firmware v1.81" ${BUILD_FLAGS} ${DEFAULT_KEYS} ${TLS_DISABLE_FLAGS}

		TLS_DISABLE_FLAGS=""

		cp Build/RPi4/DEBUG_GCC5/FV/RPI_EFI.fd .
		;;

esac

