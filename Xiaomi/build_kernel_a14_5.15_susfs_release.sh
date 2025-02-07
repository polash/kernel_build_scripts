#!/bin/bash
set -e

# Check if 'builds' folder exists, create it if not
if [ ! -d "./builds" ]; then
    echo "'builds' folder not found. Creating it..."
    mkdir -p ./builds
else
    echo "'builds' folder already exists removing it."
    rm -rf ./builds
    mkdir -p ./builds
fi

# Create the root folder with the current date and time (AM/PM)
cd ./builds
ROOT_DIR="Xiaomi12-$(date +'%Y-%m-%d-%I-%M-%p')-release"
echo "Creating root folder $ROOT_DIR..."
mkdir -p "$ROOT_DIR"
cd "$ROOT_DIR"

# Clone the repositories into the root folder
echo "Cloning repositories..."
#git clone https://github.com/TheWildJames/android14-5.15.git
git clone https://github.com/TheWildJames/AnyKernel3.git -b android14-5.15
git clone https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android14-5.15

# Get the kernel
echo "Get the kernel..."
mkdir xiaomi-8550-kernel
cd ./xiaomi-8550-kernel
repo init -u https://github.com/xiaomi-sm8550-kernel/kernel_manifest.git -b master
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune

#rm -rf ./common/android/abi_gki_protected_exports_aarch64
#rm -rf ./common/android/abi_gki_protected_exports_x86_64

# Add KernelSU
cd ./kernel_platform
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -

#add susfs
echo "adding susfs"
cp ../../susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU/
cp ../../susfs4ksu/kernel_patches/50_add_susfs_in_gki-android14-5.15.patch ./common/
cp ../../susfs4ksu/kernel_patches/fs/susfs.c ./common/fs/
cp ../../susfs4ksu/kernel_patches/include/linux/susfs.h ./common/include/linux/
cp ../../susfs4ksu/kernel_patches/fs/sus_su.c ./common/fs/
cp ../../susfs4ksu/kernel_patches/include/linux/sus_su.h ./common/include/linux/
cd ./KernelSU/
patch -p1 < 10_enable_susfs_for_ksu.patch
cd ..
cd ./common
patch -p1 < 50_add_susfs_in_gki-android14-5.15.patch

#Adding ksu and susfs options
echo "Adding KSU and SUSFS options..."
cd ..
echo "CONFIG_KSU=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_SUS_OVERLAYFS=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_KSU_SUSFS_SUS_SU=y" >> ./common/arch/arm64/configs/gki_defconfig
sed -i '2s/check_defconfig//' ./common/build.config.gki
sed -i "s/dirty/'Wild+'/g" ./common/scripts/setlocalversion
cd ..

echo "Press Enter to continue..."
read  # Waits for the user to press Enter

# Building kernel
echo "Building Kernel..."
./build.sh kalama fuxi

exit

# Copy Image.lz4
echo "Copying Image.lz4"
cp ./bazel-bin/common/kernel_aarch64/Image.lz4 ../AnyKernel3/Image.lz4

# Navigate to the AnyKernel3 directory
echo "Navigating to AnyKernel3 directory..."
cd ../AnyKernel3

# Zip the files in the AnyKernel3 directory with a new naming convention
ZIP_NAME="Xiaomi-13-KernelSU-SUSFS-$(date +'%Y-%m-%d-%H-%M-%S').zip"
echo "Creating zip file $ZIP_NAME..."
zip -r "../$ZIP_NAME" ./*

# Move back to the root directory (assuming you are already in the correct directory)
cd ..

# GitHub Release using gh CLI
REPO_OWNER="TheWildJames"         # Replace with your GitHub username
REPO_NAME="android_gki_kernel_5.15_common "  # Replace with your repository name
TAG_NAME="v$(date +'%Y.%m.%d-%H%M%S')"   # Unique tag with timestamp to ensure multiple releases on the same day
RELEASE_NAME="v24.12.03 GKI-android14-5.15 With KernelSU & SUSFS"  # Updated release name

# Create the release using gh CLI (no need to include $ROOT_DIR)
echo "Creating GitHub release for $RELEASE_NAME..."
gh release create "$TAG_NAME" "$ZIP_NAME" \
  --repo "$REPO_OWNER/$REPO_NAME" \
  --title "$RELEASE_NAME" \
  --notes "Kernel release"

# Final confirmation
echo "GitHub release created and zip file uploaded."
echo "Build and packaging process complete."
