# Maintainer: Jan Alexander Steffens (heftig) <heftig@archlinux.org>
# todo: change mkinitcpio

pkgbase=linux
pkgver=6.6.52
_pkgver=lf-6.6.52-2.2.0
pkgrel=1
pkgdesc='Linux for SolidRun LX2160A'
url="https://github.com/nxp-qoriq/linux/tree/${_pkgver}"
arch=('aarch64')
license=(GPL2)
makedepends=(
  7zip mtools acpica uboot-tools cpio bison flex
  #e2tools # not strictly necessary
  make gcc diffutils
  bc kmod libelf pahole perl tar xz
  graphviz imagemagick
  git
)
options=('!strip')
#_srcname=solidrun-lx2160-linux
source=()
validpgpkeys=(
  'ABAF11C65A2970B130ABE3C479BE3E4300411886'  # Linus Torvalds
  '647F28654894E3BD457199BE38DBBDC86092693E'  # Greg Kroah-Hartman
  'A2FF3A36AAA56654109064AB19802F8B0D70FC30'  # Jan Alexander Steffens (heftig)
)
sha256sums=()

_procn=$(getconf _NPROCESSORS_ONLN)
export KBUILD_BUILD_HOST=archlinux
export KBUILD_BUILD_USER=$pkgbase
export KBUILD_BUILD_TIMESTAMP="$(date -Ru${SOURCE_DATE_EPOCH:+d @$SOURCE_DATE_EPOCH})"

_strip="strip"
#_strip="aarch64-linux-gnu-strip"
#export CROSS_COMPILE=aarch64-linux-gnu-
#export ARCH=arm64

# todo: check with https://github.com/void-linux/void-packages/pull/8546/files
# todo: run make mrproper to remove scripts in host binary format (https://patchwork.openembedded.org/patch/146459/)
# todo: make scripts & make modules_prepare on post_install of cross-compiled

prepare() {
  echo "Cloning lx2160a build files"
  if [ ! -d "lx2160a_build" ]; then
    git clone --depth 1 -b develop-ls-6.6.52-2.2.0 https://github.com/SolidRun/lx2160a_build.git
  fi

  echo "Cloning linux kernel"
  if [ ! -d "linux" ]; then
    git clone --depth 1 -b ${_pkgver} https://github.com/nxp-qoriq/linux
  else
    pushd $srcdir/linux > /dev/null
    echo "Warning: Linux kernel source directory already exists. Moving HEAD."
    git checkout ${_pkgver}
    popd > /dev/null
  fi
  
  cd $srcdir/linux

  local src
  for src in $srcdir/lx2160a_build/patches/linux/*.patch; do
    echo "Applying patch $src..."
    git am $src
  done

  echo "Setting config..."
  ./scripts/kconfig/merge_config.sh arch/arm64/configs/defconfig arch/arm64/configs/lsdk.config $srcdir/lx2160a_build/configs/linux/lx2k_additions.config $srcdir/../lx2k_additions.config

  echo "Setting version..."
  echo "-$pkgrel" > localversion.10-pkgrel
  echo "${pkgbase#linux}" > localversion.20-pkgname
  make -s kernelrelease > version
#
#  local src
#  for src in "${source[@]}"; do
#    src="${src%%::*}"
#    src="${src##*/}"
#    [[ $src = *.patch ]] || continue
#    echo "Applying patch $src..."
#    patch -Np1 < "../$src"
#  done
#
#  echo "Setting config..."
#  cp ../config .config
#  make olddefconfig
#

  echo "Prepared $pkgbase version $(<version)"
}

build() {
  cd $srcdir/linux
  make -j${_procn} all
}

