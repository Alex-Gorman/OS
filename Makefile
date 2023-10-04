# specifies nasm assembler to be used
ASM=nasm

# source code directory
SRC_DIR=src
# build code directory
BUILD_DIR=build

.PHONY: all floppy_image kernel bootloader clean always

#
# Floppy image
#
floppy_image: $(BUILD_DIR)/main_floppy.img

# create 1.44 mb file with block size set to 512 and block count set to 2880
# mkfs.fat -F 12 -n "NBOS" $(BUILD_DIR)/main_floppy.img
$(BUILD_DIR)/main_floppy.img: bootloader kernel
	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880
	newfs_msdos -F 12 -f 2880 $(BUILD_DIR)/main_floppy.img
	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/main_floppy.img conv=nontrunc
	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/kernel.bin "::kernel.bin"

# cp $(BUILD_DIR)/main.bin $(BUILD_DIR)/main_floppy.img
# truncate -s 1440k $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main_floppy.img: bootloader kernel
	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880
	newfs_msdos -F 12 -f 2880 $(BUILD_DIR)/main_floppy.img


#
# Bootloader
#
bootloader: $(BUILD_DIR)/bootloader.bin

$(BUILD_DIR)/bootloader.bin: always
	$(ASM) $(SRC_DIR)/bootloader/boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin 


#
# Kernel
# 
kernel: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin: always
	$(ASM) $(SRC_DIR)/kernel/main.asm -f bin -o $(BUILD_DIR)/kernel.bin

always:
	mkdir -p $(BUILD_DIR)

clean: 
	rm -rf $(BUILD_DIR)/*