#!/usr/bin/env bash

# Base paths
BASENAME=$(basename "${0}")
BASEPATH=$(dirname "${0}")
CURPATH=$(pwd)
TMPNAME=".tmp.XXXXXX"

function fatal() {
	echo "FATAL ERROR: $@"
	exit 1
}

# Apps
NPROC=$(which nproc 2>/dev/null) || fatal "I need nproc!"
GIT=$(which git 2>/dev/null) || fatal "I need git!"
MAKE=$(which make 2>/dev/null) || fatal "I need make!"

# Process args
MK_IMAGE=0
MK_MODULES=0
MK_INSTALL=0
MK_CLEAN=0
MK_PATH="${CURPATH}"
while (( "$#" )); do
	ARG1=$(echo "${1}" | awk '{$1=$1;print}')
	ARG2=$(echo "${2}" | awk '{$1=$1;print}')
	case "${ARG1}" in
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
        rm -rf ".tmp.*"
        popd || exit 1
}

# Setup cleanup handler
trap cleanup EXIT

# Switch to kernel source path (may be pwd)
pushd "${MK_PATH}" || fatal "pushd(${MK_PATH}) failed"

# Check we have a config
[ -f ".config" ] || fatal "No .config in pwd"

# Defaults
MK_FILE_SRC="Makefile"
MK_FILE_TMP=$(mktemp "${TMPNAME}")
MK_ARCH=$(uname -m)
MK_NPROCS=$(${NPROC} --all)

# Get some version information
GIT_HASH=$(${GIT} show -s --format=%h)
GIT_BRANCH=$(${GIT} branch | sed -n '/\* /s///p')
GIT_DETACHED=$(echo "${GIT_BRANCH}" | grep "detached at" | cut -d "(" -f2 | cut -d ")" -f1 | sed -e 's/[ \/]/_/g')
[ ! -z "${GIT_DETACHED}" ] && GIT_BRANCH="${GIT_DETACHED}"

# Generate new version information
EXTRA_VERSION=$(grep -E "^EXTRAVERSION" "${MK_FILE_SRC}" | sed -e 's/^EXTRAVERSION = //g')
BUILD_VERSION="${EXTRA_VERSION}.${GIT_HASH}(${GIT_BRANCH}).${MK_ARCH}"

# Write the version info
cp -f "${MK_FILE_SRC}" "${MK_FILE_TMP}" || fatal "Copy Makefile failed"
sed -i "s@^EXTRAVERSION.*@EXTRAVERSION = ${BUILD_VERSION}@" "${MK_FILE_TMP}"

# Run a build
NUM_PROCS=$(( "${MK_NPROCS}" + 0 ))
echo "EXTRAVERSION = ${BUILD_VERSION}"
echo "MK_IMAGE=${MK_IMAGE} MK_MODULES=${MK_MODULES} MK_INSTALL=${MK_INSTALL} MK_CLEAN=${MK_CLEAN} NUM_PROCS=${NUM_PROCS}"
sleep 1

if [ "${MK_IMAGE}" -gt 0 ]; then
        ${MAKE} -f "${MK_FILE_TMP}" -j${NUM_PROCS} || fatal "make image failed"
fi
if [ "${MK_MODULES}" -gt 0 ]; then
        ${MAKE} -f "${MK_FILE_TMP}" -j${NUM_PROCS} modules || fatal "make modules failed"
fi
if [ "${MK_INSTALL}" -gt 0 ]; then
        ${MAKE} -f "${MK_FILE_TMP}" -j${NUM_PROCS} modules_install || fatal "make modules_install failed"
        ${MAKE} -f "${MK_FILE_TMP}" -j${NUM_PROCS} install || fatal "make install failed"
fi
if [ "${MK_CLEAN}" -gt 0 ]; then
        ${MAKE} -f "${MK_FILE_TMP}" -j${NUM_PROCS} clean || fatal "make clean failed"
fi
