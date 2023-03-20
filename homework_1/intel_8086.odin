package intel_8086

import "core:fmt"
import "core:bytes"
import "core:os"
import "core:log"
import "core:strings"
import "core:math/bits"

Op_codes :: enum u8 {
    MOV_IMMEDIATE_TO_REG         = 0b1011,
    MOV_REG_OR_MEM_FROM_REG      = 0b100010,
    ADD_REG_OR_MEM_FROM_REG      = 0b0,
    ADD_IMMEDIATE_TO_ACC         = 0b0000010,
    SUB_REG_OR_MEM_FROM_REG      = 0b001010,
    SUB_IMMEDIATE_TO_ACC         = 0b0010110,
    CMP_REG_OR_MEM_FROM_REG      = 0b001110,
    CMP_IMMEDIATE_TO_ACC         = 0b0011110,
    ARITHMETIC_IMMEDIATE_REG_MEM = 0b100000,
    JMP_EQUAL                    = 0b01110100,
    JMP_LESS                     = 0b01111100,
    JMP_LESS_OR_EQUAL            = 0b01111110,
    JMP_BELOW                    = 0b01110010,
    JMP_BELOW_OR_EQUAL           = 0b01110110,
    JMP_PARITY                   = 0b01111010,
    JMP_OVERFLOW                 = 0b01110000,
    JMP_SIGN                     = 0b01111000,
    JMP_NOT_EQUAL                = 0b01110101,
    JMP_NOT_LESS                 = 0b01111101,
    JMP_GREATER                  = 0b01111111,
    JMP_NOT_BELOW                = 0b01110011,
    JMP_ABOVE                    = 0b01110111,
    JMP_NOT_PARITY               = 0b01111011,
    JMP_NOT_OVERFLOW             = 0b01110001,
    JMP_NOT_SIGN                 = 0b01111001,
    LOOP                         = 0b11100010,
    LOOP_WHILE_ZERO              = 0b11100001,
    LOOP_WHILE_NOT_ZERO          = 0b11100000,
    JMP_CX_ZERO                  = 0b11100011,
}

Arithmetic_immidiate_reg_mem_types :: enum u8 {
    add = 0b000,
    sub = 0b101,
    cmp = 0b111,
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
    op:     Op_codes,
    op_str: string,
    d:      bool, // 1 bit , d as destination
    w:      bool, // 1 bit, w as wide
    s:      bool,
    mod:    Mod_encodings, // 2 bits
    reg:    Register, // 3 bits
    r_m:    u8, // 3 bits
    displ:  u16, // can be 8 or 16 bits
    data:   u16, // can be 8 or 16 bits
}

main :: proc() {
    if len(os.args) != 2 {
        fmt.printf("Usage: %s file.asm", os.args[0])
        os.exit(1)
    }
    data, ok := os.read_entire_file_from_filename(os.args[1])
    if !ok {
        log.error("Can't read file")
        os.exit(1)
    }
    defer delete(data)

    fd: os.Handle = os.stdout
    fmt.fprintf(fd, "bits 16\n\n")
    bytes_used := 0
    for i := 0; i < len(data); i += bytes_used {
        shift := 7 if i + 7 <= len(data) else len(data) - i
        instruction, bytes_used_by_inst := get_instruction_from_bytes(data[i:i + shift])
        bytes_used = bytes_used_by_inst
        write_asm_instruction(fd, &instruction)
    }
}

