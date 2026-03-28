ARG KEEP_ON_FAIL=false
FROM scratch
ADD ArchLinuxARM-aarch64-latest.tar.gz /

# Disable pacman's Landlock/alpm sandbox — not supported under QEMU user emulation
RUN sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf

# Bootstrap pacman keyring, drop pre-installed kernel, update
RUN pacman-key --init && \
    pacman-key --populate archlinuxarm && \
    pacman -Rdd --noconfirm $(pacman -Qq | grep '^linux') 2>/dev/null || true && \
    pacman -Syu --noconfirm && \
    pacman -S --noconfirm --needed git wget base-devel

RUN mkdir -p /build/src /build/pkg /etc/makepkg.d && \
    git config --file /etc/makepkg.d/gitconfig user.email "build@local" && \
    git config --file /etc/makepkg.d/gitconfig user.name "lx2160 builder" && \
    git config --file /etc/makepkg.d/gitconfig safe.directory '*'
COPY PKGBUILD lx2k_additions.config linux.preset /build/

RUN source /build/PKGBUILD && pacman -S --noconfirm --needed "${makedepends[@]}"

RUN sed -i '0,/if (( EUID == 0 ))/s/if (( EUID == 0 ))/if false/' /usr/bin/makepkg && \
    cd /build && \
    PACKAGER="lx2160-builder <build@local>" \
    makepkg --nodeps --noconfirm --noprogressbar \
    || $KEEP_ON_FAIL