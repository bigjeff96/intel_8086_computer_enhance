package intel_8086

import "core:fmt"
import "core:bytes"
import "core:os"
import "core:log"
import "core:strings"
import "core:math/bits"

Op_codes :: enum u8 {
    mov,
}

Mov_codes :: enum u8 {
    MOV_IMMEDIATE_TO_REG    = 0b1011,
    MOV_REG_OR_MEM_FROM_REG = 0b100010,
}

Mod_encodings :: enum u8 {
    MEMORY_MODE            = 0x0,
    REGISTER_MODE          = 0x3,
    MEMORY_MODE_8BIT_DISP  = 0x1,
    MEMORY_MODE_16BIT_DISP = 0x2,
}

Effective_address_strings := [?]string{"bx + si", "bx + di", "bp + si", "bp + di", "si", "di", "bp", "bx"}

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
    op:      Op_codes, // 6 bits to 4 bits
    op_code: u8,
    d:       bool, // 1 bit , d as destination
    w:       bool, // 1 bit, w as wide
    mod:     Mod_encodings, // 2 bits
    reg:     u8, // 3 bits
    r_m:     u8, // 3 bits
    data:    u16, // can be 8 or 16 bits
}

main :: proc() {
    logger := log.create_console_logger()
    defer log.destroy_console_logger(logger)
    context.logger = logger
    data, ok := os.read_entire_file_from_filename(
        "/home/joseph/Dropbox/Projects/Performance_aware/homeworks/homework_1/data/listing_0039_more_movs",
    )
    if !ok {
        log.error("Can't read file")
        os.exit(1)
    }
    defer delete(data)
    
    instructions: [dynamic]Intruction
    defer delete(instructions)
    bytes_used := 0
    for i := 0; i < len(data); i += bytes_used {
        shift := 5 if i + 5 <= len(data) else len(data) - i
        instruction, bytes_used_by_inst := get_instruction_from_bytes(data[i:i + shift])
        bytes_used = bytes_used_by_inst
        append(&instructions, instruction)
    }

    fd, err := os.open("test.asm", os.O_RDWR | os.O_CREATE | os.O_TRUNC)
    assert(err == os.ERROR_NONE)
    defer os.close(fd)
    fmt.fprintf(fd, "bits 16\n\n")

    for instruction in instructions do write_asm_instruction_to_file(fd, instruction)
}

get_instruction_from_bytes :: proc(data: []byte) -> (Intruction, int) {
    using bits
    result_intruction: Intruction
    bytes_used: int = 2

    // Op_code
    op_code_u8 := bitfield_extract(data[0], 4, 4)

    if cast(Mov_codes)op_code_u8 == .MOV_IMMEDIATE_TO_REG {
        result_intruction.op = .mov
        result_intruction.op_code = op_code_u8
    } else {
        op_code_u8 = bitfield_extract(data[0], 2, 6)
        result_intruction.op = .mov
        result_intruction.op_code = op_code_u8
    }

    if cast(Mov_codes)result_intruction.op_code == .MOV_REG_OR_MEM_FROM_REG {
        dw_u8 := bitfield_extract(data[0], 0, 2)
        if dw_u8 & 0b1 == 0b1 do result_intruction.w = true
        if (dw_u8 >> 1) & 0b1 == 0b1 do result_intruction.d = true

        mod_u8 := bitfield_extract(data[1], 6, 2)
        result_intruction.mod = cast(Mod_encodings)mod_u8

        reg_u8 := bitfield_extract(data[1], 3, 3)
        result_intruction.reg = reg_u8

        r_m_u8 := bitfield_extract(data[1], 0, 3)
        result_intruction.r_m = r_m_u8

        // find out of we need extra data of not
        switch result_intruction.mod {
        case .MEMORY_MODE_8BIT_DISP:
            result_intruction.data = cast(u16)data[2]
            bytes_used += 1
        case .MEMORY_MODE_16BIT_DISP:
            result_intruction.data = (cast(u16)data[2]) + cast(u16)data[3] << 8
            bytes_used += 2
        case .MEMORY_MODE:
            if result_intruction.r_m == 0b110 {
                result_intruction.data = (cast(u16)data[2]) + cast(u16)data[3] << 8
                bytes_used += 2
            }
        case .REGISTER_MODE:

        }
    }

    if cast(Mov_codes)result_intruction.op_code == .MOV_IMMEDIATE_TO_REG {
        w_u8 := bitfield_extract(data[0], 3, 1)
        if w_u8 == 0b1 {
            result_intruction.w = true
            result_intruction.data = (cast(u16)data[1]) + cast(u16)data[2] << 8
            bytes_used += 1
        } else do result_intruction.data = cast(u16)data[1]
        reg_u8 := bitfield_extract(data[0], 0, 3)
        result_intruction.reg = reg_u8
    }


    return result_intruction, bytes_used
}

write_asm_instruction_to_file :: proc(fd: os.Handle, instruction: Intruction) {
    assert(instruction.op == .mov)

    if cast(Mov_codes)instruction.op_code == .MOV_IMMEDIATE_TO_REG {
        reg: Register
        if instruction.w do reg = cast(Registers_wide)instruction.reg
	else do reg = cast(Registers_non_wide)instruction.reg

        fmt.fprintf(fd, "%v %v, %v\n", instruction.op, reg, instruction.data)
        return
    }

    switch instruction.mod {
    case .REGISTER_MODE:
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
        fmt.fprintf(fd, "%v %v, %v\n", instruction.op, destination_reg, source_reg)

    case .MEMORY_MODE_8BIT_DISP, .MEMORY_MODE_16BIT_DISP:
        reg: Register
        if instruction.w do reg = cast(Registers_wide)instruction.reg
	else do reg = cast(Registers_non_wide)instruction.reg

        if instruction.d {
            fmt.fprintf(
                fd,
                "%v %v, [%v + %v]\n",
                instruction.op,
                reg,
                Effective_address_strings[instruction.r_m],
                instruction.data,
            )
        } else {
            fmt.fprintf(
                fd,
                "%v [%v + %v], %v\n",
                instruction.op,
                Effective_address_strings[instruction.r_m],
                instruction.data,
                reg,
            )
        }

    case .MEMORY_MODE:
        if instruction.r_m == 0b110 {
            reg: Register
            if instruction.w do reg = cast(Registers_wide)instruction.reg
	    else do reg = cast(Registers_non_wide)instruction.reg

            if instruction.d {
                fmt.fprintf(fd, "%v %v, [%v]\n", instruction.op, reg, instruction.data)
            } else {
                fmt.fprintf(fd, "%v [%v], %v\n", instruction.op, instruction.data, reg)
            }
        } else {
            reg: Register
            if instruction.w do reg = cast(Registers_wide)instruction.reg
	    else do reg = cast(Registers_non_wide)instruction.reg

            if instruction.d {
                fmt.fprintf(fd, "%v %v, [%v]\n", instruction.op, reg, Effective_address_strings[instruction.r_m])
            } else {
                fmt.fprintf(fd, "%v [%v], %v\n", instruction.op, Effective_address_strings[instruction.r_m], reg)
            }
        }
    }
}
