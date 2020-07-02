#!/bin/bash

set -e -u

iso_name=archlinux
iso_label="ARCH_$(date +%Y%m)"
iso_publisher="Arch Linux ARM <http://www.archlinuxarm.org>"
iso_application="Arch Linux ARM Install Image"
iso_version=$(date +%Y.%m.%d)
install_dir=arch
work_dir=work
out_dir=out
gpg_key=

verbose=""
script_path=$(readlink -f ${0%/*})

pacmanconfname=pacman.conf

umask 0022

_usage ()
{
    echo "usage ${0} [options]"
    echo
    echo " General options:"
    echo "    -N <iso_name>      Set an iso filename (prefix)"
    echo "                        Default: ${iso_name}"
    echo "    -V <iso_version>   Set an iso version (in filename)"
    echo "                        Default: ${iso_version}"
    echo "    -L <iso_label>     Set an iso label (disk label)"
    echo "                        Default: ${iso_label}"
    echo "    -P <publisher>     Set a publisher for the disk"
    echo "                        Default: '${iso_publisher}'"
    echo "    -A <application>   Set an application name for the disk"
    echo "                        Default: '${iso_application}'"
    echo "    -D <install_dir>   Set an install_dir (directory inside iso)"
    echo "                        Default: ${install_dir}"
    echo "    -w <work_dir>      Set the working directory"
    echo "                        Default: ${work_dir}"
    echo "    -o <out_dir>       Set the output directory"
    echo "                        Default: ${out_dir}"
    echo "    -v                 Enable verbose output"
    echo "    -h                 This help message"
    exit ${1}
}

# Helper function to run make_*() only one time per architecture.
run_once() {
    if [[ ! -e ${work_dir}/build.${1} ]]; then
        $1
        touch ${work_dir}/build.${1}
    fi
}

# Setup custom pacman.conf with current cache directories.
make_pacman_conf() {
    local _cache_dirs
	arch=$(uname -m)
	if [[ arch == "aarch64" ]]; then
		pacmanconfname=pacman.conf
	else
		pacmanconfname=pacman-cross.conf
	fi

    _cache_dirs=($(pacman -v 2>&1 | grep '^Cache Dirs:' | sed 's/Cache Dirs:\s*//g'))
    sed -r "s|^#?\\s*CacheDir.+|CacheDir = $(echo -n ${_cache_dirs[@]})|g" ${script_path}/$pacmanconfname > ${work_dir}/pacman.conf
}


# Base installation, plus needed packages (airootfs)
make_basefs() {
#    mkarchiso ${verbose} -w "${work_dir}/aarch64" -C "${work_dir}/pacman.conf" -D "${install_dir}" init
	
    mkdir -p ${work_dir}/aarch64/airootfs
	pacstrap -C "${work_dir}/pacman.conf" -c -G -M "${work_dir}/aarch64/airootfs" base

    mkarchiso ${verbose} -w "${work_dir}/aarch64" -C "${work_dir}/pacman.conf" -D "${install_dir}" -p "haveged mkinitcpio-nfs-utils nbd zsh efitools" install
}

# Additional packages (airootfs)
make_packages() {
    mkarchiso ${verbose} -w "${work_dir}/aarch64" -C "${work_dir}/pacman.conf" -D "${install_dir}" -p "$(grep -h -v ^# ${script_path}/packages.aarch64 | tr "\n" " ")" install
}

# Copy mkinitcpio archiso hooks and build initramfs (airootfs)
make_setup_mkinitcpio() {
    local _hook
    mkdir -p ${work_dir}/aarch64/airootfs/etc/initcpio/hooks
    mkdir -p ${work_dir}/aarch64/airootfs/etc/initcpio/install
    for _hook in archiso archiso_shutdown archiso_pxe_common archiso_pxe_nbd archiso_pxe_http archiso_pxe_nfs archiso_loop_mnt; do
        cp /usr/lib/initcpio/hooks/${_hook} ${work_dir}/aarch64/airootfs/etc/initcpio/hooks
        cp /usr/lib/initcpio/install/${_hook} ${work_dir}/aarch64/airootfs/etc/initcpio/install
    done
    sed -i "s|/usr/lib/initcpio/|/etc/initcpio/|g" ${work_dir}/aarch64/airootfs/etc/initcpio/install/archiso_shutdown
    cp /usr/lib/initcpio/install/archiso_kms ${work_dir}/aarch64/airootfs/etc/initcpio/install
    cp /usr/lib/initcpio/archiso_shutdown ${work_dir}/aarch64/airootfs/etc/initcpio
    cp ${script_path}/mkinitcpio.conf ${work_dir}/aarch64/airootfs/etc/mkinitcpio-archiso.conf
    gnupg_fd=
    if [[ ${gpg_key} ]]; then
      gpg --export ${gpg_key} >${work_dir}/gpgkey
      exec 17<>${work_dir}/gpgkey
    fi
	kver=$(basename $(find ${work_dir}/aarch64/airootfs/lib/modules -name "[0-9].*"))
    ARCHISO_GNUPG_FD=${gpg_key:+17} mkarchiso ${verbose} -w "${work_dir}/aarch64" -C "${work_dir}/pacman.conf" -D "${install_dir}" -r "mkinitcpio -c /etc/mkinitcpio-archiso.conf -k ${kver} -g /boot/archiso.img || true" run
    if [[ ${gpg_key} ]]; then
      exec 17<&-
    fi
}

# Customize installation (airootfs)
make_customize_airootfs() {
    cp -af ${script_path}/airootfs ${work_dir}/aarch64

    cp ${script_path}/pacman.conf ${work_dir}/aarch64/airootfs/etc

    lynx -dump -nolist 'https://wiki.archlinux.org/index.php/Installation_Guide?action=render' >> ${work_dir}/aarch64/airootfs/root/install.txt

    mkarchiso ${verbose} -w "${work_dir}/aarch64" -C "${work_dir}/pacman.conf" -D "${install_dir}" -r '/root/customize_airootfs.sh' run
    rm ${work_dir}/aarch64/airootfs/root/customize_airootfs.sh
}

# Prepare kernel/initramfs ${install_dir}/boot/
make_boot() {
    mkdir -p ${work_dir}/iso/${install_dir}/boot/aarch64
    cp ${work_dir}/aarch64/airootfs/boot/archiso.img ${work_dir}/iso/${install_dir}/boot/aarch64/archiso.img
    cp ${work_dir}/aarch64/airootfs/boot/Image ${work_dir}/iso/${install_dir}/boot/aarch64/Image

	cp "${work_dir}/aarch64/airootfs/boot/dtbs/rockchip/rk3399-pinebook-pro.dtb" "${work_dir}/iso/"

	mkdir -p "${work_dir}/iso/extlinux"
	cat - > "${work_dir}/iso/extlinux/extlinux.conf" <<EOF
LABEL Arch Linux ARM
KERNEL /arch/boot/aarch64/Image
FDT /rk3399-pinebook-pro.dtb
APPEND initrd=/arch/boot/aarch64/archiso.img console=tty1 archisobasedir=$install_dir archisolabel=${iso_label} video=eDP-1:1920x1080@60
EOF
}


# Build airootfs filesystem image
make_prepare() {
    cp -a -l -f ${work_dir}/aarch64/airootfs ${work_dir}
    mkarchiso ${verbose} -w "${work_dir}" -D "${install_dir}" pkglist
    mkarchiso ${verbose} -w "${work_dir}" -D "${install_dir}" ${gpg_key:+-g ${gpg_key}} prepare
    rm -rf ${work_dir}/airootfs
	mv "${work_dir}/iso/${install_dir}/$(uname -m)" "${work_dir}/iso/${install_dir}/aarch64" &> /dev/null || true
    # rm -rf ${work_dir}/aarch64/airootfs (if low space, this helps)
}

# Build image
make_image() {
	mkdir -p "${out_dir}"
	image="${out_dir}/${iso_name}-${iso_version}-pbp.img"
	truncate -s $(($(du -sm "${work_dir}/iso" | cut -d"	" -f1)+20))M $image
	parted -s $image -- mktable msdos
	parted -s $image -- mkpart primary fat32 10M -0
	parted -s $image -- set 1 boot on

	mkdir -p "${work_dir}/mnt"
	part=$(kpartx $image | cut -d" " -f1)
	kpartx -a $image
	mkfs.vfat -n "${iso_label}" /dev/mapper/$part

	mount /dev/mapper/$part "${work_dir}/mnt"
	cp -r "${work_dir}"/iso/* "${work_dir}/mnt/"
	umount "${work_dir}/mnt"

	kpartx -d $image

	dd if="${work_dir}/aarch64/airootfs/boot/idbloader.img" of=$image seek=64 conv=notrunc
	dd if="${work_dir}/aarch64/airootfs/boot/u-boot.itb" of=$image seek=16384 conv=notrunc

}

if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root."
    _usage 1
fi

while getopts 'N:V:L:P:A:D:w:o:g:vh' arg; do
    case "${arg}" in
        N) iso_name="${OPTARG}" ;;
        V) iso_version="${OPTARG}" ;;
        L) iso_label="${OPTARG}" ;;
        P) iso_publisher="${OPTARG}" ;;
        A) iso_application="${OPTARG}" ;;
        D) install_dir="${OPTARG}" ;;
        w) work_dir="${OPTARG}" ;;
        o) out_dir="${OPTARG}" ;;
        g) gpg_key="${OPTARG}" ;;
        v) verbose="-v" ;;
        h) _usage 0 ;;
        *)
           echo "Invalid argument '${arg}'"
           _usage 1
           ;;
    esac
done

mkdir -p ${work_dir}

run_once make_pacman_conf
run_once make_basefs
run_once make_packages
run_once make_setup_mkinitcpio
run_once make_customize_airootfs
run_once make_boot
run_once make_prepare
run_once make_image
