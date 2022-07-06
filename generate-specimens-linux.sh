#!/bin/bash
#
# Script to generate XFS test files
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

# Creates test file entries.
#
# Arguments:
#   a string containing the mount point of the image file
#
create_test_file_entries()
{
	MOUNT_POINT=$1;

	# Create an empty file
	touch ${MOUNT_POINT}/emptyfile

	# Create a directory
	mkdir ${MOUNT_POINT}/testdir1

	# Create a file that can be stored as inline data
	echo "My file" > ${MOUNT_POINT}/testdir1/testfile1

	# Create a file that cannot be stored as inline data
	cp LICENSE ${MOUNT_POINT}/testdir1/TestFile2

	# Create a hard link to a file
	ln ${MOUNT_POINT}/testdir1/testfile1 ${MOUNT_POINT}/file_hardlink1

	# Create a symbolic link to a file
	ln -s ${MOUNT_POINT}/testdir1/testfile1 ${MOUNT_POINT}/file_symboliclink1

	# Create a hard link to a directory
	# ln: hard link not allowed for directory

	# Create a symbolic link to a directory
	ln -s ${MOUNT_POINT}/testdir1 ${MOUNT_POINT}/directory_symboliclink1

	# Create a file with an UTF-8 NFC encoded filename
	touch `printf "${MOUNT_POINT}/nfc_t\xc3\xa9stfil\xc3\xa8"`

	# Create a file with an UTF-8 NFD encoded filename
	touch `printf "${MOUNT_POINT}/nfd_te\xcc\x81stfile\xcc\x80"`

	# Create a file with an UTF-8 NFD encoded filename
	touch `printf "${MOUNT_POINT}/nfd_\xc2\xbe"`

	# Create a file with an UTF-8 NFKD encoded filename
	touch `printf "${MOUNT_POINT}/nfkd_3\xe2\x81\x844"`

	# Create a file with an extended attribute
	touch ${MOUNT_POINT}/testdir1/xattr1
	setfattr -n "user.myxattr1" -v "My 1st extended attribute" ${MOUNT_POINT}/testdir1/xattr1

	# Create a directory with an extended attribute
	mkdir ${MOUNT_POINT}/testdir1/xattr2
	setfattr -n "user.myxattr2" -v "My 2nd extended attribute" ${MOUNT_POINT}/testdir1/xattr2

	# Create a file with an extended attribute that is not stored inline (extent-based)
	read -d "" -N 8192 -r LARGE_XATTR_DATA < LICENSE;
	touch ${MOUNT_POINT}/testdir1/large_xattr
	setfattr -n "user.mylargexattr" -v "${LARGE_XATTR_DATA}" ${MOUNT_POINT}/testdir1/large_xattr

	# Create a file with an initial sparse extent
	truncate -s $(( 1 * 1024 * 1024 )) ${MOUNT_POINT}/testdir1/initial_sparse1
	echo "File with an initial sparse extent" >> ${MOUNT_POINT}/testdir1/initial_sparse1

	# Create a file with a trailing sparse extent
	echo "File with a trailing sparse extent" > ${MOUNT_POINT}/testdir1/trailing_sparse1
	truncate -s $(( 1 * 1024 * 1024 )) ${MOUNT_POINT}/testdir1/trailing_sparse1

	# Create a file with an uninitialized extent
	fallocate -x -l 4096 ${MOUNT_POINT}/testdir1/uninitialized1
	echo "File with an uninitialized extent" >> ${MOUNT_POINT}/testdir1/uninitialized1

	# Create a block device file
	# Need to run mknod with sudo otherwise it errors with: Operation not permitted
	sudo mknod ${MOUNT_POINT}/testdir1/blockdev1 b 24 57

	# Create a character device file
	# Need to run mknod with sudo otherwise it errors with: Operation not permitted
	sudo mknod ${MOUNT_POINT}/testdir1/chardev1 c 13 68

	# Create a pipe (FIFO) file
	mknod ${MOUNT_POINT}/testdir1/pipe1 p
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

	echo "mkfs.xfs -q ${ARGUMENTS[@]} ${IMAGE_FILE}";
	mkfs.xfs -q ${ARGUMENTS[@]} ${IMAGE_FILE};
}

