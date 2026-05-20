#!/bin/bash
#
# Script to generate XFS test files, that contain many (extended) attributes
# Requires Linux with dd and mkfs.xfs

source ./shared_linux.sh

assert_availability_binary dd
assert_availability_binary fallocate
assert_availability_binary mkfs.xfs
assert_availability_binary mknod
assert_availability_binary setfattr
assert_availability_binary truncate

VERSION=$( mkfs.xfs -V | sed 's/mkfs.xfs version //' )

SPECIMENS_PATH="specimens/mkfs.xfs-${VERSION}-many-attributes"

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

SECTOR_SIZE=512

for NUMBER_OF_ATTRIBUTES in 100 1000 10000
do
	# Need at least 16 MiB
	IMAGE_SIZE=$(( 16 * 1024 * 1024 ))

	IMAGE_FILE="${SPECIMENS_PATH}/xfs_${NUMBER_OF_ATTRIBUTES}_attributes_version_1.raw"

	 echo "Creating: XFS; with: ${NUMBER_OF_ATTRIBUTES} version 1 attributes"
	create_test_image_file ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-i attr=1" "-L xfs_test" "-m crc=0"

	sudo mount -o loop,rw ${IMAGE_FILE} ${MOUNT_POINT}

	sudo chown ${USERNAME} ${MOUNT_POINT}

	create_test_file_entries ${MOUNT_POINT}

	touch ${MOUNT_POINT}/testdir1/many_xattrs

	# Create additional extended attributes
	for NUMBER in `seq 1 ${NUMBER_OF_ATTRIBUTES}`
	do
		setfattr -n "user.myxattr${NUMBER}" -v "Extended attribute: ${NUMBER}" ${MOUNT_POINT}/testdir1/many_xattrs
	done

	sudo umount ${MOUNT_POINT}
done

for NUMBER_OF_ATTRIBUTES in 100 1000 10000
do
	# Need at least 16 MiB
	IMAGE_SIZE=$(( 16 * 1024 * 1024 ))

	IMAGE_FILE="${SPECIMENS_PATH}/xfs_${NUMBER_OF_ATTRIBUTES}_attributes_version_2.raw"

	 echo "Creating: XFS; with: ${NUMBER_OF_ATTRIBUTES} version 2 attributes"
	create_test_image_file ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-i attr=2" "-L xfs_test"

	sudo mount -o loop,rw ${IMAGE_FILE} ${MOUNT_POINT}

	sudo chown ${USERNAME} ${MOUNT_POINT}

	create_test_file_entries ${MOUNT_POINT}

	touch ${MOUNT_POINT}/testdir1/many_xattrs

	# Create additional extended attributes
	for NUMBER in `seq 1 ${NUMBER_OF_ATTRIBUTES}`
	do
		setfattr -n "user.myxattr${NUMBER}" -v "Extended attribute: ${NUMBER}" ${MOUNT_POINT}/testdir1/many_xattrs
	done

	sudo umount ${MOUNT_POINT}
done

exit ${EXIT_SUCCESS}
