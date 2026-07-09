#!/usr/bin/env bash
set -eo pipefail

./bootstrap

# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* ./conftools

CFLAGS="${CFLAGS} -I${PREFIX}/include/pango-1.0 -I${PREFIX}/include/harfbuzz -I${PREFIX}/include/cairo"

./configure \
    "--prefix=${PREFIX}" \
    "--with-systemdsystemunitdir=${PREFIX}/lib/systemd/system" \
    --disable-python \
    --disable-perl \
    --disable-ruby \
    --disable-lua \
    --disable-tcl \
    --disable-docs || (cat config.log && exit 1)

make "-j${CPU_COUNT}"

XFAIL_TESTS=""
if [[ "$(uname)" == "Darwin" && "${PKG_VERSION}" == "1.7.2" ]]; then
    # Known failure, should be fixed in the next version
    # https://github.com/oetiker/rrdtool-1.x/issues/1012
    XFAIL_TESTS="${XFAIL_TESTS} rpn2"
fi

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR}" != "" ]]; then
make check XFAIL_TESTS="${XFAIL_TESTS}" || (cat tests/test-suite.log && exit 1)
fi

make install

# "make check" runs rrdtool, which makes fontconfig write a host-specific
# cache under $PREFIX/var/cache; drop it so it does not ship in the package.
rm -rf "${PREFIX}/var/cache/fontconfig"
