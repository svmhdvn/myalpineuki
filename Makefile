.POSIX:
.SUFFIXES:

host != hostname

# NOTE: use vmlinuz-edge in case a newer custom kernel breaks
#bzImage = $(rootfs_dest)/boot/vmlinuz-edge

rootfs_src = $(CURDIR)/hosts/$(host)/root
common_pkgs = $(CURDIR)/common_packages.txt
host_pkgs = $(CURDIR)/hosts/$(host)/packages.txt

workspace = $(HOME)/.cache/myalpineuki/$(host)
rootfs_dest = $(workspace)/rootfs
initramfs_dest = $(workspace)/myinitramfs
linux_src = $(workspace)/linux-stable
bzImage = $(linux_src)/arch/x86/boot/bzImage

latest_kernel != curl -s 'https://kernel.org' | grep -A1 latest_link | grep -o '>.*<' | tr -d '><'
cpu_vendor != grep vendor_id /proc/cpuinfo | head -1 | awk '$$3 == "GenuineIntel" { print "intel" }; $$3 == "AuthenticAMD" { print "amd" }'

all: clean kernel rootfs initramfs uki
	ls -lh '$(workspace)'

# TODO automatically git commit and push to s/dotfiles/kernel_configs
kernel:
	if ! test -d '$(linux_src)'; then \
	  git clone --depth=1 --branch='v$(latest_kernel)' git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git '$(linux_src)'; \
	elif git -C '$(linux_src)' tag | xargs test 'v$(latest_kernel)' !=; then \
	  git -C '$(linux_src)' fetch --depth 1 origin tag 'v$(latest_kernel)'; \
	  git -C '$(linux_src)' checkout                   'v$(latest_kernel)'; \
    	fi
	$(MAKE) -C '$(linux_src)'               CC='ccache cc' KBUILD_BUILD_TIMESTAMP='' oldconfig
	$(MAKE) -C '$(linux_src)' -j"$$(nproc)" CC='ccache cc' KBUILD_BUILD_TIMESTAMP=''
	cp '$(linux_src)/.config' "$(HOME)/s/dotfiles/kernel_configs/$(host)_$(latest_kernel).config"

rootfs:
	# Stop mkinitfs from running during apk install.
	doas mkdir -p '$(rootfs_dest)/etc/mkinitfs'
	echo disable_trigger=yes | doas tee '$(rootfs_dest)/etc/mkinitfs/mkinitfs.conf'
	# TODO write a useful date here
	date -u '+%Y-%m-%dT%H:%M:%SZ' | doas tee '$(rootfs_dest)/etc/myalpineuki-release'
	doas alpine-make-rootfs \
	    --fs-skel-chown root:root \
	    --fs-skel-dir '$(rootfs_src)' \
	    --packages "$$(cat '$(common_pkgs)' '$(host_pkgs)' | grep -v -e '^[ \t]*#' -e '^[ \t]*$$')" \
	    --repositories-file /etc/apk/repositories \
	    --timezone 'Canada/Eastern' \
	    --script-chroot \
	    '$(rootfs_dest)' setup.sh

initramfs:
	(cd '$(rootfs_dest)' && doas find . -path ./boot -prune -o -print | doas cpio -o -H newc | zstd -o '$(initramfs_dest)')

uki:
	# The default rdinit is /init, while the default init is /sbin/init.
	efi-mkuki -c rdinit=/sbin/init -o '$(workspace)/bootx64.efi' \
	    '$(bzImage)' \
	    '$(rootfs_dest)/boot/$(cpu_vendor)-ucode.img' \
	    '$(initramfs_dest)'

install:
	doas cp /boot/efi/EFI/myalpineuki-cur/bootx64.efi /boot/efi/EFI/myalpineuki-prev/bootx64.efi
	doas cp '$(workspace)/bootx64.efi' /boot/efi/EFI/myalpineuki-cur/bootx64.efi

rollback:
	doas cp /boot/efi/EFI/myalpineuki-prev/bootx64.efi /boot/efi/EFI/myalpineuki-cur/bootx64.efi

clean:
	doas rm -rf '$(rootfs_dest)' '$(initramfs_dest)'
