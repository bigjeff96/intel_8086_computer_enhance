package intel_8086

import "core:fmt"
import "core:bytes"
import "core:os"
import "core:log"
import "core:strings"
import "core:math/bits"

Op_codes :: enum u8 {
    mov = 0b100010,
}

Mod_encodings :: enum u8 {
    MEMORY_MODE            = 0x0,
    REGISTER_MODE          = 0x3,
    MEMORY_MODE_8BIT_DISP  = 0x1,
    MEMORY_MODE_16BIT_DISP = 0x2,
}

Registers_wide :: enum u8 {
    ax = 0x0,
    cx = 0x1,
    dx = 0x2,
    bx = 0x3,
    sp = 0x4,
    bp = 0x5,
    si = 0x6,
    di = 0x7,
}

Registers_non_wide :: enum u8 {
    al = 0x0,
    cl = 0x1,
    dl = 0x2,
    bl = 0x3,
    ah = 0x4,
    ch = 0x5,
    dh = 0x6,
    bh = 0x7,
}

Register :: union {
    Registers_wide,
    Registers_non_wide,
}

Intruction :: struct {
    op_code: Op_codes, // 6 bits
    d:       bool, // 1 bit , d as destination
    w:       bool, // 1 bit, w as wide
    mod:     Mod_encodings, // 2 bits
    reg:     u8, // 3 bits
    r_m:     u8, // 3 bits
}

main :: proc() {
    logger := log.create_console_logger()
    defer log.destroy_console_logger(logger)
    context.logger = logger
    data, ok := os.read_entire_file_from_filename("data/listing_0038_many_register_mov")
    if !ok {
        log.error("Can't read file")
        os.exit(1)
    }
    instructions: [dynamic]Intruction

    for i := 0; i < len(data); i += 2 {
        append(&instructions, get_instruction_from_bytes(data[i:i + 2]))
    }

    fd, err := os.open("test.asm", os.O_RDWR | os.O_CREATE)
    assert(err == os.ERROR_NONE)
    defer os.close(fd)
    fmt.fprintf(fd, "bits 16\n\n")

    for instruction in instructions do write_asm_instruction_to_file(fd, instruction)
}

get_instruction_from_bytes :: proc(data: []byte) -> Intruction {
    assert(len(data) == 2)
    using bits
    result_intruction: Intruction

    // Op_code
    op_code_u8 := bitfield_extract(data[0], 2, 6)
    if cast(Op_codes)op_code_u8 == .mov do result_intruction.op_code = .mov

    // D and W
    dw_u8 := bitfield_extract(data[0], 0, 2)
    if dw_u8 & 0b1 == 0b1 do result_intruction.w = true
    if (dw_u8 >> 1) & 0b1 == 0b1 do result_intruction.d = true

    // mod
    mod_u8 := bitfield_extract(data[1], 6, 2)
    result_intruction.mod = cast(Mod_encodings)mod_u8
    // reg
    reg_u8 := bitfield_extract(data[1], 3, 3)
    result_intruction.reg = reg_u8
    // r_m
    r_m := bitfield_extract(data[1], 0, 3)
    result_intruction.r_m = r_m

    return result_intruction
}

write_asm_instruction_to_file :: proc(fd: os.Handle, instruction: Intruction) {
    assert(instruction.op_code == .mov)
    assert(instruction.mod == .REGISTER_MODE)

    // Determine the registers
    destination_reg: Register
    source_reg: Register

    reg_r_m: Register
    reg_reg: Register

    if instruction.w {
        reg_r_m = cast(Registers_wide)instruction.r_m
        reg_reg = cast(Registers_wide)instruction.reg
    } else {
        reg_r_m = cast(Registers_non_wide)instruction.r_m
        reg_reg = cast(Registers_non_wide)instruction.reg
    }

    if instruction.d == true {
        // destination is in reg, source is in r_m
        destination_reg = reg_reg
        source_reg = reg_r_m
    } else {
        // destination is in r_m, source is in reg
        destination_reg = reg_r_m
        source_reg = reg_reg
    }

    fmt.fprintf(fd, "%v %v, %v\n", instruction.op_code, destination_reg, source_reg)
}