get_instruction_from_bytes :: proc(data: []byte) -> (Intruction, int) {
    /* using bits */
    result_intruction: Intruction
    bytes_used: int = 2

    // Op_code
    if cast(Op_codes)(data[0] >> 4) == .MOV_IMMEDIATE_TO_REG {
        result_intruction.op = .MOV_IMMEDIATE_TO_REG
        result_intruction.op_str = "mov"
        result_intruction.w = bits.bitfield_extract(data[0], 3, 1) == 1
        reg_u8 := bits.bitfield_extract(data[0], 0, 3)
        reg: Register = cast(Registers_wide)reg_u8 if result_intruction.w else cast(Registers_non_wide)reg_u8
        result_intruction.reg = reg
        get_data_immidiate(&result_intruction, data[:], &bytes_used)

    } else if cast(Op_codes)(data[0] >> 2) == .MOV_REG_OR_MEM_FROM_REG {
        result_intruction.op = .MOV_REG_OR_MEM_FROM_REG
        result_intruction.op_str = "mov"
        reg_or_mem_from_reg(&result_intruction, data[:], &bytes_used)

    } else if cast(Op_codes)(data[0] >> 1) == .ADD_IMMEDIATE_TO_ACC {
        result_intruction.op = .ADD_IMMEDIATE_TO_ACC
        result_intruction.op_str = "add"
        result_intruction.w = (data[0] & 0b1) == 0b1
        result_intruction.reg = Registers_wide.ax if result_intruction.w else Registers_non_wide.al
        get_data_immidiate(&result_intruction, data[:], &bytes_used)

    } else if cast(Op_codes)(data[0] >> 2) == .ADD_REG_OR_MEM_FROM_REG {
        result_intruction.op = .ADD_REG_OR_MEM_FROM_REG
        result_intruction.op_str = "add"
        reg_or_mem_from_reg(&result_intruction, data[:], &bytes_used)
    } else if cast(Op_codes)(data[0] >> 1) == .SUB_IMMEDIATE_TO_ACC {
        result_intruction.op = .SUB_IMMEDIATE_TO_ACC
        result_intruction.op_str = "sub"
        result_intruction.w = data[0] & 0b1 == 0b1
        result_intruction.reg = Registers_wide.ax if result_intruction.w else Registers_non_wide.al
        get_data_immidiate(&result_intruction, data[:], &bytes_used)

    } else if cast(Op_codes)(data[0] >> 2) == .SUB_REG_OR_MEM_FROM_REG {
        result_intruction.op = .SUB_REG_OR_MEM_FROM_REG
        result_intruction.op_str = "sub"
        reg_or_mem_from_reg(&result_intruction, data[:], &bytes_used)

    } else if cast(Op_codes)(data[0] >> 1) == .CMP_IMMEDIATE_TO_ACC {
        result_intruction.op = .CMP_IMMEDIATE_TO_ACC
        result_intruction.op_str = "cmp"
        result_intruction.w = data[0] & 0b1 == 0b1
        result_intruction.reg = Registers_wide.ax if result_intruction.w else Registers_non_wide.al
        get_data_immidiate(&result_intruction, data[:], &bytes_used)

    } else if cast(Op_codes)(data[0] >> 2) == .CMP_REG_OR_MEM_FROM_REG {
        result_intruction.op = .CMP_REG_OR_MEM_FROM_REG
        result_intruction.op_str = "cmp"
        reg_or_mem_from_reg(&result_intruction, data[:], &bytes_used)

    } else if cast(Op_codes)(data[0] >> 2) == .ARITHMETIC_IMMEDIATE_REG_MEM {
        result_intruction.op = .ARITHMETIC_IMMEDIATE_REG_MEM
        result_intruction.s = bits.bitfield_extract(data[0], 1, 1) == 0b1
        result_intruction.w = bits.bitfield_extract(data[0], 0, 1) == 0b1
        result_intruction.mod = cast(Mod_encodings)bits.bitfield_extract(data[1], 6, 2)
        result_intruction.r_m = bits.bitfield_extract(data[1], 0, 3)
        type := cast(Arithmetic_immidiate_reg_mem_types)bits.bitfield_extract(data[1], 3, 3)
        switch type {
        case .add:
            result_intruction.op_str = "add"
        case .cmp:
            result_intruction.op_str = "cmp"
        case .sub:
            result_intruction.op_str = "sub"
        }
        switch result_intruction.mod {
        case .MEMORY_MODE_8BIT_DISP:
            result_intruction.displ = cast(u16)data[2]
            bytes_used += 1
        case .MEMORY_MODE_16BIT_DISP:
            result_intruction.displ = (cast(u16)data[2]) + cast(u16)data[3] << 8
            bytes_used += 2
        case .MEMORY_MODE:
            if result_intruction.r_m == 0b110 {
                result_intruction.displ = (cast(u16)data[2]) + cast(u16)data[3] << 8
                bytes_used += 2
            }
        case .REGISTER_MODE:
        }

        if result_intruction.w && !result_intruction.s {
            result_intruction.data = cast(u16)data[bytes_used] + cast(u16)data[bytes_used + 1] << 8
            bytes_used += 2
        } else {
            result_intruction.data = cast(u16)data[bytes_used]
            bytes_used += 1
        }
    } else if cast(Op_codes)data[0] == .JMP_EQUAL {
        result_intruction.op = .JMP_EQUAL
        result_intruction.op_str = "je"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .JMP_LESS {
        result_intruction.op = .JMP_LESS
        result_intruction.op_str = "jl"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .JMP_LESS_OR_EQUAL {
        result_intruction.op = .JMP_LESS_OR_EQUAL
        result_intruction.op_str = "jle"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .JMP_BELOW {
        result_intruction.op = .JMP_BELOW
        result_intruction.op_str = "jb"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .JMP_BELOW_OR_EQUAL {
        result_intruction.op = .JMP_BELOW_OR_EQUAL
        result_intruction.op_str = "jbe"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .JMP_PARITY {
        result_intruction.op = .JMP_PARITY
        result_intruction.op_str = "jp"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .JMP_OVERFLOW {
        result_intruction.op = .JMP_OVERFLOW
        result_intruction.op_str = "jo"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .JMP_SIGN {
        result_intruction.op = .JMP_SIGN
        result_intruction.op_str = "js"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .JMP_NOT_EQUAL {
        result_intruction.op = .JMP_NOT_EQUAL
        result_intruction.op_str = "jne"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .JMP_NOT_LESS {
        result_intruction.op = .JMP_NOT_LESS
        result_intruction.op_str = "jnl"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .JMP_GREATER {
        result_intruction.op = .JMP_GREATER
        result_intruction.op_str = "jg"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .JMP_NOT_BELOW {
        result_intruction.op = .JMP_NOT_BELOW
        result_intruction.op_str = "jnb"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .JMP_ABOVE {
        result_intruction.op = .JMP_ABOVE
        result_intruction.op_str = "ja"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .JMP_NOT_PARITY {
        result_intruction.op = .JMP_NOT_PARITY
        result_intruction.op_str = "jnp"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .JMP_NOT_OVERFLOW {
        result_intruction.op = .JMP_NOT_OVERFLOW
        result_intruction.op_str = "jno"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .JMP_NOT_SIGN {
        result_intruction.op = .JMP_NOT_SIGN
        result_intruction.op_str = "jns"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .LOOP {
        result_intruction.op = .LOOP
        result_intruction.op_str = "loop"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .LOOP_WHILE_ZERO {
        result_intruction.op = .LOOP_WHILE_ZERO
        result_intruction.op_str = "loopz"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .LOOP_WHILE_NOT_ZERO {
        result_intruction.op = .LOOP_WHILE_NOT_ZERO
        result_intruction.op_str = "loopnz"
        result_intruction.data = cast(u16)data[1]
    } else if cast(Op_codes)data[0] == .JMP_CX_ZERO {
        result_intruction.op = .JMP_CX_ZERO
        result_intruction.op_str = "jcxz"
        result_intruction.data = cast(u16)data[1]
    } else do panic("ERROR: Unknown instrunction")

    return result_intruction, bytes_used
}

write_asm_instruction :: proc(fd: os.Handle, instruction: ^Intruction) {
    using instruction

    switch op {
    case .MOV_IMMEDIATE_TO_REG, .ADD_IMMEDIATE_TO_ACC, .SUB_IMMEDIATE_TO_ACC, .CMP_IMMEDIATE_TO_ACC:
        fmt.fprintf(fd, "%v %v, %v\n", op_str, reg, data)

    case .MOV_REG_OR_MEM_FROM_REG, .ADD_REG_OR_MEM_FROM_REG, .SUB_REG_OR_MEM_FROM_REG, .CMP_REG_OR_MEM_FROM_REG:
        write_reg_or_mem_from_reg(instruction, fd)

    case .ARITHMETIC_IMMEDIATE_REG_MEM:
        size: string = "word" if w else "byte"
        switch mod {
        case .REGISTER_MODE:
            reg_r_m: Register = cast(Registers_wide)r_m if w else cast(Registers_non_wide)r_m
            fmt.fprintf(fd, "%v %v, %v\n", op_str, reg_r_m, data)
        case .MEMORY_MODE_8BIT_DISP, .MEMORY_MODE_16BIT_DISP:
            fmt.fprintf(fd, "%v %v [%v + %v], %v\n", op_str, size, Effective_address_strings[r_m], displ, data)
        case .MEMORY_MODE:
            if r_m == 0b110 {
                fmt.fprintf(fd, "%v %v [%v], %v\n", op_str, size, displ, data)
            } else {
                fmt.fprintf(fd, "%v %v [%v], %v\n", op_str, size, Effective_address_strings[r_m], data)
            }
        }

    case .JMP_ABOVE, .JMP_BELOW, .JMP_BELOW_OR_EQUAL, .JMP_CX_ZERO, .JMP_EQUAL, .JMP_GREATER, .JMP_LESS, .JMP_LESS_OR_EQUAL, .JMP_NOT_BELOW, .JMP_NOT_EQUAL, .JMP_NOT_LESS, .JMP_NOT_OVERFLOW, .JMP_NOT_PARITY, .JMP_NOT_SIGN, .JMP_OVERFLOW, .JMP_PARITY, .JMP_SIGN, .LOOP, .LOOP_WHILE_NOT_ZERO, .LOOP_WHILE_ZERO:
        data_u8: u8 = auto_cast bits.bitfield_extract(data, 0, 8)
        is_negative := bits.bitfield_extract(data_u8, 7, 1) == 0b1 // if leading bit is 1 => negative
        // twos complement allowes us to have a unique zero, not +- 0, just 0
        negative_displacement := (~data_u8) + 1 - 2
        if is_negative {
            if negative_displacement == 0 do fmt.fprintf(fd, "%v $+%v\n", op_str, negative_displacement)
	    else do fmt.fprintf(fd, "%v $-%v\n", op_str, negative_displacement)
        } else do fmt.fprintf(fd, "%v $+%v\n", op_str, data_u8 + 2)
    }
}

get_data_immidiate :: proc(result_intruction: ^Intruction, data: []byte, bytes_used: ^int) {
    if result_intruction.w {
        result_intruction.data = cast(u16)data[1] + cast(u16)data[2] << 8
        bytes_used^ += 1
    } else do result_intruction.data = cast(u16)data[1]
}

reg_or_mem_from_reg :: proc(result_intruction: ^Intruction, data: []byte, bytes_used: ^int) {
    using bits
    dw_u8 := bitfield_extract(data[0], 0, 2)
    if dw_u8 & 0b1 == 0b1 do result_intruction.w = true
    if (dw_u8 >> 1) & 0b1 == 0b1 do result_intruction.d = true

    mod_u8 := bitfield_extract(data[1], 6, 2)
    result_intruction.mod = cast(Mod_encodings)mod_u8

    reg_u8 := bitfield_extract(data[1], 3, 3)
    result_intruction.reg = cast(Registers_wide)reg_u8 if result_intruction.w else cast(Registers_non_wide)reg_u8

    r_m_u8 := bitfield_extract(data[1], 0, 3)
    result_intruction.r_m = r_m_u8

    switch result_intruction.mod {
    case .MEMORY_MODE_8BIT_DISP:
        result_intruction.displ = cast(u16)data[2]
        bytes_used^ += 1
    case .MEMORY_MODE_16BIT_DISP:
        result_intruction.displ = (cast(u16)data[2]) + cast(u16)data[3] << 8
        bytes_used^ += 2
    case .MEMORY_MODE:
        if result_intruction.r_m == 0b110 {
            result_intruction.displ = (cast(u16)data[2]) + cast(u16)data[3] << 8
            bytes_used^ += 2
        }
    case .REGISTER_MODE:
    }
}

write_reg_or_mem_from_reg :: proc(using intruction: ^Intruction, fd: os.Handle) {
    switch mod {
    case .REGISTER_MODE:
        // Determine the registers
        reg_r_m: Register = cast(Registers_wide)r_m if w else cast(Registers_non_wide)r_m
        fmt.fprintf(fd, "%v %v, %v\n", op_str, reg_r_m, reg)
    case .MEMORY_MODE_8BIT_DISP, .MEMORY_MODE_16BIT_DISP:
        if d {
            fmt.fprintf(fd, "%v %v, [%v + %v]\n", op_str, reg, Effective_address_strings[r_m], displ)
        } else {
            fmt.fprintf(fd, "%v [%v + %v], %v\n", op_str, Effective_address_strings[r_m], displ, reg)
        }
    case .MEMORY_MODE:
        if r_m == 0b110 {
            if d {
                fmt.fprintf(fd, "%v %v, [%v]\n", op_str, reg, displ)
            } else {
                fmt.fprintf(fd, "%v [%v], %v\n", op_str, displ, reg)
            }
        } else {
            if d {
                fmt.fprintf(fd, "%v %v, [%v]\n", op_str, reg, Effective_address_strings[r_m])
            } else {
                fmt.fprintf(fd, "%v [%v], %v\n", op_str, Effective_address_strings[r_m], reg)
            }
        }
    }
}
