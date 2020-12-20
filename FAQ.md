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
```

## I used the `extlinux.conf` example and the system doesn't boot
Make sure the paths in it are correct, if you use a separate `/boot` partition, the paths must not start with `/boot` as they are from the root of the filesystem on that partition.

Also ensure that you use a filesystem for `/boot` that u-boot can actually read. FAT32 and ext\* are known to work, but others might work as well.

## The battery discharges even though the charger is plugged in
This is normal, the Pinebook Pro's hardware can draw more power under heavy load than the bundled charger and the laptop's implementation of USB Power Delivery can actually provide.

The system might also stop charging completely with the LED next to the barrel connector starting to blink, this generally happens if temperatures get too high. Unplug the charger and wait a while, then it should work again.

## Wi-Fi doesn't work well/my 5GHz network is not detected at all
Install `crda` from the official repositories, then edit `/etc/conf.d/wireless-regdom` and uncomment the one for your country. The change will take effect after a reboot.

## System doesn't wake up from suspend
Suspend currently doesn't work with upstream TF-A, in the meantime you can edit `/etc/systemd/sleep.conf` and set `SuspendState` to `freeze`. This'll make it use s2idle instead which isn't "proper" suspend but will work as a temporary solution until suspend is fixed.