# Creates a test image file with file entries.
#
# Arguments:
#   a string containing the path of the image file
#   an integer containing the size of the image file
#   an integer containing the sector size
#   an array containing the arguments for mkfs.xfs
#
create_test_image_file_with_file_entries()
{
	IMAGE_FILE=$1;
	IMAGE_SIZE=$2;
	SECTOR_SIZE=$3;
	shift 3;
	local ARGUMENTS=("$@");

	create_test_image_file ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} ${ARGUMENTS[@]};

	sudo mount -o loop,rw ${IMAGE_FILE} ${MOUNT_POINT};

	sudo chown ${USERNAME} ${MOUNT_POINT};

	create_test_file_entries ${MOUNT_POINT};

	sudo umount ${MOUNT_POINT};
}

assert_availability_binary dd;
assert_availability_binary fallocate;
assert_availability_binary mkfs.xfs;
assert_availability_binary mknod;
assert_availability_binary setfattr;
assert_availability_binary truncate;

SPECIMENS_PATH="specimens/mkfs.xfs";

if test -d ${SPECIMENS_PATH};
then
	echo "Specimens directory: ${SPECIMENS_PATH} already exists.";

	exit ${EXIT_FAILURE};
fi

mkdir -p ${SPECIMENS_PATH};

set -e;

MOUNT_POINT="/mnt/xfs";

sudo mkdir -p ${MOUNT_POINT};

# Need at least 16 MiB
IMAGE_SIZE=$(( 16 * 1024 * 1024 ));
SECTOR_SIZE=512;

# Create a XFS file system
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-L xfs_test";

# TODO: Minimum block size for CRC enabled filesystems is 1024 bytes
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_block_512.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-b size=512" "-L xfs_test" "-m crc=0";

