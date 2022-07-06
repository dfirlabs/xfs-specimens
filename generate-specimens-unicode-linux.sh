#!/bin/bash
#
# Script to generate XFS test files for testing Unicode conversions
# Requires Linux with dd and mkfs.xfs

EXIT_SUCCESS=0;
EXIT_FAILURE=1;

# Checks the availability of a binary and exits if not available.
#
# Arguments:
#   a string containing the name of the binary
#
assert_availability_binary()
{
	local BINARY=$1;

	which ${BINARY} > /dev/null 2>&1;
	if test $? -ne ${EXIT_SUCCESS};
	then
		echo "Missing binary: ${BINARY}";
		echo "";

		exit ${EXIT_FAILURE};
	fi
}

# Creates a test image file.
#
# Arguments:
#   a string containing the path of the image file
#   an integer containing the size of the image file
#   an integer containing the sector size
#   an array containing the arguments for mkfs.xfs
#
create_test_image_file()
{
	IMAGE_FILE=$1;
	IMAGE_SIZE=$2;
	SECTOR_SIZE=$3;
	shift 3;
	local ARGUMENTS=("$@");

	dd if=/dev/zero of=${IMAGE_FILE} bs=${SECTOR_SIZE} count=$(( ${IMAGE_SIZE} / ${SECTOR_SIZE} )) 2> /dev/null;

	mkfs.xfs -q ${ARGUMENTS[@]} ${IMAGE_FILE};
}

create_test_file_entries_unicode()
{
	MOUNT_POINT=$1;

	# Create a directory
	mkdir ${MOUNT_POINT}/testdir1

	set +e;

	# Create a file for Unicode characters defined in UnicodeData.txt
	for NUMBER in `cat UnicodeData.txt | sed 's/;.*$//'`;
	do
		UNICODE_CHARACTER=`printf "%08x" $(( 0x${NUMBER} ))`;

		touch `python2 -c "print(''.join(['${MOUNT_POINT}/testdir1/unicode_U+${UNICODE_CHARACTER}_', '${UNICODE_CHARACTER}'.decode('hex').decode('utf-32-be')]).encode('utf-8'))"` 2> /dev/null;

		if test $? -ne 0;
		then
			echo "Unsupported: 0x${UNICODE_CHARACTER}";
		fi
	done

	set -e;
}

assert_availability_binary dd;
assert_availability_binary mkfs.xfs;

SPECIMENS_PATH="specimens/mkfs.xfs";

if ! test -f "UnicodeData.txt";
then
	echo "Missing UnicodeData.txt file. UnicodeData.txt can be obtained from "
	echo "unicode.org make sure you have a local copy in the current working ";
	echo "directory.";

	exit ${EXIT_FAILURE};
fi

if test -d ${SPECIMENS_PATH};
then
	echo "Specimens directory: ${SPECIMENS_PATH} already exists.";

	exit ${EXIT_FAILURE};
fi

mkdir -p ${SPECIMENS_PATH};

set -e;

MOUNT_POINT="/mnt/xfs";

sudo mkdir -p ${MOUNT_POINT};

IMAGE_SIZE=$(( 32 * 1024 * 1024 ));
SECTOR_SIZE=512;

# Create raw disk image with an XFS file system and files for individual Unicode characters
IMAGE_FILE="${SPECIMENS_PATH}/xfs_unicode_files.raw";

create_test_image_file ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-L xfs_test"

sudo mount -o loop,rw ${IMAGE_FILE} ${MOUNT_POINT};

sudo chown ${USERNAME} ${MOUNT_POINT};

create_test_file_entries_unicode ${MOUNT_POINT}

sudo umount ${MOUNT_POINT};

exit ${EXIT_SUCCESS};

