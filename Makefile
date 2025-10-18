SHELL := /bin/bash
BIN := $(PWD)/bin
FC_DIR := $(PWD)/_fc
ROOTFS_IMG := $(FC_DIR)/rootfs.ext4
KERNEL_URL := https://s3.amazonaws.com/spec.ccfc.min/img/hello/kernel/vmlinux.bin
ROOTFS_URL := https://s3.amazonaws.com/spec.ccfc.min/img/hello/fsfiles/hello-rootfs.ext4

.PHONY: deps fetch build run vm clean bake-rootfs

all: deps fetch build

deps:
	@mkdir -p $(BIN) $(FC_DIR)
	@which curl >/dev/null || (echo "Install curl" && exit 1)
	@which jq >/dev/null || (echo "Install jq" && exit 1)
	@which go >/dev/null || (echo "Install Go >= 1.21" && exit 1)

fetch: $(FC_DIR)/vmlinux.bin $(ROOTFS_IMG) $(BIN)/firecracker

$(FC_DIR)/vmlinux.bin:
	curl -L $(KERNEL_URL) -o $@

$(ROOTFS_IMG):
	curl -L $(ROOTFS_URL) -o $@

$(BIN)/firecracker:
	FC_VERSION=$$(curl -s https://api.github.com/repos/firecracker-microvm/firecracker/releases/latest | jq -r .tag_name); \
	curl -L -o $(BIN)/firecracker.tgz https://github.com/firecracker-microvm/firecracker/releases/download/$${FC_VERSION}/firecracker-$${FC_VERSION}-x86_64.tgz; \
	tar -xzf $(BIN)/firecracker.tgz -C $(BIN) firecracker-$${FC_VERSION}-x86_64; \
	ln -sf $(BIN)/firecracker-$${FC_VERSION}-x86_64 $(BIN)/firecracker; \
	rm -f $(BIN)/firecracker.tgz

build:
	cd app && go mod tidy && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o $(BIN)/demo-app ./main.go

run:
	./scripts/run_vm.sh

vm: run

# Bake a custom Alpine rootfs (app + litefs + init) into _fc/custom-rootfs.ext4
bake-rootfs:
	bash ./scripts/bake_rootfs.sh

clean:
	rm -rf $(BIN) $(FC_DIR) _data.img