# Create a XFS file system with a specific block size
for BLOCK_SIZE in 1024 2048 4096;
do
	create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_block_${BLOCK_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-b size=${BLOCK_SIZE}" "-L xfs_test";
done

# Cannot mount XFS with block size > 4096
# mount: /mnt/xfs: mount(2) system call failed: Function not implemented.
for BLOCK_SIZE in 8192 16384;
do
	create_test_image_file "${SPECIMENS_PATH}/xfs_block_${BLOCK_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-b size=${BLOCK_SIZE}" "-L xfs_test";
done

# TODO: log size 501 blocks too small, minimum size is 512 blocks
# create_test_image_file "${SPECIMENS_PATH}/xfs_block_32768.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-b size=32768" "-L xfs_test";

# TODO: log size 245 blocks too small, minimum size is 512 blocks
# create_test_image_file "${SPECIMENS_PATH}/xfs_block_65536.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-b size=65536" "-L xfs_test";

# Create a XFS file system with a specific inode size
# Minimum inode size for CRCs is 512 bytes
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_inode_256.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-i size=256" "-L xfs_test" "-m crc=0";

for INODE_SIZE in 512 1024 2048;
do
	create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_inode_${INODE_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-i size=${INODE_SIZE}" "-L xfs_test";
done

# Create a XFS file system with a specific sector size
for SECTOR_SIZE in 512 1024 2048 4096;
do
	create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_sector_${SECTOR_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-s size=${SECTOR_SIZE}" "-L xfs_test";
done

# block size 4096 cannot be smaller than sector size 8192
# Cannot mount XFS with block size > 4096
# mount: /mnt/xfs: mount(2) system call failed: Function not implemented.
for SECTOR_SIZE in 8192 16384;
do
	create_test_image_file "${SPECIMENS_PATH}/xfs_sector_${SECTOR_SIZE}.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-b size=${SECTOR_SIZE}" "-s size=${SECTOR_SIZE}" "-L xfs_test";
done

# log size 498 blocks too small, minimum size is 573 blocks
# create_test_image_file "${SPECIMENS_PATH}/xfs_sector_32768.raw" ${IMAGE_SIZE} 32768 "-b size=32768" "-s size=32768" "-L xfs_test";

# TODO: create images with different directory block sizes `-n size='

# TODO: create images with more than 1 allocation group

# Create image with version 1 extended attributes
# V2 attribute format always enabled on CRC enabled filesystems
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_attributes_version_1.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-i attr=1" "-L xfs_test" "-m crc=0";

# TODO: create image with large number of attributes.

# Create image with version 2 extended attributes
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_attributes_version_2.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-i attr=2" "-L xfs_test";

# TODO: create image with large number of attributes.

# Create image with version 1 directory
# Invalid value 1 for -n version option. Value is too small.
# create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_directory_version_1.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-n version=1" "-L xfs_test";

# Create image with version 2 directory
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_directory_version_2.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-n version=2" "-L xfs_test";

# Create image with version 2 ASCII only case-insensitive directory directory
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_directory_version_ci.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-n version=ci" "-L xfs_test";

# Create image with version 1 journal
# V2 logs always enabled for CRC enabled filesystems
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_journal_version_1.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-l version=1" "-L xfs_test" "-m crc=0";

# Create image with version 2 journal
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_journal_version_2.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-l version=2" "-L xfs_test";

# TODO: create image with unaligned inodes `-i align=0'
# TODO: create image with aligned inodes `-i align=1'

# Create image without 32-bit project identifiers
# 32 bit Project IDs always enabled on CRC enabled filesystems
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_directory_without_projid.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-i projid32bit=0" "-L xfs_test" "-m crc=0";

# Create image with 32-bit project identifiers
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_directory_with_projid.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-i projid32bit=1" "-L xfs_test";

# Create image without file type in directories
# Directory ftype field always enabled on CRC enabled filesystems
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_directory_without_ftype.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-n ftype=0" "-L xfs_test" "-m crc=0";

# Create image with file type in directories
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/xfs_directory_with_ftype_ci.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-n ftype=1" "-L xfs_test";

# Create XFS file systems with many files
for NUMBER_OF_FILES in 100 1000 10000 100000;
do
	if test ${NUMBER_OF_FILES} -eq 100000;
	then
		IMAGE_SIZE=$(( 256 * 1024 * 1024 ));

	elif test ${NUMBER_OF_FILES} -eq 10000;
	then
		IMAGE_SIZE=$(( 32 * 1024 * 1024 ));
	else
		IMAGE_SIZE=$(( 16 * 1024 * 1024 ));
	fi

	IMAGE_FILE="${SPECIMENS_PATH}/xfs_${NUMBER_OF_FILES}_files.raw";

	create_test_image_file ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-L xfs_test";

	sudo mount -o loop,rw ${IMAGE_FILE} ${MOUNT_POINT};

	sudo chown ${USERNAME} ${MOUNT_POINT};

	create_test_file_entries ${MOUNT_POINT};

	# Create additional files
	for NUMBER in `seq 3 ${NUMBER_OF_FILES}`;
	do
		if test $(( ${NUMBER} % 2 )) -eq 0;
		then
			touch ${MOUNT_POINT}/testdir1/TestFile${NUMBER};
		else
			touch ${MOUNT_POINT}/testdir1/testfile${NUMBER};
		fi
	done

	sudo umount ${MOUNT_POINT};
done

# Create XFS file systems with many version 1 extended attributes
for NUMBER_OF_ATTRIBUTES in 100 1000 10000;
do
	IMAGE_SIZE=$(( 16 * 1024 * 1024 ));

	IMAGE_FILE="${SPECIMENS_PATH}/xfs_${NUMBER_OF_ATTRIBUTES}_attributes_version_1.raw";

	create_test_image_file ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-i attr=1" "-L xfs_test" "-m crc=0";

	sudo mount -o loop,rw ${IMAGE_FILE} ${MOUNT_POINT};

	sudo chown ${USERNAME} ${MOUNT_POINT};

	create_test_file_entries ${MOUNT_POINT};

	touch ${MOUNT_POINT}/testdir1/many_xattrs;

	# Create additional extended attributes
	for NUMBER in `seq 1 ${NUMBER_OF_ATTRIBUTES}`;
	do
		setfattr -n "user.myxattr${NUMBER}" -v "Extended attribute: ${NUMBER}" ${MOUNT_POINT}/testdir1/many_xattrs;
	done

	sudo umount ${MOUNT_POINT};
done

# Create XFS file systems with many version 2 extended attributes
for NUMBER_OF_ATTRIBUTES in 100 1000 10000;
do
	IMAGE_SIZE=$(( 16 * 1024 * 1024 ));

	IMAGE_FILE="${SPECIMENS_PATH}/xfs_${NUMBER_OF_ATTRIBUTES}_attributes_version_2.raw";

	create_test_image_file ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} "-i attr=2" "-L xfs_test";

	sudo mount -o loop,rw ${IMAGE_FILE} ${MOUNT_POINT};

	sudo chown ${USERNAME} ${MOUNT_POINT};

	create_test_file_entries ${MOUNT_POINT};

	touch ${MOUNT_POINT}/testdir1/many_xattrs;

	# Create additional extended attributes
	for NUMBER in `seq 1 ${NUMBER_OF_ATTRIBUTES}`;
	do
		setfattr -n "user.myxattr${NUMBER}" -v "Extended attribute: ${NUMBER}" ${MOUNT_POINT}/testdir1/many_xattrs;
	done

	sudo umount ${MOUNT_POINT};
done

exit ${EXIT_SUCCESS};

