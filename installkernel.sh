echo Backing up previous kernel
tar -cf - /lib/modules /media/boot | zstd -4 -T2 > /root/kernel-backup-`date +%Y%m%d-%H%M`.tar.zst

echo Deleting old kernel
rm -fr /media/boot/* /lib/modules/*

echo Installing new kernel
make modules_install && sync
make install
mv /boot/* /media/boot && sync
cp arch/arm64/boot/dts/rockchip/rk3399-odroid-n1.dtb /media/boot && sync
cp /home/darkbahamut/Desktop/boot.scr /media/boot && sync

