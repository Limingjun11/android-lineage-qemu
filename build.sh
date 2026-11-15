#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# ===== 暴力清理云端机器空间（保命用） =====
echo "开始清理系统空间..."
sudo rm -rf /usr/share/dotnet
sudo rm -rf /opt/ghc
sudo rm -rf "/usr/local/share/boost"
sudo rm -rf "$AGENT_TOOLSDIRECTORY"
sudo apt-get clean
sudo rm -rf /usr/local/lib/android
echo "清理完成，当前磁盘空间："
df -h /
# ==========================================

# 强行把 Azure 源替换为 Ubuntu 官方源（防丢包）
sudo rm -f /etc/apt/sources.list.d/* /etc/apt/sources.list
sudo bash -c 'cat << EOF > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse
EOF'

sudo apt update
sudo apt install -y sudo git android-sdk-platform-tools python-is-python3 python3-yaml qemu-utils
sudo apt install -y bc bison build-essential ccache curl flex g++-multilib gcc-multilib git git-lfs gnupg gperf imagemagick protobuf-compiler python3-protobuf lib32readline-dev lib32z1-dev libdw-dev libelf-dev lz4 libsdl1.2-dev libssl-dev libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev
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

# ... 前面的 repo init 保持不变 ...
repo init -u https://github.com/LineageOS/android.git -b lineage-20.0 --git-lfs --no-clone-bundle --depth 1

# ===== 强行加入 virtio_arm64only 仓库 =====
mkdir -p .repo/local_manifests
cat << EOF > .repo/local_manifests/virtio.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="LineageOS/android_device_virt_virtio_arm64only" path="device/virt/virtio_arm64only" remote="github" revision="lineage-20" />
</manifest>
EOF

# 然后再 sync
repo sync -c --no-tags --prune --force-sync --fail-fast --retry-fetches=8 -j 32

sed -i 's/-$(LINEAGE_BUILDTYPE)/-jqssun/g' vendor/lineage/config/version.mk

source build/envsetup.sh
export AB_OTA_UPDATER=false ROOMSERVICE_BRANCHES="lineage-20.0 lineage-19.1"

# 编译 ARM64 (LineageOS 20 的设备代号通常还是 virtio_arm64only)
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
