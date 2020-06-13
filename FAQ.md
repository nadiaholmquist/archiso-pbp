# Frequently asked questions

## Nothing happens when I press the power button
The version of u-boot packaged in the repo is upstream 2020.07, which doesn't turn on the power LED when it starts, give it about 15 seconds and the kernel should start and turn the LED green.

## No video output before `/` is mounted
Unlike on x86 machines, the drivers for display are required for anything to be displayed at all during early boot. To include them in your initrd, add the `drm`, `rockchipdrm`, `panel_simple` and `pwm_bl` modules to your `/etc/mkinitcpio.conf` and run `mkinitcpio -P`.

## There's no sound
The DACs for audio input are muted by default, run `alsamixer` (from `alsa-utils`) and unmute the left and right headphone DAC, and also turn the control labeled just "DAC" all the way up.

For headphone jack detection to work, you also need to install the `pinebookpro-audio` package from the `pinebookpro` repo, and enable acpid.

## The brightness shortcuts don't work
Install `pinebookpro-keyboard-hwdb` and then either run `systemd-hwdb update; udevadm trigger` or reboot.

## Pine/Super + arrow keys isn't registered
This is a bug in the default keyboard firmware, you can fix it by using a customized version from [here](https://github.com/jackhumbert/pinebook-pro-keyboard-updater). Follow the instructions for the revised firmware.

## The `pinebookpro` repo is missing in the installed system
The `pacman.conf` installed when running `pacstrap` is the default one from Arch Linux ARM, so it won't include the custom repo. Add the following to it after the entry for the `aur` repo:
```
[pinebookpro]
Server = https://nhp.sh/pinebookpro/
SigLevel = Optional
```

## I used the `extlinux.conf` example and the system doesn't boot
Make sure the paths in it are correct, if you use a separate `/boot` partition, the paths must not start with `/boot` as they are from the root of the filesystem on that partition.

Also ensure that you use a filesystem for `/boot` that u-boot can actually read. FAT32 and ext\* are known to work, but others might work as well.