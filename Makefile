ARCH := x86_64
SNAME = $(shell echo $(NAME) | cut -d'.' -f1)
DISTRO := noblemin
RAM := 8192
VCPUS := 4
ROOTSIZE := 16
MINIMAGE := https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-amd64.img
MAXIMAGE := https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
MINNAME  := $(shell basename "$(MINIMAGE)")
MAXNAME  := $(shell basename "$(MAXIMAGE)")

check_defined = \
  $(strip $(foreach 1,$1, \
      $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $2, ($2))))


## command to pass virt-install for swap disk allocation
SWAPDISK := --disk path=./swap.qcow2,device=disk,bus=virtio
SWAPSIZE := 4
GRAPHICS := none
DATASIZE := 16
DATADISK := --disk path=./data.qcow2,device=disk,bus=virtio
XTRASIZE := 8
XTRADISK := --disk path=./xtra.qcow2,device=disk,bus=virtio

.PHONEY: 

URL := $(shell egrep "^$(DISTRO);" ./distro | cut -d';' -f3)
SRC := $(shell egrep "^$(DISTRO)" ./distro | cut -d';' -f4)

maxdisks:
	rm -rf ./rootfs.qcow2
	qemu-img create -f qcow2 -F qcow2 -b ./noble-server-cloudimg-amd64.img ./rootfs.qcow2
	qemu-img resize ./rootfs.qcow2 $(ROOTSIZE)G

getmaximage: $(MAXNAME)
	echo "maxname: $(MAXNAME)"

$(MAXNAME):
	wget $(MAXIMAGE)

mindisks:
	rm -rf ./rootfs.qcow2
	qemu-img create -f qcow2 -F qcow2 -b ./ubuntu-24.04-minimal-cloudimg-amd64.img ./rootfs.qcow2
	qemu-img resize ./rootfs.qcow2 $(ROOTSIZE)G

getminimage: $(MINNAME)
	echo "minname: $(MINIMAGE)"

$(MINNAME):
	wget $(MINIMAGE)

rootfs.qcow2:
	make mindisks

datadisk:
	rm -rf ./data.qcow2
	qemu-img create -f qcow2 ./data.qcow2 $(DATASIZE)G

swapdisk:
	rm -rf ./swap.qcow2
	qemu-img create -f qcow2 ./swap.qcow2 $(SWAPSIZE)G

xtradisk:
	rm -rf ./xtra.qcow2
	qemu-img create -f qcow2 ./xtra.qcow2 $(XTRASIZE)G

getimagemin:
	wget
	
## create a node using virt-install
node:   
	@:$(call check_defined,NAME)
	#make maxdisks
	make mindisks
	make datadisk
	make swapdisk
	make xtradisk
	virt-install \
		--connect=qemu:///system \
		--arch $(ARCH) \
		--name $(SNAME) \
		--ram $(RAM) \
		--vcpus=$(VCPUS) \
		--disk path=./rootfs.qcow2,device=disk,bus=virtio \
		--os-variant=ubuntu22.04 \
		$(SWAPDISK) \
		$(DATADISK) \
		$(XTRADISK) \
		--graphics $(GRAPHICS) \
		--import \
		--cloud-init meta-data=./meta-data,user-data=./user-data,network-config=./network-config
	virsh start $(SNAME)

Delete:
	virsh destroy $(SNAME)
	virsh undefine $(SNAME)
	rm -rf ./rootfs.qcow2

