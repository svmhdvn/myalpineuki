.POSIX:
.SUFFIXES:

version = XXX

host != hostname

common_pkgs = $(CURDIR)/common_packages.txt
host_pkgs = $(CURDIR)/hosts/$(host)/packages.txt

build = $(HOME)/.cache/myalpineuki/$(host)/build
rootfs = $(build)/rootfs
linux_src = $(build)/linux-stable

obj = $(build)/obj
bzImage = $(obj)/arch/x86/boot/bzImage
# NOTE: use vmlinuz-edge in case a newer custom kernel breaks
#bzImage = $(rootfs)/boot/vmlinuz-edge

out = $(HOME)/.cache/myalpineuki/$(host)/out
myinitramfs = $(out)/myinitramfs

efi_cur = /boot/efi/EFI/myalpine_cur
efi_prev = /boot/efi/EFI/myalpine_prev

cpu_vendor != grep vendor_id /proc/cpuinfo | head -1 | awk '$$3 == "GenuineIntel" { print "intel" }; $$3 == "AuthenticAMD" { print "amd" }'
KERNEL_MAKE = KBUILD_BUILD_TIMESTAMP='' $(MAKE) -f '$(linux_src)/Makefile' O='$(obj)' CC='ccache cc' KCFLAGS='-march=native'

all: build_kernel build_initramfs stage_kernel stage_initramfs
	ls -lh '$(out)'

# TODO automatically git commit and push to s/dotfiles/kernel_configs
build_kernel:
	if ! test -d '$(linux_src)'; then \
	  mkdir -p '$(build)'; \
	  git clone \
	    --depth=1 \
	    --branch='$(version)' \
	    'git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git' \
	    '$(linux_src)'; \
	  echo "MANDATORY: please install '$(obj)/.config' to continue!" >&2; \
	  exit 1; \
	fi
	if $(KERNEL_MAKE) -s kernelversion | xargs -I% test '$(version)' != 'v%'; then \
	  git -C '$(linux_src)' fetch --depth=1 origin tag '$(version)'; \
	  git -C '$(linux_src)' checkout '$(version)'; \
	  $(KERNEL_MAKE) oldconfig; \
	fi
	$(KERNEL_MAKE) -j"$$(nproc)"
	cp '$(obj)/.config' "$(HOME)/s/dotfiles/kernel_configs/$(host)_$(version).config"

build_initramfs:
	doas rm -rf '$(rootfs)'
	mkdir -p '$(build)'
	# Stop mkinitfs from running during apk install.
	doas mkdir -p '$(rootfs)/etc/mkinitfs'
	echo disable_trigger=yes | doas tee '$(rootfs)/etc/mkinitfs/mkinitfs.conf'
	# TODO write a useful date here
	date -u '+%Y-%m-%dT%H:%M:%SZ' | doas tee '$(rootfs)/etc/myalpine-release'
	doas alpine-make-rootfs \
	    --fs-skel-chown root:root \
	    --fs-skel-dir '$(CURDIR)/hosts/$(host)/root' \
	    --packages "$$(cat '$(common_pkgs)' '$(host_pkgs)' | grep -v -e '^[ \t]*#' -e '^[ \t]*$$')" \
	    --repositories-file /etc/apk/repositories \
	    --timezone 'Canada/Eastern' \
	    --script-chroot \
	    '$(rootfs)' '$(CURDIR)/common_setup.sh'

stage_kernel:
	mkdir -p '$(out)'
	cp '$(bzImage)' '$(out)/bootx64.efi'

stage_initramfs:
	rm -f '$(myinitramfs)'
	mkdir -p '$(out)'
	(cd '$(rootfs)' && doas find . -path ./boot -prune -o -print | doas cpio -o -H newc | zstd -o '$(myinitramfs)')
	cp '$(rootfs)'/boot/*-ucode.img '$(out)'

install:
	doas mkdir -p '$(efi_cur)' '$(efi_prev)'
	doas cp '$(efi_cur)'/* '$(efi_prev)'
	doas cp '$(out)'/* '$(efi_cur)'

rollback:
	doas mkdir -p '$(efi_cur)' '$(efi_prev)'
	doas cp '$(efi_prev)'/* '$(efi_cur)'

menuconfig:
	$(KERNEL_MAKE) menuconfig
