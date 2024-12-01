#
# Compile script for FuAnDo haydn kernel
# Copyright (C) 2024 AGNi.
# Copyright (C) 2021-2024 @LeCmnGend.
#
# Download needed files
apt-get update -y # Đảm bảo cập nhật danh sách các gói trước khi cài đặt
apt-get install -y \
  apt-utils unzip zip cmake curl make git-core git git-lfs gh wget tar zstd \
  build-essential flex bc binutils-dev bison ca-certificates file \
  texinfo u-boot-tools xz-utils patchelf \
  libelf-dev libssl-dev zlib1g-dev libncurses5 bzip2 libbz2-dev libghc-bzlib-dev \
  libsdl1.2-dev lsb-core ccache
clear

#Ccache
export USE_CCACHE=1
export CCACHE_COMPILER_CHECK="%compiler% -dumpversion"
export CCACHE_MAXFILES="0"
export CCACHE_NOHASHDIR="true"
export CCACHE_UMASK="0002"
export CCACHE_COMPRESSION="true"
export CCACHE_COMPRESSION_LEVEL="-3"
export CCACHE_NOINODECACHE="true"
export CCACHE_COMPILERTYPE="auto"
export CCACHE_RUN_SECOND_CPP="true"
export CCACHE_SLOPPINESS="file_macro,time_macros,include_file_mtime,include_file_ctime,file_stat_matches"
#================================================================
export KERNEL_DIR=$(pwd)
export SOT=$KERNEL_DIR
echo "Current KERNEL_DIR is: $KERNEL_DIR"
export TC_BRANCH="clang-19"
export TC_DIR="$SOT/tc/clang/$TC_BRANCH"
export TC_URL="https://gitlab.com/lecmngend/clang"
###
export AK3_URL="https://github.com/lecmngend/AnyKernel3"
export AK3_BRANCH="U-haydn"
export AK3_DIR="$SOT/tc/AK3/$AK3_BRANCH"
#================================================================
# Check if toolchain is exist/ If not then download
git clone --single-branch --depth=1 -b $TC_BRANCH $TC_URL $TC_DIR

# Check if AK3 exist	
git clone -q --single-branch --depth 1 -b $AK3_BRANCH $AK3_URL $AK3_DIR

curl -LSs "https://raw.githubusercontent.com/LeCmnGend/KernelSU/main/kernel/setup.sh" | bash -
#================================================================
export TZ=Asia/Bangkok
export PATH="$TC_DIR/bin:$PATH" 
BOT_TOKEN="6698627948:AAHlJ9jBioXyTFH726LwAIs5yx1moZr8vKw"
CHAT_ID="-1001393783342" #Fuando kernel group
#================================================================
echo "#================================================================"
echo "#================================================================"
echo "#================================================================"
echo "#================================================================"
export PROC="-j$(nproc --all)"
export TARGET_OUT=out
export ARCH=arm64
export SUBARCH=arm64
export CC="ccache clang"


# Setup environment
# Kernel Details
KERNEL_VER="$(date '+%Y%m%d-%H%M')"
DEFCONFIG="haydn_defconfig"
ZIPNAME="FuAnDo-haydn-A14-$(date '+%Y%m%d-%H%M').zip"
BUILD_PARA="$PROC O=$TARGET_OUT ARCH=arm64 \
            CLANG_PATH=$TC_DIR/bin \
            CROSS_COMPILE=aarch64-linux-gnu- \
            CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
            CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
            CLANG_TRIPLE=aarch64-linux-gnu- \
            LLVM_IAS=1 LLVM=1"
# Toolchain environtment
SECONDS=0 # builtin bash timer
export USE_CCACHE=1
export TZ=Asia/Bangkok
export THINLTO_CACHE_DIR="$SOT/tc/ltocache/"
export KBUILD_COMPILER_STRING="$($TC_DIR/bin/clang --version | head -n 1 | perl -pe 's/\((?:http|git).*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//' -e 's/^.*clang/clang/')"
STRIP="$TC_DIR/bin/$(echo "$(find "$TC_DIR/bin" -type f -name "aarch64-*-gcc")" | awk -F '/' '{print $NF}' |\
			sed -e 's/gcc/strip/')"
