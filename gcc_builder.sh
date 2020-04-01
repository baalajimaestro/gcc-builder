echo "**GCC Cross-Compiler Builder**"
echo "**********MaestroCI***********"

GCC_OUTPUT_PATH=/build/gcc-bin
SRC_PATH=/build/src 
GCC_PATH=/build/gcc
TARGET=$1

function sendTG() {
    curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendmessage" --data "text=${*}&chat_id=-1001427544283&disable_web_page_preview=true&parse_mode=Markdown" > /dev/null
}

rm -rf $GCC_OUTPUT_PATH && mkdir $GCC_OUTPUT_PATH && cd $GCC_OUTPUT_PATH && rm -rf /tmp/build-*
rm -rf $SRC_PATH 

mkdir $SRC_PATH
cd $SRC_PATH

echo "Cloning Binutils...."
git clone git://sourceware.org/git/binutils-gdb.git --depth=1 binutils
cd $GCC_PATH

echo "Updating GCC to latest head...."

cd $SRC_PATH 
echo "Getting Linux Tarball...."
git clone https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/ -b linux-4.19.y --depth=1

echo "Getting Glibc from sourceware....."
git clone git://sourceware.org/git/glibc.git --depth=1 -b master

echo "Cloning MPFR...."
curl -sLo mpfr.tar.xz https://www.mpfr.org/mpfr-current/mpfr-4.0.2.tar.xz

echo "Cloning GMP...."
curl -sLo gmp.tar.xz https://gmplib.org/download/gmp/gmp-6.2.0.tar.xz

echo "Cloning MPC...."
curl -sLo mpc.tar.gz https://ftp.gnu.org/gnu/mpc/mpc-1.1.0.tar.gz

echo "Cloning ISL...."
curl -sLo isl.tar.xz http://isl.gforge.inria.fr/isl-0.22.1.tar.xz

for f in *.tar*; do tar xvf $f; done

cd $GCC_PATH

ln -s $SRC_PATH/gmp-6.2.0 gmp
ln -s $SRC_PATH/mpc-1.1.0 mpc 
ln -s $SRC_PATH/mpfr-4.0.2 mpfr 
ln -s $SRC_PATH/isl-0.22.1 isl 

export PATH=$GCC_OUTPUT_PATH/bin:$PATH

echo "Building Binutils...."
cd $SRC_PATH/binutils 
mkdir /tmp/build-binutils && cd /tmp/build-binutils
$SRC_PATH/binutils/configure --prefix=$GCC_OUTPUT_PATH --target=$TARGET --disable-multilib > /dev/null
make -j8 &> /dev/null || make -j8
make install-strip &> /dev/null || make install

echo "Building Linux Headers....."
cd $SRC_PATH/linux
make ARCH=arm64 INSTALL_HDR_PATH=$GCC_OUTPUT_PATH/$TARGET  headers_install &> /dev/null || make ARCH=arm64 INSTALL_HDR_PATH=$GCC_OUTPUT_PATH/$TARGET  headers_install

while true; do echo "Building Cross-Compiler in Progress....."; sleep 120; done &

echo "Building GCC..."
mkdir /tmp/build-gcc
cd /tmp/build-gcc 

$GCC_PATH/configure \
--prefix=$GCC_OUTPUT_PATH \
--target=$TARGET \
--disable-shared \
--disable-nls \
--disable-bootstrap \
--disable-browser-plugin \
--disable-cloog-version-check \
--disable-isl-version-check \
--disable-libgomp \
--disable-libitm \
--disable-libmudflap \
--disable-libsanitizer \
--disable-libssp \
--disable-libstdc__-v3 \
--disable-multilib \
--disable-ppl-version-check \
--disable-sjlj-exceptions \
--disable-vtable-verify \
--disable-werror \
--enable-gold \
--enable-lto \
--enable-checking=yes \
--enable-graphite=yes \
--enable-plugins \
--enable-languages=c \
--prefix=$GCC_OUTPUT_PATH \
--with-gmp=$GCC_PATH/gmp \
--with-mpfr=$GCC_PATH/mpfr \
--with-mpc=$GCC_PATH/mpc \
--with-isl=$GCC_PATH/isl > /dev/null

echo "Building GCC Step-1...."
make -j8 all-gcc > /dev/null
make install-gcc > /dev/null
echo "Built GCC...."

mkdir /tmp/build-glibc && cd /tmp/build-glibc

echo "Building GLIBC Stage-1...."
$SRC_PATH/glibc/configure \
--prefix=$GCC_OUTPUT_PATH/$TARGET \
--build=$MACHTYPE \$(date +%d%m%y)
--host=$TARGET \
--target=$TARGET \
--with-headers=$GCC_OUTPUT_PATH/$TARGET/include \
--disable-multilib libc_cv_forced_unwind=yes > /dev/null

make install-bootstrap-headers=yes install-headers > /dev/null
make -j8 csu/subdir_lib > /dev/null
install csu/crt1.o csu/crti.o csu/crtn.o $GCC_OUTPUT_PATH/$TARGET/lib > /dev/null
$TARGET-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o $GCC_OUTPUT_PATH/$TARGET/lib/libc.so > /dev/null
touch $GCC_OUTPUT_PATH/$TARGET/include/gnu/stubs.h

echo "Building GCC Stage-2...."
cd /tmp/build-gcc 
make -j8 all-target-libgcc > /dev/null
make install-target-libgcc > /dev/null

echo "Building GCC Stage-3...."
cd /tmp/build-glibc
make -j8 > /dev/null
make install-strip > /dev/null

jobs
kill %1

if [[ -n $(${GCC_OUTPUT_PATH}/${TARGET}/bin/${TARGET}-gcc --version) ]]; then 
cd ${GCC_OUTPUT_PATH}/${TARGET}
git init
git add .
git commit -m "MaestroCI: ${TARGET}-$2 $(date +%d%m%y)" --signoff
if [[ "$2" == "master" ]]; then
git checkout -b $(date +%d%m%y)
if [[ "$1" == "aarch64-maestro-linux-gnu" ]]; then
git remote add origin https://baalajimaestro:${GH_PERSONAL_TOKEN}@github.com/baalajimaestro/aarch64-maestro-linux-android.git
sendTG "`Pushing GCC ${TARGET} to `[link](https://github.com/baalajimaestro/aarch64-maestro-linux-android.git)%0A%0A`Branch: $(date +%d%m%y)`"
else
git remote add origin https://baalajimaestro:${GH_PERSONAL_TOKEN}@github.com/baalajimaestro/arm-maestro-linux-gnueabi.git
sendTG "`Pushing GCC ${TARGET} to `[link](https://github.com/baalajimaestro/arm-maestro-linux-gnueabi.git)%0A%0A`Branch: $(date +%d%m%y)`"
fi
git push -f origin $(date +%d%m%y)
else
git checkout -b $(date +%d%m%y)-9
if [[ "$1" == "aarch64-maestro-linux-gnu" ]]; then
git remote add origin https://baalajimaestro:${GH_PERSONAL_TOKEN}@github.com/baalajimaestro/aarch64-maestro-linux-android.git
sendTG "`Pushing GCC ${TARGET} to `[link](https://github.com/baalajimaestro/aarch64-maestro-linux-android.git)%0A%0A`Branch: $(date +%d%m%y)`"
else
git remote add origin https://baalajimaestro:${GH_PERSONAL_TOKEN}@github.com/baalajimaestro/arm-maestro-linux-gnueabi.git
sendTG "`Pushing GCC ${TARGET} to `[link](https://github.com/baalajimaestro/arm-maestro-linux-gnueabi.git)%0A%0A`Branch: $(date +%d%m%y)`"
fi
git push -f origin $(date +%d%m%y)-9
fi
