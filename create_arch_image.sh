#!/bin/bash
_mount_point=arch_img
_image_name=arch_arm64_lx2160.ext4
_root_dir=`pwd`
_pkgver=LSDK.21.08
_pkgrel=1

if [[ ! -f "$_image_name" ]]; then
	echo "Allocating image"
	truncate -s 4G $_image_name
	mkfs.ext4 $_image_name -b 4096
else
	echo "Skipping allocation. Image file already exists."
fi

echo "Mounting image"
mkdir -p $_mount_point
umount $_mount_point || /bin/true
mount $_image_name $_mount_point -o loop

echo "Copying image"
if [[ ! -f "ArchLinuxARM-aarch64-latest.tar.gz" ]]; then
	wget http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
fi
pushd $_mount_point
tar xzf ../ArchLinuxARM-aarch64-latest.tar.gz
popd


mkdir -p $_mount_point/root/lx2160_bootstrap

echo "Copying kernel packages"
cp linux-${_pkgver}-${_pkgrel}-aarch64.pkg.tar.xz $_mount_point/root/lx2160_bootstrap
cp linux-headers-${_pkgver}-${_pkgrel}-aarch64.pkg.tar.xz $_mount_point/root/lx2160_bootstrap

echo "Copying ftb"


echo "Creating startup script"
cat > $_mount_point/usr/lib/systemd/system/lx2160_bootstrap.service << EOF
[Unit]
Description=LX2160 bootstrap

[Service]
StandardOutput=journal+console
ExecStart=/root/lx2160_bootstrap/bootstrap.sh
Type=oneshot

[Install]
WantedBy=getty.target
EOF
if [ ! -f $_mount_point/etc/systemd/system/getty.target.wants/lx2160_bootstrap.service ]; then
	ln -s /usr/lib/systemd/system/lx2160_bootstrap.service $_mount_point/etc/systemd/system/getty.target.wants/lx2160_bootstrap.service
fi
cat > $_mount_point/root/lx2160_bootstrap/bootstrap.sh << EOF
#!/bin/bash
set -e
echo "Init keyring"
pacman-key --init
pacman-key --populate archlinuxarm
pacman -Sy
echo "Removing old kernel"
pacman --noconfirm -Sy
pacman --noconfirm -R --nodeps --nodeps linux-aarch64
echo "Installing kernel packages"
pacman --noconfirm -U linux-${_pkgver}-${_pkgrel}-aarch64.pkg.tar.xz linux-headers-${_pkgver}-${_pkgrel}-aarch64.pkg.tar.xz
echo "Removing bootstrap files"
rm -r /root/lx2160_bootstrap
rm /etc/systemd/system/getty.target.wants/lx2160_bootstrap.service
rm /usr/lib/systemd/system/lx2160_bootstrap.service
systemctl reboot
EOF
chmod +x $_mount_point/root/lx2160_bootstrap/bootstrap.sh

IMG="src/lx2160a_build/images/lx2160acex7_2000_700_3200_8_5_2-a393e2e.img"
#qemu-system-aarch64 -m 1G -M virt -cpu cortex-a57 -nographic -smp 1 -kernel pkg/linux/usr/lib/modules/5.10.35-1-00001-g695bca60dc33/Image -append "console=ttyAMA0,root=PARTUUID=30303030-01 rw rootwait" -netdev user,id=eth0 -device virtio-net-device,netdev=eth0 -initrd arch_img/boot/initramfs-linux.img -drive file=$IMG,if=none,format=raw,id=hd0 -device virtio-blk-device,drive=hd0 -no-reboot