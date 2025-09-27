#!/bin/bash
#
# Compile script for QuicksilveR kernel + Auto Upload Telegram
# Copyright (C) 2020-2021 Adithya R.

SECONDS=0
KERNEL_DIR="$(pwd)"
GC_DIR="$HOME/toolchains/neutron-clang"
AK3_DIR="$HOME/AnyKernel3"
MKDTBO_FILE="$KERNEL_DIR/mkdtboimg.py"
DEFCONFIG="vendor/xiaomi-qgki_defconfig vendor/debugfs.config"
REDWOOD_DEF="vendor/redwood-fragment.config"

export PATH="${GC_DIR}/bin:/usr/bin:${PATH}"

# === TELEGRAM SETUP ===
BOT_TOKEN="8372952744:AAEFNxioJXEZGL1mRTfHqHC3W6nDJ5eFyuM"   # ganti token bot
CHANNEL_ID="@MargaSkutz"                          # bisa @username atau -100xxxxxxxxxx
# =======================

if ! [ -d "$AK3_DIR" ]; then
    echo "Anykernel 3 not found! Cloning to $AK3_DIR..."
    if ! git clone https://github.com/ibadriansyah/AnyKernel3 $AK3_DIR; then
        echo "Cloning failed! Aborting..."
        exit 1
    fi
fi

if ! [ -f "$MKDTBO_FILE" ]; then
    echo "Mkdtboimg not found! Wget to $MKDTBO_FILE..."
    if ! wget https://raw.githubusercontent.com/awakened1712/android_kernel_oneplus_sm8350/lineage-21/mkdtboimg.py -O $MKDTBO_FILE; then
        echo "Wget failed! Aborting..."
        exit 1
    fi
fi

export KBUILD_BUILD_USER=dabskutz
export KBUILD_BUILD_HOST=lab

if [[ $1 = "-c" || $1 = "--clean" ]]; then
    rm -rf out
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG $REDWOOD_DEF

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 LLVM=1 Image dtbs

if [ -f "out/arch/arm64/boot/Image" ]; then
    echo -e "\nKernel compiled succesfully! Zipping up...\n"
fi

cd $AK3_DIR
make clean
cp $KERNEL_DIR/out/arch/arm64/boot/Image $AK3_DIR
find $KERNEL_DIR/out/arch/arm64/boot/dts/vendor -name '*.dtb' -exec cat {} + > $AK3_DIR/dtb
python3 $KERNEL_DIR/mkdtboimg.py create $AK3_DIR/dtbo.img $KERNEL_DIR/out/arch/arm64/boot/dts/vendor/qcom/*.dtbo
make
cd $KERNEL_DIR
rm -rf out/arch/arm64/boot

# === CEK HASIL ZIP ===
ZIP_FILE=$(ls $HOME/AnyKernel3/*-signed.zip 2>/dev/null | head -n 1)

if [ -f "$ZIP_FILE" ]; then
    END_TIME=$SECONDS
    WAKTU_WIB=$(date +"%Y-%m-%d %H:%M:%S" -d "+7 hours")
    DURASI=$((END_TIME / 60)) menit $((END_TIME % 60)) detik

    echo -e "\n✅ Build selesai pada $WAKTU_WIB"
    echo "⏱️ Lama compile: $DURASI"
    echo "📦 File hasil: $ZIP_FILE"

    # === KIRIM KE TELEGRAM ===
    curl -s -F chat_id="$CHANNEL_ID" \
           -F document=@"$ZIP_FILE" \
           -F caption="✅ Kernel build selesai pada *$WAKTU_WIB*  
⏱️ Durasi: $DURASI" \
           -F parse_mode="Markdown" \
           "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" >/dev/null

    echo "📤 File berhasil dikirim ke Telegram!"
else
    echo "❌ Build gagal atau file zip tidak ditemukan!"
fi
