#!/usr/bin/env bash

# Base paths
BASENAME=$(basename "${0}")
BASEPATH=$(dirname "${0}")
CURPATH=$(pwd)

function fatal() {
	echo "FATAL ERROR: $@"
	exit 1
}

# Apps
NPROC=$(which nproc 2>/dev/null) || fatal "I need nproc!"
GIT=$(which git 2>/dev/null) || fatal "I need git!"
MAKE=$(which make 2>/dev/null) || fatal "I need make!"

# Process args
MK_PREPARE=0
MK_IMAGE=0
MK_MODULES=0
MK_INSTALL=0
MK_CLEAN=0
MK_PATH="${CURPATH}"
while (( "$#" )); do
	ARG1=$(echo "${1}" | awk '{$1=$1;print}')
	ARG2=$(echo "${2}" | awk '{$1=$1;print}')
	case "${ARG1}" in
                --prepare)
                        MK_PREPARE=1
                        shift ;;

		--image)
                        MK_IMAGE=1
                        shift ;;
                
                --modules)
                        MK_MODULES=1
                        shift ;;
                
                --install)
                        MK_INSTALL=1
                        shift ;;

                --full)
                        MK_PREPARE=1
                        MK_IMAGE=1
                        MK_MODULES=1
                        MK_INSTALL=1
                        shift ;;
                
                --clean)
                        MK_CLEAN=1
                        shift ;;
                
                --src)
                        [ -z "${ARG2}" ] && fatal "--path requires <path>"
                        MK_PATH="${ARG2}"
                        shift 2 ;;
                
                *)
                        fatal "Unknown arg: ${ARG1}"
        esac
done

function cleanup() {
        popd || exit 1
}

# Setup cleanup handler
trap cleanup EXIT

# Switch to kernel source path (may be pwd)
pushd "${MK_PATH}" || fatal "pushd(${MK_PATH}) failed"

# Check we have a config
[ -f ".config" ] || fatal "No .config in pwd"

# Defaults
MK_FILE="Makefile"
MK_NPROCS=$(${NPROC} --all)

# Get some version information
GIT_HASH=$(${GIT} show -s --format=%h)
GIT_BRANCH=$(${GIT} branch | sed -n '/\* /s///p')
GIT_DETACHED=$(echo "${GIT_BRANCH}" | grep "detached at" | cut -d "(" -f2 | cut -d ")" -f1 | sed -e 's/[ \/]/_/g')
if [ ! -z "${GIT_DETACHED}" ]; then
        GIT_BRANCH="${GIT_DETACHED}"
else
        GIT_BRANCH=${GIT_BRANCH//\//__}
fi

# Generate new version information
EXTRA_VERSION=$(grep -E "^EXTRAVERSION" "${MK_FILE}" | sed -e 's/^EXTRAVERSION = //g')
EXTRA_VERSION="${EXTRA_VERSION}.${GIT_HASH}.${GIT_BRANCH}"

# Run a build
NUM_PROCS=$(( "${MK_NPROCS}" + 0 ))
MK_COMMAND="${MAKE} EXTRAVERSION=${EXTRA_VERSION} -j${NUM_PROCS}"
MK_VERSION=$(${MK_COMMAND} -s kernelrelease)

echo "MK_VERSION=${MK_VERSION}"
echo "MK_IMAGE=${MK_IMAGE} MK_MODULES=${MK_MODULES} MK_INSTALL=${MK_INSTALL} MK_CLEAN=${MK_CLEAN} NUM_PROCS=${NUM_PROCS}"
sleep 1

if [ "${MK_PREPARE}" -gt 0 ]; then
        ${MK_COMMAND} oldconfig || fatal "make oldconfig failed"
        ${MK_COMMAND} prepare || fatal "make prepare failed"
fi
if [ "${MK_IMAGE}" -gt 0 ]; then
        ${MK_COMMAND} || fatal "make image failed"
fi
if [ "${MK_MODULES}" -gt 0 ]; then
        ${MK_COMMAND} modules || fatal "make modules failed"
fi
if [ "${MK_INSTALL}" -gt 0 ]; then
        ${MK_COMMAND} modules_install || fatal "make modules_install failed"
        ${MK_COMMAND} install || fatal "make install failed"
fi
if [ "${MK_CLEAN}" -gt 0 ]; then
        ${MK_COMMAND} clean || fatal "make clean failed"
fi
