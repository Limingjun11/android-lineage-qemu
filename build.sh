#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# 强行把 Azure 镜像源替换为 Ubuntu 官方源
sudo sed -i 's/azure.archive.ubuntu.com/archive.ubuntu.com/g' /etc/apt/sources.list

sudo apt update
sudo apt install -y sudo git android-sdk-platform-tools python-is-python3 python3-yaml qemu-utils # libncurses5
sudo apt install -y bc bison build-essential ccache curl flex g++-multilib gcc-multilib git git-lfs gnupg gperf imagemagick protobuf-compiler python3-protobuf lib32readline-dev lib32z1-dev libdw-dev libelf-dev lz4 libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev
sudo apt install -y meson-1.5 glslang-tools python3-mako
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"
git config --global trailer.changeid.key "Change-Id"
git config --global color.ui true
git lfs install

unset REPO_URL
mkdir -p bin android/lineage
curl https://storage.googleapis.com/git-repo-downloads/repo > bin/repo
chmod a+x bin/repo
export PATH="$(realpath .)/bin:$PATH"
cd android/lineage
export PATH="$(realpath .)/prebuilts/sdk/tools/linux/bin/:$PATH"
repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --git-lfs --no-clone-bundle --depth 1
repo sync -c --prune --force-sync --fail-fast --retry-fetches=8 -j 8
sed -i 's/-$(LINEAGE_BUILDTYPE)/-jqssun/g' vendor/lineage/config/version.mk

source build/envsetup.sh
export AB_OTA_UPDATER=false ROOMSERVICE_BRANCHES="lineage-24.0 lineage-23.2"

# ===== 删除了 x86_64 的编译部分，直接只编译 ARM64 =====

breakfast virtio_arm64only userdebug
m recoveryimage
mv out/target/product/virtio_arm64only/recovery.img ../../recovery_arm64only-userdebug.img

breakfast virtio_arm64only user
m vm-utm-zip otapackage
mv out/target/product/virtio_arm64only/boot.img ../../boot_arm64only.img
mv out/target/product/virtio_arm64only/recovery.img ../../recovery_arm64only.img

# ===== 新增：在云端自动解压并转换为 qcow2 =====
echo "开始转换 UTM 镜像以节省空间..."
UTM_ZIP=$(find out/target/product/virtio_arm64only/VirtualMachine/UTM/ -name "*.zip" | head -n 1)
mkdir -p /tmp/utm_extract
unzip -q "$UTM_ZIP" -d /tmp/utm_extract

find /tmp/utm_extract -name "vda.img" -exec qemu-img convert -f raw -O qcow2 -c {} ../../vda_arm64only.qcow2 \;
find /tmp/utm_extract -name "vdb.img" -exec qemu-img convert -f raw -O qcow2 -c {} ../../vdb_arm64only.qcow2 \;
echo "转换完成！"
