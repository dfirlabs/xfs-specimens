#!/bin/bash

EXIT_SUCCESS=0
EXIT_FAILURE=1

SPECIMENS_PATH="specimens"

if test -d ${SPECIMENS_PATH}
then
	echo "Specimens directory: ${SPECIMENS_PATH} already exists."

	exit ${EXIT_FAILURE}
fi

mkdir -p ${SPECIMENS_PATH}

# Notes:
# * 26.04 has the same version of mkfs.xfs as 24.04

VERSIONS=("14.04" "16.04" "18.04" "20.04" "22.04" "24.04")
SPECIMENS_PATH="${PWD}/${SPECIMENS_PATH}"

CURRENT_GID=$( id -g )
CURRENT_UID=$( id -u )

set -e

for VERSION in ${VERSIONS[@]}
do
	TAG="xfs-specimens/ubuntu${VERSION}"

	docker build \
	    --build-arg GID=${CURRENT_GID} \
	    --build-arg UID=${CURRENT_UID} \
	    --build-arg VERSION=${VERSION} \
	    -f docker/ubuntu.Dockerfile \
	    -t ${TAG} \
	    .

	docker run \
	    --privileged=true \
	    -u ${CURRENT_UID}:${CURRENT_GID} \
	    -v /dev/loop-control:/dev/loop-control \
	    -v ${SPECIMENS_PATH}:/home/ubuntu/specimens:z \
	    ${TAG} \
	    ./generate-specimens-linux.sh
	    # /bin/bash -c "bash -x ./generate-specimens-linux.sh"
done

exit ${EXIT_SUCCESS}