BOT_TOKEN="6698627948:AAHlJ9jBioXyTFH726LwAIs5yx1moZr8vKw"
CHAT_ID="-1001393783342" #Fuando kernel group
#================================================================
# Regened defconfig 
function make_defconfig {
    echo "------------------------------";
    echo " Building Kernel Defconfig..";
    echo "------------------------------";

	make $BUILD_PARA $DEFCONFIG

	if [[ $1 == "-r" || $1 == "--regen" ]]; then
			   cp $TARGET_OUT/.config arch/arm64/configs/$DEFCONFIG
			   echo -e "\nRegened defconfig succesfully!"
			   exit 0
	fi
}

function make_kernel {
		echo -e "\nStarting compilation...\n"
		make $BUILD_PARA Image.gz-dtb dtbo.img dtb.img
}

function link_all_dtb_files {
    find $TARGET_OUT/arch/arm64/boot/dts/vendor/qcom -name '*.dtb' -exec cat {} + > $TARGET_OUT/arch/arm64/boot/dtb;
}

function clean_all {
		cd $KERNEL_DIR
		echo
		rm -rf prebuilt
		rm -rf $TARGET_OUT 
		make clean
		mkdir -p $TARGET_OUT
}

# Creating zip flashable file
function create_zip {
		#Copy AK3 to $TARGET_OUT/Anykernel13
		cp -r $AK3_DIR AnyKernel3
		cp $TARGET_OUT/arch/arm64/boot/Image.gz-dtb AnyKernel3
		cp $TARGET_OUT/arch/arm64/boot/dtbo.img AnyKernel3

		# Change dir to AK3 to make zip kernel
		cd AnyKernel3
		zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder

		#Back to out folder and clean
		cd ..
		rm -rf AnyKernel3
		# rm -rf $TARGET_OUT/arch/arm64/boot ##keep boot to compile rom
		echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
		echo "Zip: $ZIPNAME"
}

# # Upload the ZIP file
function upload_zip {
    # Kiểm tra nếu tệp ZIP có tồn tại
    if [ ! -f "$ZIPNAME" ]; then
        echo "Tệp $ZIPNAME không tồn tại! Vui lòng kiểm tra lại."
        return 1
    fi
	echo -e "\nBot Token has been set successfully!"
	echo -e "\nUploading the ZIP file to Telegram..."
	curl --progress-bar -F chat_id=$CHAT_ID -F document=@"$ZIPNAME" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"
    # Kiểm tra kết quả của lệnh curl
    if [ $? -eq 0 ]; then
        echo -e "\nTải tệp lên Telegram thành công!"
    else
        echo -e "\nCó lỗi xảy ra khi tải tệp lên Telegram!"
        return 1
    fi
	echo -e "\nDone!"
}

###########################################################################
#MAIN
###########################################################################
		make_defconfig
		link_all_dtb_files
		make_kernel
###
if [ -f "$TARGET_OUT/arch/arm64/boot/Image.gz-dtb" ] && [ -f "$TARGET_OUT/arch/arm64/boot/dtbo.img" ]; then
		 echo -e "\nKernel compiled succesfully! Zipping up...\n"
		while read -p "Do you want to create Zip file (y/n/p)? " cchoice
		do
		case "$cchoice" in
			y|Y )
				create_zip
				echo -e "\nDone !"
				upload_zip
				break
				;;
			n|N )
				echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
				break
				;;
			p|P )
				create_prebuilt
				echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
				break
				;;			
			* )
				echo
				echo "Invalid try again!"
				echo
				;;
		esac
		done
else
		echo -e "\nFailed!"
fi

