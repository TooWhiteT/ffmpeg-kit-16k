#!/bin/bash

# INIT SUBMODULES
${SED_INLINE} 's|openssl/openssl|arthenica/openssl|g' "${BASEDIR}"/src/"${LIB_NAME}"/.gitmodules || return 1
${SED_INLINE} 's|tomato42|arthenica|g' "${BASEDIR}"/src/"${LIB_NAME}"/.gitmodules || return 1
${SED_INLINE} 's|warner|arthenica|g' "${BASEDIR}"/src/"${LIB_NAME}"/.gitmodules || return 1
${SED_INLINE} 's|gitlab.com/libidn/gnulib-mirror|github.com/arthenica/gnulib|g' "${BASEDIR}"/src/"${LIB_NAME}"/.gitmodules || return 1
${SED_INLINE} 's|gitlab.com/gnutls/libtasn1|github.com/arthenica/libtasn1|g' "${BASEDIR}"/src/"${LIB_NAME}"/.gitmodules || return 1
${SED_INLINE} 's|gitlab.com/gnutls/nettle|github.com/arthenica/nettle|g' "${BASEDIR}"/src/"${LIB_NAME}"/.gitmodules || return 1
${SED_INLINE} 's|gitlab.com/gnutls/abi-dump|github.com/arthenica/abi-dump|g' "${BASEDIR}"/src/"${LIB_NAME}"/.gitmodules || return 1
${SED_INLINE} 's|gitlab.com/gnutls/cligen|github.com/arthenica/cligen|g' "${BASEDIR}"/src/"${LIB_NAME}"/.gitmodules || return 1
${SED_INLINE} 's|gitlab.com/redhat-crypto/tests/interop|github.com/arthenica/redhat-crypto-tests-interop|g' "${BASEDIR}"/src/"${LIB_NAME}"/.gitmodules || return 1

# Newer autopoint rejects configure.ac files that contain both gettext
# version macros. The release still bootstraps correctly with VERSION only.
${SED_INLINE} '/m4_ifdef(\[AM_GNU_GETTEXT_REQUIRE_VERSION\],\[/d' "${BASEDIR}"/src/"${LIB_NAME}"/configure.ac || return 1
${SED_INLINE} '/AM_GNU_GETTEXT_REQUIRE_VERSION/d' "${BASEDIR}"/src/"${LIB_NAME}"/configure.ac || return 1
${SED_INLINE} '/AM_GNU_GETTEXT_VERSION(\[0.19\])/{n
/^])$/d
}' "${BASEDIR}"/src/"${LIB_NAME}"/configure.ac || return 1

# UPDATE BUILD FLAGS
export CFLAGS="$(get_cflags ${LIB_NAME}) -I${LIB_INSTALL_BASE}/libiconv/include"
export CXXFLAGS=$(get_cxxflags "${LIB_NAME}")
export LDFLAGS="$(get_ldflags ${LIB_NAME}) -L${LIB_INSTALL_BASE}/libiconv/lib"

export NETTLE_CFLAGS="-I${LIB_INSTALL_BASE}/nettle/include"
export NETTLE_LIBS="-L${LIB_INSTALL_BASE}/nettle/lib -lnettle -L${LIB_INSTALL_BASE}/gmp/lib -lgmp"
export HOGWEED_CFLAGS="-I${LIB_INSTALL_BASE}/nettle/include"
export HOGWEED_LIBS="-L${LIB_INSTALL_BASE}/nettle/lib -lhogweed -L${LIB_INSTALL_BASE}/gmp/lib -lgmp"
export GMP_CFLAGS="-I${LIB_INSTALL_BASE}/gmp/include"
export GMP_LIBS="-L${LIB_INSTALL_BASE}/gmp/lib -lgmp"

if [[ -x /opt/homebrew/opt/bison/bin/bison ]]; then
  export PARSE_DATETIME_BISON="/opt/homebrew/opt/bison/bin/bison"
elif [[ -x /usr/local/opt/bison/bin/bison ]]; then
  export PARSE_DATETIME_BISON="/usr/local/opt/bison/bin/bison"
fi

# SET BUILD OPTIONS
ASM_OPTIONS=""
case ${ARCH} in
x86)
  ASM_OPTIONS="--disable-hardware-acceleration"
  ;;
*)
  ASM_OPTIONS="--enable-hardware-acceleration"
  ;;
esac

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_gnutls} -eq 1 ]]; then
  ./bootstrap --skip-po || return 1
  git submodule update --remote gnulib || return 1
  overwrite_file ./gnulib/lib/fpending.c ./src/gl/fpending.c || return 1
fi

if ! grep -q "ffmpeg-kit android mktime_z fallback" "${BASEDIR}"/src/"${LIB_NAME}"/src/gl/nstrftime.c; then
  ${SED_INLINE} '/#define TM_YEAR_BASE 1900/a\
\
#if defined(__ANDROID__) && !defined(mktime_z)\
/* ffmpeg-kit android mktime_z fallback */\
# define mktime_z(tz, tm) mktime (tm)\
#endif' "${BASEDIR}"/src/"${LIB_NAME}"/src/gl/nstrftime.c || return 1
fi

./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --with-sysroot="${ANDROID_SYSROOT}" \
  --with-included-libtasn1 \
  --with-included-unistring \
  --without-idn \
  --without-p11-kit \
  ${ASM_OPTIONS} \
  --enable-static \
  --disable-openssl-compatibility \
  --disable-shared \
  --disable-fast-install \
  --disable-code-coverage \
  --disable-doc \
  --disable-manpages \
  --disable-guile \
  --disable-tests \
  --disable-tools \
  --disable-maintainer-mode \
  --disable-full-test-suite \
  --host="${HOST}" || return 1

if [[ -n ${PARSE_DATETIME_BISON} ]]; then
  make -C src/gl PARSE_DATETIME_BISON="${PARSE_DATETIME_BISON}" generate-parse-datetime || return 1
fi

make -C gl -j$(get_cpu_count) || return 1

make -C lib -j$(get_cpu_count) || return 1

make -C lib install || return 1

# CREATE PACKAGE CONFIG MANUALLY
create_gnutls_package_config "3.7.9" || return 1
