#!/bin/bash
#
# Script to generate XFS test files
# Requires Linux with dd and mkfs.xfs

source ./shared_linux.sh

assert_availability_binary dd
assert_availability_binary fallocate
assert_availability_binary mkfs.xfs
assert_availability_binary mknod
assert_availability_binary setfattr
assert_availability_binary truncate

VERSION=$( mkfs.xfs -V | sed 's/mkfs.xfs version //' )

SPECIMENS_PATH="specimens/mkfs.xfs-${VERSION}-many-files"

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

# Need at least 16 MiB
IMAGE_SIZE=$(( 16 * 1024 * 1024 ))
SECTOR_SIZE=512

echo "Creating: XFS"
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-L xfs_test"

for BLOCK_SIZE in 512 1024 2048 4096 8192 16384
do
	echo "Creating: XFS; with block size: ${BLOCK_SIZE}"

	if test ${BLOCK_SIZE} -lt 1024
	then
		# Note that the minimum block size for CRC enabled filesystems is 1024 bytes
		create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_block_${BLOCK_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-b size=${BLOCK_SIZE}" "-L xfs_test" "-m crc=0"

	elif test ${BLOCK_SIZE} -lt 8192
	then
		create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_block_${BLOCK_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-b size=${BLOCK_SIZE}" "-L xfs_test"

	else
		# Cannot mount XFS with block size > 4096
		# mount: /mnt/xfs: mount(2) system call failed: Function not implemented.
		create_test_image_file "${SPECIMENS_PATH}/xfs_block_${BLOCK_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-b size=${BLOCK_SIZE}" "-L xfs_test"
	fi
done

# TODO: log size 501 blocks too small, minimum size is 512 blocks
# create_test_image_file "${SPECIMENS_PATH}/xfs_block_32768.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-b size=32768" "-L xfs_test"

# TODO: log size 245 blocks too small, minimum size is 512 blocks
# create_test_image_file "${SPECIMENS_PATH}/xfs_block_65536.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-b size=65536" "-L xfs_test"

for INODE_SIZE in 512 1024 2048
do
	echo "Creating: XFS; with inode size: ${INODE_SIZE}"

	if test ${INODE_SIZE} -lt 512
	then
		# Minimum inode size for CRCs is 512 bytes
		create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_inode_${INODE_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-i size=${INODE_SIZE}" "-L xfs_test" "-m crc=0"
	else
		create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_inode_${INODE_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-i size=${INODE_SIZE}" "-L xfs_test"
	fi
done

for SECTOR_SIZE in 512 1024 2048 4096 8192 16384 32768
do
	echo "Creating: XFS; with sector size: ${SECTOR_SIZE}"

	if test ${SECTOR_SIZE} -lt 8192
	then
		create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_sector_${SECTOR_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-s size=${SECTOR_SIZE}" "-L xfs_test"
	else
		# Note that block size cannot be smaller than sector size

		# max log size 2036 smaller than min log size 2810, filesystem is too small
		#
		# Cannot mount XFS with block size > 4096
		# mount: /mnt/xfs: mount(2) system call failed: Function not implemented.
		create_test_image_file "${SPECIMENS_PATH}/xfs_sector_${SECTOR_SIZE}.raw" $(( 32 * 1024 * 1024 )) ${SECTOR_SIZE} "-b size=${SECTOR_SIZE}" "-s size=${SECTOR_SIZE}" "-L xfs_test"
	fi
done

# TODO: create images with different directory block sizes `-n size='

# TODO: create images with more than 1 allocation group

# Create image with version 1 extended attributes
# V2 attribute format always enabled on CRC enabled filesystems
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_attributes_version_1.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-i attr=1" "-L xfs_test" "-m crc=0"

# TODO: create image with large number of attributes.

echo "Creating: XFS; with version 2 extended attributes"
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_attributes_version_2.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-i attr=2" "-L xfs_test"

# TODO: create image with large number of attributes.

# Create image with version 1 directory
# Invalid value 1 for -n version option. Value is too small.
# create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_directory_version_1.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-n version=1" "-L xfs_test"

echo "Creating: XFS; with version 2 directory"
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_directory_version_2.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-n version=2" "-L xfs_test"

echo "Creating: XFS; with version ASCII only case-insensitive directory"
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_directory_version_ci.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-n version=ci" "-L xfs_test"

echo "Creating: XFS; with version 1 journal"
# Version 2 journals (logs) always enabled for CRC enabled filesystems
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_journal_version_1.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-l version=1" "-L xfs_test" "-m crc=0"

echo "Creating: XFS; with version 2 journal"
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_journal_version_2.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-l version=2" "-L xfs_test"

# TODO: create image with unaligned inodes `-i align=0'
# TODO: create image with aligned inodes `-i align=1'

echo "Creating: XFS; without 32-bit project identifiers" 
# 32 bit Project IDs always enabled on CRC enabled filesystems
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_directory_without_projid.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-i projid32bit=0" "-L xfs_test" "-m crc=0"

echo "Creating: XFS; with 32-bit project identifiers" 
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_directory_with_projid.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-i projid32bit=1" "-L xfs_test"

echo "Creating: XFS; without file type (ftype) in directories"
# Directory ftype field always enabled on CRC enabled filesystems
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_directory_without_ftype.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-n ftype=0" "-L xfs_test" "-m crc=0"

echo "Creating: XFS; with file type (ftype) in directories"
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_directory_with_ftype_ci.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-n ftype=1" "-L xfs_test"

exit ${EXIT_SUCCESS}
