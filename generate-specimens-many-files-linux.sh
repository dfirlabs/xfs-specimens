#!/bin/bash
#
# Script to generate XFS test files, that contain many files
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

SECTOR_SIZE=512

for NUMBER_OF_FILES in 100 1000 10000 100000
do
	if test ${NUMBER_OF_FILES} -eq 100000
	then
		IMAGE_SIZE=$(( 256 * 1024 * 1024 ))

	elif test ${NUMBER_OF_FILES} -eq 10000
	then
		IMAGE_SIZE=$(( 32 * 1024 * 1024 ))
	else
		# Need at least 16 MiB
		IMAGE_SIZE=$(( 16 * 1024 * 1024 ))
	fi

	IMAGE_FILE="${SPECIMENS_PATH}/xfs_${NUMBER_OF_FILES}_files.raw"

	 echo "Creating: XFS; with: ${NUMBER_OF_FILES} files"
	create_test_image_file ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-L xfs_test"

	sudo mount -o loop,rw ${IMAGE_FILE} ${MOUNT_POINT}

	sudo chown ${USERNAME} ${MOUNT_POINT}

	create_test_file_entries ${MOUNT_POINT}

	# Create additional files
	for NUMBER in `seq 3 ${NUMBER_OF_FILES}`
	do
		if test $(( ${NUMBER} % 2 )) -eq 0
		then
			touch ${MOUNT_POINT}/testdir1/TestFile${NUMBER}
		else
			touch ${MOUNT_POINT}/testdir1/testfile${NUMBER}
		fi
	done

	sudo umount ${MOUNT_POINT}
done

exit ${EXIT_SUCCESS}