_package() {
  pkgdesc="The $pkgdesc kernel and modules"
  depends=(coreutils kmod initramfs)
  optdepends=('crda: to set the correct wireless channels of your country'
              'linux-firmware: firmware images needed for some devices')
  provides=("linux=${pkgver}" WIREGUARD-MODULE)
  replaces=('linux-armv8')
  conflicts=('linux')
  backup=("etc/mkinitcpio.d/${pkgbase}.preset")

  cd $srcdir/linux
  local kernver="$(<version)"
  local modulesdir="$pkgdir/usr/lib/modules/$kernver"

  echo "Installing boot image..."
  # systemd expects to find the kernel here to allow hibernation
  # https://github.com/systemd/systemd/commit/edda44605f06a41fb86b7ab8128dcf99161d2344
  install -Dm644 "$(make -s image_name)" "$modulesdir/vmlinuz"

  install -Dm644 arch/arm64/boot/Image "$modulesdir/Image"
  install -Dm644 arch/arm64/boot/Image "$pkgdir/boot/Image"
  install -Dm644 arch/arm64/boot/dts/freescale/*.dtb -t "${pkgdir}/boot"

  # Used by mkinitcpio to name the kernel
  echo "$pkgbase" | install -Dm644 /dev/stdin "$modulesdir/pkgbase"

  echo "Installing modules..."
  make INSTALL_MOD_PATH="$pkgdir/usr" INSTALL_MOD_STRIP=1 modules_install

  # remove build and source links
  rm "$modulesdir"/{source,build}

  local _subst="
    s|%PKGBASE%|${pkgbase}|g
    s|%KERNVER%|${kernver}|g
  "

  # install mkinitcpio preset file
  sed "${_subst}" "$srcdir/../linux.preset" |
    install -Dm644 /dev/stdin "${pkgdir}/etc/mkinitcpio.d/${pkgbase}.preset"
}

_package-headers() {
  pkgdesc="Headers and scripts for building modules for the $pkgdesc kernel"
  depends=(pahole)

  cd $srcdir/linux
  local builddir="$pkgdir/usr/lib/modules/$(<version)/build"

  echo "Installing build files..."
  install -Dt "$builddir" -m644 .config Makefile Module.symvers System.map \
    localversion.* version vmlinux
  install -Dt "$builddir/kernel" -m644 kernel/Makefile
  install -Dt "$builddir/arch/arm64" -m644 arch/arm64/Makefile

  # required for out-of-tree kernel modules
  #  keep arch/x86/ras/Kconfig as it is needed by drivers/ras/Kconfig
  install -Dt "$builddir/arch/x86/ras/Kconfig" -m644 arch/x86/ras/Kconfig 
  install -Dt "$builddir/tools/include/tools" -m644 tools/include/tools/*
  install -Dt "$builddir/arch/arm64/kernel/vdso" -m644 arch/arm64/kernel/vdso/*
  mkdir -p $builddir/lib/vdso
  cp -t "$builddir/lib/vdso" lib/vdso/*
  install -Dt "$builddir/lib/vdso" -m644 lib/vdso/* # todo: copy only what is needed

  cp -t "$builddir" -a scripts


  # add xfs and shmem for aufs building
  mkdir -p "$builddir"/{fs/xfs,mm}

  echo "Installing headers..."
  cp -t "$builddir" -a include
  cp -t "$builddir/arch/arm64" -a arch/arm64/include
  install -Dt "$builddir/arch/arm64/kernel" -m644 arch/arm64/kernel/asm-offsets.s

  install -Dt "$builddir/drivers/md" -m644 drivers/md/*.h
  install -Dt "$builddir/net/mac80211" -m644 net/mac80211/*.h

  # http://bugs.archlinux.org/task/13146
  install -Dt "$builddir/drivers/media/i2c" -m644 drivers/media/i2c/msp3400-driver.h

  # http://bugs.archlinux.org/task/20402
  install -Dt "$builddir/drivers/media/usb/dvb-usb" -m644 drivers/media/usb/dvb-usb/*.h
  install -Dt "$builddir/drivers/media/dvb-frontends" -m644 drivers/media/dvb-frontends/*.h
  install -Dt "$builddir/drivers/media/tuners" -m644 drivers/media/tuners/*.h

  echo "Installing KConfig files..."
  find . -name 'Kconfig*' -exec install -Dm644 {} "$builddir/{}" \;

  echo "Removing unneeded architectures..."
  local arch
  for arch in "$builddir"/arch/*/; do
    [[ $arch = */arm64/ ]] && continue
    echo "Removing $(basename "$arch")"
    rm -r "$arch"
  done

  echo "Removing documentation..."
  rm -r "$builddir/Documentation"

  echo "Removing broken symlinks..."
  find -L "$builddir" -type l -printf 'Removing %P\n' -delete

  echo "Removing loose objects..."
  find "$builddir" -type f -name '*.o' -printf 'Removing %P\n' -delete

  echo "Stripping build tools..."
  local file
  while read -rd '' file; do
    case "$(file -bi "$file")" in
      application/x-sharedlib\;*)      # Libraries (.so)
        $_strip -v $STRIP_SHARED "$file" ;;
      application/x-archive\;*)        # Libraries (.a)
        $_strip -v $STRIP_STATIC "$file" ;;
      application/x-executable\;*)     # Binaries
        $_strip -v $STRIP_BINARIES "$file" ;;
      application/x-pie-executable\;*) # Relocatable binaries
        $_strip -v $STRIP_SHARED "$file" ;;
    esac
  done < <(find "$builddir" -type f -perm -u+x ! -name vmlinux -print0)

  echo "Stripping vmlinux..."
  $_strip -v $STRIP_STATIC "$builddir/vmlinux"

  echo "Adding symlink..."
  mkdir -p "$pkgdir/usr/src"
  ln -sr "$builddir" "$pkgdir/usr/src/$pkgbase"
}

pkgname=("$pkgbase" "$pkgbase-headers")
for _p in "${pkgname[@]}"; do
  eval "package_$_p() {
    $(declare -f "_package${_p#$pkgbase}")
    _package${_p#$pkgbase}
  }"
done

# vim:set ts=8 sts=2 sw=2 et:
