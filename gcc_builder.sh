echo "**GCC Cross-Compiler Builder**"
echo "**********MaestroCI***********"

GCC_OUTPUT_PATH=/home/baalajimaestro/gcc-bin
SRC_PATH=/home/baalajimaestro/src 
GCC_PATH=/home/baalajimaestro/gcc
TARGET=aarch64-maestro-linux-gnu

rm -rf $GCC_OUTPUT_PATH && mkdir $GCC_OUTPUT_PATH && cd $GCC_OUTPUT_PATH && rm -rf /tmp/build-*
rm -rf $SRC_PATH 

mkdir $SRC_PATH
cd $SRC_PATH

echo "Cloning Binutils...."
git clone git://sourceware.org/git/binutils-gdb.git --depth=1 binutils
cd $GCC_PATH

echo "Updating GCC to latest head...."

case $1 in

  master)
    git checkout master
    git clean -f
    rm -rf build*
    rm -rf build
    git pull origin master
    ;;
  gcc-9)
    git checkout releases/gcc-9
    git clean -f 
    git pull origin releases/gcc-9
    ;;
  *)
    echo "Cant build specified branch!"
    exit 1
    ;;
esac

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
make install &> /dev/null || make install

echo "Building Linux Headers....."
cd $SRC_PATH/linux
make ARCH=arm64 INSTALL_HDR_PATH=$GCC_OUTPUT_PATH/$TARGET  headers_install &> /dev/null || make ARCH=arm64 INSTALL_HDR_PATH=$GCC_OUTPUT_PATH/$TARGET  headers_install

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
--build=$MACHTYPE \
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
make install > /dev/null


