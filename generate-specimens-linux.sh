#!/bin/bash
#
# Script to generate XFS test files
# Requires Linux with dd and mkfs.xfs

source ./shared_linux.sh

assert_availability_binary dd
# assert_availability_binary fallocate
assert_availability_binary mkfs.xfs
assert_availability_binary mknod
assert_availability_binary qemu-img
assert_availability_binary setfattr
assert_availability_binary truncate

VERSION=$( mkfs.xfs -V | sed 's/mkfs.xfs version //' )

SPECIMENS_PATH="specimens/mkfs.xfs-${VERSION}"

if test -d ${SPECIMENS_PATH}
then
	echo "Specimens directory: ${SPECIMENS_PATH} already exists."

	exit ${EXIT_FAILURE}
fi

mkdir -p ${SPECIMENS_PATH}

set -e

USERNAME=$( whoami )

MOUNT_POINT="/mnt/xfs"

sudo mkdir -p ${MOUNT_POINT}

MINIMUM_VERSION=$( echo "${VERSION} 3.2.0" | tr ' ' '\n' | sort -V | head -n 1 )

if test "${MINIMUM_VERSION}" = "3.2.0"
then
	METADATA_OPTIONS="-m crc=0"
else
	METADATA_OPTIONS=""
fi

# mkfs.xfs 6.15.0: V4 filesystems are deprecated and will not be supported by future versions.

MAXIMUM_RAW_IMAGE_SIZE=$(( 50 * 1024 * 1024 ))

SECTOR_SIZE=512

# Need at least 16 MiB
IMAGE_SIZE=$(( 16 * 1024 * 1024 ))

IMAGE_FILE="${SPECIMENS_PATH}/xfs.raw"

echo "Creating: XFS"
create_test_image_file_with_file_entries ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-L xfs_test"

