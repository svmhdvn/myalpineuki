.POSIX:
.SUFFIXES:

host != hostname

common_pkgs = $(CURDIR)/common_packages.txt
host_pkgs = $(CURDIR)/hosts/$(host)/packages.txt

build = $(HOME)/.cache/myalpineuki/$(host)/build
rootfs = $(build)/rootfs
linux_src = $(build)/linux-stable

bzImage = $(linux_src)/arch/x86/boot/bzImage
# NOTE: use vmlinuz-edge in case a newer custom kernel breaks
#bzImage = $(rootfs)/boot/vmlinuz-edge

out = $(HOME)/.cache/myalpineuki/$(host)/out
myinitramfs = $(out)/myinitramfs

efi_cur = /boot/efi/EFI/myalpine_cur/
efi_prev = /boot/efi/EFI/myalpine_prev/

cpu_vendor != grep vendor_id /proc/cpuinfo | head -1 | awk '$$3 == "GenuineIntel" { print "intel" }; $$3 == "AuthenticAMD" { print "amd" }'
KERNEL_MAKE = $(MAKE) -C '$(linux_src)' CC='ccache cc' KBUILD_BUILD_TIMESTAMP=''

all: prep kernel initramfs
	ls -lh '$(out)'

prep:
	mkdir -p '$(build)' '$(out)'
	doas mkdir -p '$(efi_cur)' '$(efi_prev)'
	if ! test -d '$(linux_src)'; then \
	  git clone \
	    --depth=1 \
	    --branch=linux-rolling-stable \
	    'git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git' \
	    '$(linux_src)'; \
	  @echo "MANDATORY: please install '$(linux_src)/.config' to continue!" >&2; \
	  exit 1; \
	fi


# TODO automatically git commit and push to s/dotfiles/kernel_configs
kernel:
	git -C '$(linux_src)' pull --depth=1
	$(KERNEL_MAKE) oldconfig
	$(KERNEL_MAKE) -j"$$(nproc)"
	$(KERNEL_MAKE) -s kernelversion | xargs -I% cp '$(linux_src)/.config' "$(HOME)/s/dotfiles/kernel_configs/$(host)_%.config"
	cp '$(bzImage)' '$(out)/bootx64.efi'

initramfs: clean
	# Stop mkinitfs from running during apk install.
	doas mkdir -p '$(rootfs)/etc/mkinitfs'
	echo disable_trigger=yes | doas tee '$(rootfs)/etc/mkinitfs/mkinitfs.conf'
	# TODO write a useful date here
	date -u '+%Y-%m-%dT%H:%M:%SZ' | doas tee '$(rootfs)/etc/myalpineuki-release'
	doas alpine-make-rootfs \
	    --fs-skel-chown root:root \
	    --fs-skel-dir '$(CURDIR)/hosts/$(host)/root' \
	    --packages "$$(cat '$(common_pkgs)' '$(host_pkgs)' | grep -v -e '^[ \t]*#' -e '^[ \t]*$$')" \
	    --repositories-file /etc/apk/repositories \
	    --timezone 'Canada/Eastern' \
	    --script-chroot \
	    '$(rootfs)' '$(CURDIR)/common_setup.sh'
	(cd '$(rootfs)' && doas find . -path ./boot -prune -o -print | doas cpio -o -H newc | zstd -o '$(myinitramfs)')
	cp '$(rootfs)/boot/$(cpu_vendor)-ucode.img' '$(out)'

install:
	doas cp '$(efi_cur)'/* '$(efi_prev)'
	doas cp '$(out)'/* '$(efi_cur)'

rollback:
	doas cp '$(efi_prev)'/* '$(efi_cur)'

menuconfig:
	$(KERNEL_MAKE) menuconfig

# TODO remove this eventually, there's no real need for UKIs (yet)
uki:
	# The default rdinit is /init, while the default init is /sbin/init.
	efi-mkuki -c rdinit=/sbin/init -o '$(out)/bootx64.efi' \
	    '$(bzImage)' \
	    '$(rootfs)/boot/$(cpu_vendor)-ucode.img' \
	    '$(myinitramfs)'
	#efi-mkuki -c rdinit=/sbin/init -o '$(out)/bootx64.efi' '$(bzImage)' '$(myinitramfs)'

clean:
	doas rm -rf '$(rootfs)' '$(myinitramfs)'
