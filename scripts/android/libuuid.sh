#!/bin/bash

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_libuuid} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

# libuuid checks HAVE_SYS_FILE_H before including config.h. Newer Clang
# versions in NDK 28 reject the resulting implicit flock() declaration.
if ! grep -q "ffmpeg-kit ndk28 config include patch" "${BASEDIR}"/src/"${LIB_NAME}"/gen_uuid.c; then
  ${SED_INLINE} '/#ifdef HAVE_UNISTD_H/i\
/* ffmpeg-kit ndk28 config include patch */\
#ifdef HAVE_CONFIG_H\
#include "config.h"\
#endif\
' "${BASEDIR}"/src/"${LIB_NAME}"/gen_uuid.c || return 1
fi

./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --with-sysroot="${ANDROID_SYSROOT}" \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --host="${HOST}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

# CREATE PACKAGE CONFIG MANUALLY
create_uuid_package_config "1.0.3" || return 1