for INODE_SIZE in 256 512 1024 2048
do
	echo "Creating: XFS; with inode size: ${INODE_SIZE}"

	if test ${INODE_SIZE} -lt 512
	then
		# Minimum inode size for CRCs is 512 bytes
		create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_inode_${INODE_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-i size=${INODE_SIZE}" "-L xfs_test" ${METADATA_OPTIONS}
	else
		create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_inode_${INODE_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-i size=${INODE_SIZE}" "-L xfs_test"
	fi
done

# Note that sector size cannot be larger than block size

# TODO: add support for sector sizes: 8192 16384 32768

for SECTOR_SIZE in 512 1024 2048 4096
do
	IMAGE_FILE="${SPECIMENS_PATH}/xfs_sector_${SECTOR_SIZE}.raw"

	echo "Creating: XFS; with sector size: ${SECTOR_SIZE}"

	create_test_image_file_with_file_entries ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-s size=${SECTOR_SIZE}" "-L xfs_test"
done

# TODO: create images with more than 1 allocation group -d agcount=X

# V2 attribute format always enabled on CRC enabled filesystems

IMAGE_FILE="${SPECIMENS_PATH}/xfs_attributes_version_1.raw"

echo "Creating: XFS; with version 1 extended attributes"
create_test_image_file_with_file_entries ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-i attr=1" "-L xfs_test" ${METADATA_OPTIONS}

IMAGE_FILE="${SPECIMENS_PATH}/xfs_attributes_version_2.raw"

echo "Creating: XFS; with version 2 extended attributes"
create_test_image_file_with_file_entries ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-i attr=2" "-L xfs_test"

# mkfs.xfs Version 1 directories are not supported.
# IMAGE_FILE="${SPECIMENS_PATH}/xfs_directory_version_1.raw"
#
# echo "Creating: XFS; with version 1 directory"
# Invalid value 1 for -n version option. Value is too small.
# create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_directory_version_1.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-n version=1" "-L xfs_test"

IMAGE_FILE="${SPECIMENS_PATH}/xfs_directory_version_2.raw"

echo "Creating: XFS; with version 2 directory"
create_test_image_file_with_file_entries ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-n version=2" "-L xfs_test"

IMAGE_FILE="${SPECIMENS_PATH}/xfs_directory_version_ci.raw"

echo "Creating: XFS; with version ASCII only case-insensitive directory"
create_test_image_file_with_file_entries ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-n version=ci" "-L xfs_test"

IMAGE_FILE="${SPECIMENS_PATH}/xfs_journal_version_1.raw"

echo "Creating: XFS; with version 1 journal"
# Version 2 journals (logs) always enabled for CRC enabled filesystems
create_test_image_file_with_file_entries ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-l version=1" "-L xfs_test" ${METADATA_OPTIONS}

IMAGE_FILE="${SPECIMENS_PATH}/xfs_journal_version_2.raw"

echo "Creating: XFS; with version 2 journal"
create_test_image_file_with_file_entries ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-l version=2" "-L xfs_test"

# TODO: create image with unaligned inodes `-i align=0'
# TODO: create image with aligned inodes `-i align=1'

# 32 bit Project IDs always enabled on CRC enabled filesystems

IMAGE_FILE="${SPECIMENS_PATH}/xfs_directory_without_projid.raw"

echo "Creating: XFS; without 32-bit project identifiers" 
create_test_image_file_with_file_entries ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-i projid32bit=0" "-L xfs_test" ${METADATA_OPTIONS}

IMAGE_FILE="${SPECIMENS_PATH}/xfs_directory_with_projid.raw"

echo "Creating: XFS; with 32-bit project identifiers" 
create_test_image_file_with_file_entries ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-i projid32bit=1" "-L xfs_test"

MINIMUM_VERSION=$( echo "${VERSION} 3.2.0" | tr ' ' '\n' | sort -V | head -n 1 )

if test "${MINIMUM_VERSION}" = "3.2.0"
then
	# Directory ftype field always enabled on CRC enabled filesystems

	IMAGE_FILE="${SPECIMENS_PATH}/xfs_directory_without_ftype.raw"

	echo "Creating: XFS; without file type (ftype) in directories"
	create_test_image_file_with_file_entries ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-n ftype=0" "-L xfs_test" "-m crc=0"

	IMAGE_FILE="${SPECIMENS_PATH}/xfs_directory_with_ftype_ci.raw"

	echo "Creating: XFS; with file type (ftype) in directories"
	create_test_image_file_with_file_entries ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-n ftype=1" "-L xfs_test"
fi

# TODO: enable/disable "bigtime" -m bigtime=1/0
# TODO: enable/disable "metadir" -m metadir=1/0

# TODO: enable/disable "free inode btree" -m finobt=1/0 and -m inobtcount=X
# TODO: enable/disable "reverse-mapping btree" -m rmapbt=1/0
# TODO: enable/disable "reference count btree" -m reflink=1/0

for BLOCK_SIZE in 512 1024 2048 4096 8192 16384 32768 65536
do
	# Make sure the image is suficiently large otherwise mkfs.xfs might error with:
	# max log size X smaller than min log size Y, filesystem is too small
	if test ${BLOCK_SIZE} -ge 32768
	then
		IMAGE_SIZE=$(( 512 * 1024 * 1024 ))

	elif test ${BLOCK_SIZE} -eq 16384
	then
		IMAGE_SIZE=$(( 256 * 1024 * 1024 ))

	elif test ${BLOCK_SIZE} -eq 8192
	then
		IMAGE_SIZE=$(( 128 * 1024 * 1024 ))
	else
		IMAGE_SIZE=$(( 16 * 1024 * 1024 ))
	fi

	IMAGE_FILE="${SPECIMENS_PATH}/xfs_block_${BLOCK_SIZE}.raw"

	echo "Creating: XFS; with block size: ${BLOCK_SIZE}"

	if test ${BLOCK_SIZE} -lt 1024
	then
		# Note that the minimum block size for CRC enabled filesystems is 1024 bytes
		create_test_image_file_with_file_entries ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-b size=${BLOCK_SIZE}" "-L xfs_test" ${METADATA_OPTIONS}

	else
		# Linux kernel versions prior to 6.12 cannot mount XFS with a block size > 4096
		# mount: /mnt/xfs: mount(2) system call failed: Function not implemented.
		#
		# Using mkfs.xfs version as proxy for kernel version, given this script is run with docker

		if (test "${VERSION}" = "3.1.9" && test ${BLOCK_SIZE} -ge 8192) || (test "${VERSION}" = "4.9.0" && test ${BLOCK_SIZE} -ge 32768)
		then
			create_test_image_file ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-b size=${BLOCK_SIZE}" "-L xfs_test"
		else
			create_test_image_file_with_file_entries ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-b size=${BLOCK_SIZE}" "-L xfs_test"
		fi
		if test ${IMAGE_SIZE} -ge ${MAXIMUM_RAW_IMAGE_SIZE};
		then
			qemu-img convert -f raw -O qcow2 ${IMAGE_FILE} ${IMAGE_FILE/.raw/.qcow2}

			rm -f ${IMAGE_FILE}
		fi
	fi
done

# Note that directory block size cannot be less than block size

for DIRECTORY_BLOCK_SIZE in 8192 16384 32768 65536
do
	if test ${DIRECTORY_BLOCK_SIZE} -eq 65536
	then
		# If 16 MiB mkfs.xfs 3.1.9 will run out of space
		IMAGE_SIZE=$(( 32 * 1024 * 1024 ))
	else
		IMAGE_SIZE=$(( 16 * 1024 * 1024 ))
	fi

	IMAGE_FILE="${SPECIMENS_PATH}/xfs_directory_block_${DIRECTORY_BLOCK_SIZE}.raw"

	echo "Creating: XFS; with directory block size: ${DIRECTORY_BLOCK_SIZE}"

	create_test_image_file_with_file_entries ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-n size=${DIRECTORY_BLOCK_SIZE}" "-L xfs_test"
done

exit ${EXIT_SUCCESS}
