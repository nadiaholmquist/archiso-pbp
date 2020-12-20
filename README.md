# archiso for Pinebook Pro

This repository contains a customized archiso preset for building images for the Pinebook Pro ARM laptop. Pre-built images are available [here](https://github.com/nadiaholmquist/archiso-pbp/releases).

Building the image should be possible on aarch64 platforms like the Pinebook Pro itself, as well as other architectures. For building to work on non-aarch64, you'll need `qemu-user-static` and `binfmt-qemu-static`.

PKGBUILDs for the packages used in this image can be found [here](https://github.com/nadiaholmquist/pbp-packages).

Check out the [FAQ](./FAQ.md) for common issues you may encounter.

## Building
Building the image is fairly straightforward, install `archiso`, `multipath-tools`, and the qemu packages if you need them, then clone this repository and run `build.sh` as root.

If all goes well, an `.img` file will be placed in the `out` directory, and should be ready to be written to an SD card or USB stick.

## Installation
The instructions in installation guide in `/root` mostly apply, however there are some things specific to the Pinebook Pro to be aware of:

 * The SD card is `/dev/mmcblk1`, eMMC is `mmcblk2` and USB storage will be `/dev/sdX`.
 * You must leave around 16MB or more of free space before your first partition if you are installing to the eMMC, u-boot will be written here.
 * U-boot looks for a file called `extlinux.conf` in `/extlinux`, or `/boot/extlinux` on the first partition marked bootable on the eMMC, an example configuration is provided below.
 * Currently, the regular `linux-aarch64` and `linux-aarch64-rc` kernels don't work, until this is sorted out you can use the `pinebookpro` repository included in the image (see `/etc/pacman.conf`) and install `linux-pbp` from it.
 * `ap6256-firmware` is needed for the Wi-Fi and Bluetooth to function, and `pbp-keyboard-hwdb` for the brightness control shortcuts to work correctly, both can be installed from the `pinebookpro` repo.
 * The `pinebookpro` repo will be missing from the target system's `pacman.conf`, make sure to edit it and add this if you want to use my prebuilt packages
 ```
 [pinebookpro]
 Server = https://nhp.sh/pinebookpro/
 ```

### Writing u-boot to the eMMC
The Pinebook Pro currently uses u-boot as its bootloader, you can install it with the `uboot-pbp` package in the `pinebookpro` repo. Two files will be placed in `/boot` that need to be written to the eMMC, `idbloader.img` at sector 64 and `u-boot.itb` at sector 16384, they can be installed like this:
```
dd if=/boot/idbloader.img of=/dev/mmcblk2 seek=64
dd if=/boot/u-boot.itb of=/dev/mmcblk2 seek=16384
```

### Extlinux configuration
Here is a sample `extlinux.conf` file:
```
LABEL Arch Linux ARM
KERNEL ../Image
FDT ../dtbs/rockchip/rk3399-pinebook-pro.dtb
APPEND initrd=../initramfs-linux.img console=tty1 rootwait root=UUID=<UUID> rw
```
Place this example configuration in a directory named `extlinux` in `/boot`. Remember to replace `<UUID>` with your actual partition UUID, or use one of the other options for specifying the root filesystem.
