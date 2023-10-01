# specifies nasm assembler to be used
ASM=nasm

# source code directory
SRC_DIR=src

# build code directory
BUILD_DIR=build

# bootable floppy disk image file which is the main output of the makefile
# depends on binary file
# copes main.bin to floppy disk, creates floppy disk containing binary code
# resizes floppy disk image to 1440 kb (standard size of floppy disk), ensures bootable as floppy disk
$(BUILD_DIR)/main_floppy.img: $(BUILD_DIR)/main.bin
	cp $(BUILD_DIR)/main.bin $(BUILD_DIR)/main_floppy.img
	truncate -s 1440k $(BUILD_DIR)/main_floppy.img

# target assmembles assembly source code into binary executable
# needs assembly source code
# uses assembler to assembler main.asm into binary format
$(BUILD_DIR)/main.bin: $(SRC_DIR)/main.asm
	$(ASM) $(SRC_DIR)/main.asm -f bin -o $(BUILD_DIR)/main.bin
	