#!/bin/bash
#
# Compile script for FuAnDo haydn kernel
# Copyright (C) 2024 AGNi.
# Copyright (C) 2021-2024 @LeCmnGend.
#
# Download needed files
clear

KERNEL_DIR=`pwd`
export TC_BRANCH="clang-18"
export TC_DIR="$HOME/tc/clang/$TC_BRANCH"
#export TC_URL="https://gitlab.com/lecmngend/clang"
#export TC_GIT_BRANCH=$TC_BRANCH

export TC_URL="https://gitlab.com/kei-space/clang/r522817"
export TC_GIT_BRANCH=master

export AK3_URL="https://github.com/lecmngend/AnyKernel3"
export AK3_BRANCH="U-haydn"
export AK3_DIR="$HOME/tc/AK3/$AK3_BRANCH"

export PROC="-j11"
export TARGET_OUT=out
export ARCH=arm64
export SUBARCH=arm64
export CC="ccache clang"

# Setup environment
# Kernel Details
KERNEL_VER="$(date '+%Y%m%d-%H%M')"
DEFCONFIG="haydn_defconfig vendor/haydn_QGKI.config"
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
export PATH="$TC_DIR/bin:$PATH" 
export THINLTO_CACHE_DIR="/mnt/e/.ccache/ltocache/"
export KBUILD_COMPILER_STRING="$($TC_DIR/bin/clang --version | head -n 1 | perl -pe 's/\((?:http|git).*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//' -e 's/^.*clang/clang/')"
STRIP="$TC_DIR/bin/$(echo "$(find "$TC_DIR/bin" -type f -name "aarch64-*-gcc")" | awk -F '/' '{print $NF}' |\
			sed -e 's/gcc/strip/')"
BOT_TOKEN="6698627948:AAHlJ9jBioXyTFH726LwAIs5yx1moZr8vKw"
CHAT_ID="-1001393783342" #Fuando kernel group
#================================================================

# Check if toolchain is exist/ If not then download
if ! [ -d "$TC_DIR" ]; then
		echo "Proton clang not found! Cloning to $TC_DIR..."
		if ! git clone --single-branch --depth=1 -b $TC_GIT_BRANCH $TC_URL $TC_DIR; then
				echo "Cloning failed! Aborting..."
				exit 1
		fi
fi

# Check if AK3 exist	
if ! [ -d "$AK3_DIR" ]; then
				echo "$AK3_DIR not found! Cloning to $AK3_DIR..."
				if ! git clone -q --single-branch --depth 1 -b $AK3_BRANCH $AK3_URL $AK3_DIR; then
						echo "Cloning failed! Aborting..."
						exit 1
				fi
else
				echo "$AK3_DIR found! Update $AK3_DIR"
				cd $AK3_DIR
				git pull
				cd $KERNEL_DIR
fi

# Regened defconfig 
function make_defconfig {
    echo "------------------------------";
    echo " Building Kernel Defconfig..";
    echo "------------------------------";

	make $BUILD_PARA $DEFCONFIG

	if [[ $1 == "-r" || $1 == "--regen" ]]; then
			   cp out/.config arch/arm64/configs/$DEFCONFIG
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
		rm -rf $TARGET_OUT && make clean && make mrproper
		mkdir -p $TARGET_OUT
}

# Creating zip flashable file
function create_zip {
		#Copy AK3 to out/Anykernel13
		cp -r $AK3_DIR AnyKernel3
		cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
		cp out/arch/arm64/boot/dtbo.img AnyKernel3
		cp out/arch/arm64/boot/dtb.img AnyKernel3

		# Change dir to AK3 to make zip kernel
		cd AnyKernel3
		zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder

		#Back to out folder and clean
		cd ..
		rm -rf AnyKernel3
		# rm -rf out/arch/arm64/boot ##keep boot to compile rom
		echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
		echo "Zip: $ZIPNAME"
}

function create_prebuilt {
		#Copy Image.gz-dtb.gz and dtbo.img to prebuilt folder
		mkdir -p prebuilt
		cp out/arch/arm64/boot/Image.gz-dtb prebuilt
		cp out/arch/arm64/boot/dtbo.img prebuilt
		cp out/arch/arm64/boot/dtb.img prebuilt
		rm -rf out
		make clean
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
while read -p "Do you want to clean stuffs (y/n/h)? " cchoice
do
case "$cchoice" in
	y|Y )
		clean_all
		echo
		echo "All Cleaned now."
		make_defconfig
		link_all_dtb_files
		make_kernel
		break
		;;
	n|N )
		make_defconfig
		link_all_dtb_files
		make_kernel
		echo
		break
		;;	
	* )
		echo
		echo "Invalid try again!"
		echo
		;;
esac
done

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then
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

