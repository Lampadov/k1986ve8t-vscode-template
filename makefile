# Toolchain
CC      = arm-none-eabi-gcc
CXX     = arm-none-eabi-g++
OBJCOPY = arm-none-eabi-objcopy
OBJDUMP = arm-none-eabi-objdump
SIZE    = arm-none-eabi-size
RM      = rm -rf
MKDIR   = mkdir -p
FIND    = find

# Project
PROJECT_NAME ?= K1986BE8T_Template
TARGET    = $(PROJECT_NAME)
BUILD_DIR = build
LD_SCRIPT = linker/K1986BE8T.ld

# MCU flags (Cortex-M4F, FPv4 single precision)
ARCH_FLAGS = -mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16

# Defines (под ваши заголовки SPL, обычно надо указать чип)
DEFS = -DUSE_K1986BE8T -D__FPU_PRESENT=1U

# Source files
PROGRAM_C_SRCS    = src/main.c
LIBRARY_C_SRCS    = $(shell $(FIND) Library -name "*.c" -type f)
LIBRARY_ASM_SRCS  = $(shell $(FIND) Library -name "*.S" -type f) $(shell $(FIND) Library -name "*.s" -type f)

C_SRCS   = $(PROGRAM_C_SRCS) $(LIBRARY_C_SRCS)
ASM_SRCS = $(LIBRARY_ASM_SRCS)

# Include paths
INC_DIRS = \
    Library \
    Library/inc \
    Library/src \
    src

INC_FLAGS = $(addprefix -I, $(INC_DIRS))

# Common flags
COMMON_FLAGS = $(ARCH_FLAGS) $(DEFS) $(INC_FLAGS) \
    -Og -g3 -fmessage-length=0 -fsigned-char \
    -ffunction-sections -fdata-sections -fno-move-loop-invariants \
    -Wa,-adhlns="$@.lst"

DEP_FLAGS = -MMD -MP -MF"$(BUILD_DIR)/$*.d" -MT"$@"

CFLAGS = $(COMMON_FLAGS) -std=gnu11 -Wall -Wextra $(DEP_FLAGS)

ASFLAGS = $(COMMON_FLAGS) -x assembler-with-cpp

LDFLAGS = $(ARCH_FLAGS) -T $(LD_SCRIPT) \
    -Xlinker --gc-sections \
    -Wl,-Map="$(BUILD_DIR)/$(TARGET).map" --specs=nano.specs --specs=nosys.specs

# Objects
C_OBJS   = $(addprefix $(BUILD_DIR)/, $(C_SRCS:.c=.o))
ASM_OBJS = $(patsubst %, $(BUILD_DIR)/%.o, $(basename $(ASM_SRCS)))
OBJS     = $(C_OBJS) $(ASM_OBJS)
OBJ_DIRS = $(sort $(dir $(OBJS)))

DEP_FILES = $(C_OBJS:.o=.d)

# Targets
all: $(BUILD_DIR)/$(TARGET).elf $(BUILD_DIR)/$(TARGET).hex $(BUILD_DIR)/$(TARGET).bin $(BUILD_DIR)/$(TARGET).lst
	@$(SIZE) --format=berkeley $(BUILD_DIR)/$(TARGET).elf

$(BUILD_DIR)/$(TARGET).elf: $(OBJS)
	@echo 'Linking: $@'
	@$(CC) $(OBJS) $(LDFLAGS) -o $@
	@echo 'Build complete'

$(BUILD_DIR)/$(TARGET).hex: $(BUILD_DIR)/$(TARGET).elf
	@$(OBJCOPY) -O ihex $< $@

$(BUILD_DIR)/$(TARGET).bin: $(BUILD_DIR)/$(TARGET).elf
	@$(OBJCOPY) -O binary $< $@

$(BUILD_DIR)/$(TARGET).lst: $(BUILD_DIR)/$(TARGET).elf
	@$(OBJDUMP) --source --all-headers --demangle --disassemble --line-numbers --wide $< > $@

$(OBJ_DIRS):
	@$(MKDIR) $@

$(BUILD_DIR)/%.o: %.c | $(OBJ_DIRS)
	@echo 'Compiling: $<'
	@$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: %.S | $(OBJ_DIRS)
	@echo 'Assembling: $<'
	@$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: %.s | $(OBJ_DIRS)
	@echo 'Assembling: $<'
	@$(CC) $(ASFLAGS) -c $< -o $@

-include $(DEP_FILES)

clean:
	@$(RM) $(BUILD_DIR)
	@echo 'Project cleaned'

.PHONY: all clean
