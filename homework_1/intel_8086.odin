package intel_8086

import "core:fmt"
import "core:bytes"
import "core:os"
import "core:log"
import "core:strings"
import "core:math/bits"

extract :: bits.bitfield_extract

main :: proc() {
    logger := log.create_console_logger()
    context.logger = logger
    defer log.destroy_console_logger(logger)
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
    fd, err := os.open("test.asm", os.O_RDWR | os.O_CREATE, 0o777)
    if err != os.ERROR_NONE {
	log.error("Can't make test.asm")
	os.exit(1)
    }
    fmt.fprintf(fd, "bits 16\n\n")
    
    registers := [8]u16{}
    flags: Flags
    ip := 0
    for ip < len(data) {
        instruction, bytes_used_by_inst := get_instruction_from_bytes(data[ip:])
	ip += bytes_used_by_inst
	fmt.println(instruction.op)
	compute_instruction(instruction,registers[:], &flags, &ip)
        write_asm_instruction(fd, instruction)
    }

    print_registers(registers[:])
    fmt.println(flags)
    fmt.println(ip)
}

get_instruction_from_bytes :: proc(data: []byte) -> (Instruction, int) {
    result_instruction: Instruction
    bytes_used: int = 2

    switch {
    case cast(Op)(data[0] >> 4) == .MOV_IMMEDIATE_TO_REG:
        result_instruction.op = .MOV_IMMEDIATE_TO_REG
        result_instruction.w = extract(data[0], 3, 1) == 1
        reg_u8 := extract(data[0], 0, 3)
        reg: Register = cast(Registers_wide)reg_u8 if result_instruction.w else cast(Registers_non_wide)reg_u8
        result_instruction.reg = reg
        bytes_used = get_data_immidiate(&result_instruction, data[:], bytes_used)

    case cast(Op)(data[0] >> 2) == .MOV_REG_OR_MEM_FROM_REG:
        result_instruction.op = .MOV_REG_OR_MEM_FROM_REG
        bytes_used = reg_or_mem_from_reg(&result_instruction, data[:], bytes_used)

    case cast(Op)(data[0] >> 1) == .ADD_IMMEDIATE_TO_ACC:
        result_instruction.op = .ADD_IMMEDIATE_TO_ACC
        result_instruction.w = (data[0] & 0b1) == 0b1
        result_instruction.reg = Registers_wide.ax if result_instruction.w else Registers_non_wide.al
        bytes_used = get_data_immidiate(&result_instruction, data[:], bytes_used)

    case cast(Op)(data[0] >> 2) == .ADD_REG_OR_MEM_FROM_REG:
        result_instruction.op = .ADD_REG_OR_MEM_FROM_REG
        bytes_used = reg_or_mem_from_reg(&result_instruction, data[:], bytes_used)

    case cast(Op)(data[0] >> 1) == .SUB_IMMEDIATE_TO_ACC:
        result_instruction.op = .SUB_IMMEDIATE_TO_ACC
        result_instruction.w = data[0] & 0b1 == 0b1
        result_instruction.reg = Registers_wide.ax if result_instruction.w else Registers_non_wide.al
        bytes_used = get_data_immidiate(&result_instruction, data[:], bytes_used)

    case cast(Op)(data[0] >> 2) == .SUB_REG_OR_MEM_FROM_REG:
        result_instruction.op = .SUB_REG_OR_MEM_FROM_REG
        bytes_used = reg_or_mem_from_reg(&result_instruction, data[:], bytes_used)

    case cast(Op)(data[0] >> 1) == .CMP_IMMEDIATE_TO_ACC:
        result_instruction.op = .CMP_IMMEDIATE_TO_ACC
        result_instruction.w = data[0] & 0b1 == 0b1
        result_instruction.reg = Registers_wide.ax if result_instruction.w else Registers_non_wide.al
        bytes_used = get_data_immidiate(&result_instruction, data[:], bytes_used)

    case cast(Op)(data[0] >> 2) == .CMP_REG_OR_MEM_FROM_REG:
        result_instruction.op = .CMP_REG_OR_MEM_FROM_REG
        bytes_used = reg_or_mem_from_reg(&result_instruction, data[:], bytes_used)

    case cast(Op)(data[0] >> 2) == .ARITHMETIC_IMMEDIATE_REG_MEM:
        Arithmetic_immidiate_reg_mem_types :: enum u8 {
            add = 0b000,
            sub = 0b101,
            cmp = 0b111,
        }
        result_instruction.s = extract(data[0], 1, 1) == 0b1
        result_instruction.w = extract(data[0], 0, 1) == 0b1
        result_instruction.mod = cast(Mod_encodings)extract(data[1], 6, 2)
        result_instruction.r_m = extract(data[1], 0, 3)
        type := cast(Arithmetic_immidiate_reg_mem_types)extract(data[1], 3, 3)
        switch type {
        case .add:
            result_instruction.op = .ADD_IMMEDIATE_REG_MEM
        case .cmp:
            result_instruction.op = .CMP_IMMEDIATE_REG_MEM
        case .sub:
            result_instruction.op = .SUB_IMMEDIATE_REG_MEM
        }
        bytes_used = get_displacement(&result_instruction, data, bytes_used)

        if result_instruction.w && !result_instruction.s {
            result_instruction.data = cast(u16)data[bytes_used] + cast(u16)data[bytes_used + 1] << 8
            bytes_used += 2
        } else if result_instruction.w && result_instruction.s {
            result_instruction.data = auto_cast cast(i16)cast(i8)data[bytes_used]
            bytes_used += 1
        } else {
            result_instruction.data = auto_cast data[bytes_used]
            bytes_used += 1
        }

    case cast(Op)(data[0] >> 1) == .MOV_IMMEDIATE_REG_MEM:
        result_instruction.op = .MOV_IMMEDIATE_REG_MEM
        result_instruction.w = extract(data[0], 0, 1) == 0b1
        result_instruction.mod = cast(Mod_encodings)extract(data[1], 6, 2)
        result_instruction.r_m = extract(data[1], 0, 3)

        bytes_used = get_displacement(&result_instruction, data, bytes_used)

        if result_instruction.w {
            result_instruction.data = cast(u16)data[bytes_used] + cast(u16)data[bytes_used + 1] << 8
            bytes_used += 2
        } else {
            result_instruction.data = cast(u16)data[bytes_used]
            bytes_used += 1
        }

    case cast(Op)(data[0] >> 1) == .MOV_ACC_TO_MEM:
        result_instruction.op = .MOV_ACC_TO_MEM
        result_instruction.w = extract(data[0], 0, 1) == 1

        if result_instruction.w {
            result_instruction.displ = cast(i16)(cast(u16)data[1] + cast(u16)data[2] << 8)
            bytes_used += 1
        } else do result_instruction.displ = cast(i16)cast(i8)data[1]

    case cast(Op)(data[0] >> 1) == .MOV_MEM_TO_ACC:
        result_instruction.op = .MOV_MEM_TO_ACC
        result_instruction.w = extract(data[0], 0, 1) == 1

        if result_instruction.w {
            result_instruction.displ = cast(i16)(cast(u16)data[1] + cast(u16)data[2] << 8)
            bytes_used += 1
        } else do result_instruction.displ = cast(i16)cast(i8)data[1]

    case cast(Op)data[0] == .JMP_EQUAL:
        fallthrough
    case cast(Op)data[0] == .JMP_LESS:
        fallthrough
    case cast(Op)data[0] == .JMP_LESS_OR_EQUAL:
        fallthrough
    case cast(Op)data[0] == .JMP_BELOW:
        fallthrough
    case cast(Op)data[0] == .JMP_BELOW_OR_EQUAL:
        fallthrough
    case cast(Op)data[0] == .JMP_PARITY:
        fallthrough
    case cast(Op)data[0] == .JMP_OVERFLOW:
        fallthrough
    case cast(Op)data[0] == .JMP_SIGN:
        fallthrough
    case cast(Op)data[0] == .JMP_NOT_EQUAL:
        fallthrough
    case cast(Op)data[0] == .JMP_NOT_LESS:
        fallthrough
    case cast(Op)data[0] == .JMP_GREATER:
        fallthrough
    case cast(Op)data[0] == .JMP_NOT_BELOW:
        fallthrough
    case cast(Op)data[0] == .JMP_ABOVE:
        fallthrough
    case cast(Op)data[0] == .JMP_NOT_PARITY:
        fallthrough
    case cast(Op)data[0] == .JMP_NOT_OVERFLOW:
        fallthrough
    case cast(Op)data[0] == .JMP_NOT_SIGN:
        fallthrough
    case cast(Op)data[0] == .LOOP:
        fallthrough
    case cast(Op)data[0] == .LOOP_WHILE_ZERO:
        fallthrough
    case cast(Op)data[0] == .LOOP_WHILE_NOT_ZERO:
        fallthrough
    case cast(Op)data[0] == .JMP_CX_ZERO:
        result_instruction.op = cast(Op)data[0]
        result_instruction.data = cast(u16)data[1]

    case:
        fmt.eprintf("%x\n", data[0])
        panic("ERROR: Unknown instrunction")
    }

    when !ODIN_DEBUG {
	fmt.println(result_instruction.op)
    }
    return result_instruction, bytes_used

    get_data_immidiate :: proc(result_instruction: ^Instruction, data: []byte, bytes_used: int) -> int {
        bytes_used := bytes_used
        if result_instruction.w {
            result_instruction.data = cast(u16)data[1] + cast(u16)data[2] << 8
            bytes_used += 1
        } else do result_instruction.data = cast(u16)data[1]
        return bytes_used
    }

    get_displacement :: proc(result_instruction: ^Instruction, data: []byte, bytes_used: int) -> int {
        bytes_used := bytes_used
        switch result_instruction.mod {
        case .MEMORY_MODE_8BIT_DISP:
            if result_instruction.w {
                result_instruction.displ = cast(i16)cast(i8)data[2]
                bytes_used += 1
            } else {
                result_instruction.displ = cast(i16)cast(i8)data[2]
                bytes_used += 1
            }
        case .MEMORY_MODE_16BIT_DISP:
            result_instruction.displ = cast(i16)((cast(u16)data[2]) + cast(u16)data[3] << 8)
            bytes_used += 2
        case .MEMORY_MODE:
            if result_instruction.r_m == 0b110 {
                result_instruction.displ = cast(i16)(cast(u16)data[2] + cast(u16)data[3] << 8)
                bytes_used += 2
            }
        case .REGISTER_MODE:
        }
        return bytes_used
    }

    reg_or_mem_from_reg :: proc(result_instruction: ^Instruction, data: []byte, bytes_used: int) -> int {
        using bits
        bytes_used := bytes_used
        dw_u8 := extract(data[0], 0, 2)
        if dw_u8 & 0b1 == 0b1 do result_instruction.w = true
        if (dw_u8 >> 1) & 0b1 == 0b1 do result_instruction.d = true

        mod_u8 := extract(data[1], 6, 2)
        result_instruction.mod = cast(Mod_encodings)mod_u8

        reg_u8 := extract(data[1], 3, 3)
        result_instruction.reg = cast(Registers_wide)reg_u8 if result_instruction.w else cast(Registers_non_wide)reg_u8

        r_m_u8 := extract(data[1], 0, 3)
        result_instruction.r_m = r_m_u8

        bytes_used = get_displacement(result_instruction, data, bytes_used)
        return bytes_used
    }
}

write_asm_instruction :: proc(fd: os.Handle, instruction: Instruction) {
    @(static)
    Op_strings: #sparse[Op]string = {
        .NONE                         = "",
        .ARITHMETIC_IMMEDIATE_REG_MEM = "",
        .MOV_IMMEDIATE_TO_REG         = "mov",
        .MOV_REG_OR_MEM_FROM_REG      = "mov",
        .MOV_MEM_TO_ACC               = "mov",
        .MOV_ACC_TO_MEM               = "mov",
        .ADD_REG_OR_MEM_FROM_REG      = "add",
        .ADD_IMMEDIATE_TO_ACC         = "add",
        .SUB_REG_OR_MEM_FROM_REG      = "sub",
        .SUB_IMMEDIATE_TO_ACC         = "sub",
        .CMP_REG_OR_MEM_FROM_REG      = "cmp",
        .CMP_IMMEDIATE_TO_ACC         = "cmp",
        .ADD_IMMEDIATE_REG_MEM        = "add",
        .SUB_IMMEDIATE_REG_MEM        = "sub",
        .CMP_IMMEDIATE_REG_MEM        = "cmp",
        .MOV_IMMEDIATE_REG_MEM        = "mov",
        .JMP_EQUAL                    = "je",
        .JMP_LESS                     = "jl",
        .JMP_LESS_OR_EQUAL            = "jle",
        .JMP_BELOW                    = "jb",
        .JMP_BELOW_OR_EQUAL           = "jbe",
        .JMP_PARITY                   = "jp",
        .JMP_OVERFLOW                 = "jo",
        .JMP_SIGN                     = "js",
        .JMP_NOT_EQUAL                = "jne",
        .JMP_NOT_LESS                 = "jnl",
        .JMP_GREATER                  = "jg",
        .JMP_NOT_BELOW                = "jnb",
        .JMP_ABOVE                    = "ja",
        .JMP_NOT_PARITY               = "jnp",
        .JMP_NOT_OVERFLOW             = "jno",
        .JMP_NOT_SIGN                 = "jns",
        .LOOP                         = "loop",
        .LOOP_WHILE_ZERO              = "loopz",
        .LOOP_WHILE_NOT_ZERO          = "loopnz",
        .JMP_CX_ZERO                  = "jcxz",
    }
    @(static)
    Effective_address_strings := [Effective_address]string {
        .BX_PLUS_SI = "bx + si",
        .BX_PLUS_DI = "bx + di",
        .BP_PLUS_SI = "bp + si",
        .BP_PLUS_DI = "bp + di",
        .SI         = "si",
        .DI         = "di",
        .BP         = "bp",
        .BX         = "bx",
    }
    using instruction
    assert(len(Op_strings[op]) != 0)
    switch op {
    case .MOV_IMMEDIATE_TO_REG, .ADD_IMMEDIATE_TO_ACC, .SUB_IMMEDIATE_TO_ACC, .CMP_IMMEDIATE_TO_ACC:
        fmt.fprintf(fd, "%v %v, %v\n", Op_strings[op], reg, data)

    case .MOV_REG_OR_MEM_FROM_REG, .ADD_REG_OR_MEM_FROM_REG, .SUB_REG_OR_MEM_FROM_REG, .CMP_REG_OR_MEM_FROM_REG:
        switch mod {
        case .REGISTER_MODE:
            // Determine the registers
            reg_r_m: Register = cast(Registers_wide)r_m if w else cast(Registers_non_wide)r_m
            fmt.fprintf(fd, "%v %v, %v\n", Op_strings[op], reg_r_m, reg)
        case .MEMORY_MODE_8BIT_DISP, .MEMORY_MODE_16BIT_DISP:
            sign := "-" if displ < 0 else "+"
            if d {
                fmt.fprintf(
                    fd,
                    "%v %v, [%v %s %v]\n",
                    Op_strings[op],
                    reg,
                    Effective_address_strings[auto_cast r_m],
                    sign,
                    abs(displ),
                )
            } else {
                fmt.fprintf(
                    fd,
                    "%v [%v %s %v], %v\n",
                    Op_strings[op],
                    Effective_address_strings[auto_cast r_m],
                    sign,
                    abs(displ),
                    reg,
                )
            }
        case .MEMORY_MODE:
            if r_m == 0b110 {
                if d {
                    fmt.fprintf(fd, "%v %v, [%v]\n", Op_strings[op], reg, displ)
                } else {
                    fmt.fprintf(fd, "%v [%v], %v\n", Op_strings[op], displ, reg)
                }
            } else {
                if d {
                    fmt.fprintf(fd, "%v %v, [%v]\n", Op_strings[op], reg, Effective_address_strings[auto_cast r_m])
                } else {
                    fmt.fprintf(fd, "%v [%v], %v\n", Op_strings[op], Effective_address_strings[auto_cast r_m], reg)
                }
            }
        }

    case .ADD_IMMEDIATE_REG_MEM, .SUB_IMMEDIATE_REG_MEM, .CMP_IMMEDIATE_REG_MEM, .MOV_IMMEDIATE_REG_MEM:
        size: string = "word" if w else "byte"
        switch mod {
        case .REGISTER_MODE:
            reg_r_m: Register = cast(Registers_wide)r_m if w else cast(Registers_non_wide)r_m
            fmt.fprintf(fd, "%v %v, %v\n", Op_strings[op], reg_r_m, data)
        case .MEMORY_MODE_8BIT_DISP, .MEMORY_MODE_16BIT_DISP:
            sign := "-" if displ < 0 else "+"
            fmt.fprintf(
                fd,
                "%v %v [%v %s %v], %v\n",
                Op_strings[op],
                size,
                Effective_address_strings[auto_cast r_m],
                sign,
                abs(displ),
                data,
            )
        case .MEMORY_MODE:
            if r_m == 0b110 {
                fmt.fprintf(fd, "%v %v [%v], %v\n", Op_strings[op], size, displ, data)
            } else {
                fmt.fprintf(
                    fd,
                    "%v %v [%v], %v\n",
                    Op_strings[op],
                    size,
                    Effective_address_strings[auto_cast r_m],
                    data,
                )
            }
        }

    case .MOV_ACC_TO_MEM:
        fmt.fprintf(fd, "%v [%v], ax\n", Op_strings[op], displ)

    case .MOV_MEM_TO_ACC:
        fmt.fprintf(fd, "%v ax, [%v]\n", Op_strings[op], displ)

    case .JMP_EQUAL, .JMP_ABOVE, .JMP_BELOW, .JMP_BELOW_OR_EQUAL, .JMP_CX_ZERO, .JMP_GREATER, .JMP_LESS,
	    .JMP_LESS_OR_EQUAL, .JMP_NOT_BELOW, .JMP_NOT_EQUAL, .JMP_NOT_LESS, .JMP_NOT_OVERFLOW, .JMP_NOT_PARITY,
	    .JMP_NOT_SIGN, .JMP_OVERFLOW, .JMP_PARITY, .JMP_SIGN, .LOOP, .LOOP_WHILE_NOT_ZERO, .LOOP_WHILE_ZERO:
        data_u8: u8 = auto_cast extract(data, 0, 8)
        is_negative := extract(data_u8, 7, 1) == 0b1 // if leading bit is 1 => negative
        // twos complement allowes us to have a unique zero, not +- 0, just 0
        negative_displacement := (~data_u8) + 1 - 2
        if is_negative {
            if negative_displacement == 0 do fmt.fprintf(fd, "%v $+%v\n", Op_strings[op], negative_displacement)
            else do fmt.fprintf(fd, "%v $-%v\n", Op_strings[op], negative_displacement)
        } else do fmt.fprintf(fd, "%v $+%v\n", Op_strings[op], data_u8 + 2)

    case .NONE, .ARITHMETIC_IMMEDIATE_REG_MEM:
        panic("Unknown instruction operation")
    }

}

compute_instruction :: proc(instruction: Instruction, registers: []u16, flags: ^Flags, ip: ^int) {
    using instruction
    assert(len(registers) == 8)
    #partial switch op {
    case .MOV_IMMEDIATE_TO_REG:
	assert(w)
	dest_index : int = auto_cast reg.(Registers_wide)
	registers[dest_index] = data

    case .MOV_REG_OR_MEM_FROM_REG:
	assert(mod == .REGISTER_MODE && w)
	dest_index, source_index := get_dest_source_indices(instruction)
	registers[dest_index] = registers[source_index]

    case .SUB_REG_OR_MEM_FROM_REG:
	assert(mod == .REGISTER_MODE && w)
	dest_index, source_index := get_dest_source_indices(instruction)
	registers[dest_index] -= registers[source_index]
	flags.sign = extract(registers[dest_index], 15, 1) == 1
	flags.zero = registers[dest_index] == 0

    case .ADD_REG_OR_MEM_FROM_REG:
	assert(mod == .REGISTER_MODE && w)
	dest_index, source_index := get_dest_source_indices(instruction)
	registers[dest_index] += registers[source_index]
	flags.sign = extract(registers[dest_index], 15, 1) == 1
	flags.zero = registers[dest_index] == 0

    case .CMP_REG_OR_MEM_FROM_REG:
	assert(mod == .REGISTER_MODE && w)
	dest_index, source_index := get_dest_source_indices(instruction)
	copy_dest := registers[dest_index]
	copy_dest -= registers[source_index]
	flags.sign = extract(copy_dest, 15, 1) == 1
	flags.zero = copy_dest == 0

    case .ADD_IMMEDIATE_REG_MEM:
	assert(w && mod == .REGISTER_MODE)
	dest_index := r_m
	registers[dest_index] += data
	flags.sign = extract(registers[dest_index], 15, 1) == 1
	flags.zero = registers[dest_index] == 0

    case .SUB_IMMEDIATE_REG_MEM:
	assert(w && mod == .REGISTER_MODE)
	dest_index := r_m
	registers[dest_index] -= data
	flags.sign = extract(registers[dest_index], 15, 1) == 1
	flags.zero = registers[dest_index] == 0

    case .CMP_IMMEDIATE_REG_MEM:
	assert(w && mod == .REGISTER_MODE)
	dest_index := r_m
	copy_dest := registers[dest_index]
	copy_dest -= data
	flags.sign = extract(copy_dest, 15, 1) == 1
	flags.zero = copy_dest == 0
    }

    get_dest_source_indices :: #force_inline proc(instruction: Instruction) -> (dest_index, source_index: u8) {
	using instruction
	if d {
	    dest_index = register_wide_to_u8[reg.(Registers_wide)]
	    source_index = r_m
	} else {
	    dest_index = r_m
	    source_index = register_wide_to_u8[reg.(Registers_wide)]
	}
	return
    }
}

print_registers :: proc(registers: []u16) {
    assert(len(registers) == 8)
    fmt.println(Registers_wide.ax, registers[0])
    fmt.println(Registers_wide.bx, registers[3])
    fmt.println(Registers_wide.cx, registers[1])
    fmt.println(Registers_wide.dx, registers[2])
    fmt.println(Registers_wide.sp, registers[4])
    fmt.println(Registers_wide.bp, registers[5])
    fmt.println(Registers_wide.si, registers[6])
    fmt.println(Registers_wide.di, registers[7])
}

Op :: enum u8 {
    MOV_IMMEDIATE_TO_REG = 0b1011,
    MOV_REG_OR_MEM_FROM_REG = 0b100010,
    MOV_IMMEDIATE_REG_MEM = 0b1100011,
    MOV_MEM_TO_ACC = 0b1010000,
    MOV_ACC_TO_MEM = 0b1010001,
    ADD_REG_OR_MEM_FROM_REG = 0b00000,
    ADD_IMMEDIATE_TO_ACC = 0b0000010,
    SUB_REG_OR_MEM_FROM_REG = 0b001010,
    SUB_IMMEDIATE_TO_ACC = 0b0010110,
    CMP_REG_OR_MEM_FROM_REG = 0b001110,
    CMP_IMMEDIATE_TO_ACC = 0b0011110,
    ARITHMETIC_IMMEDIATE_REG_MEM = 0b100000,
    JMP_EQUAL = 0b01110100,
    JMP_LESS = 0b01111100,
    JMP_LESS_OR_EQUAL = 0b01111110,
    JMP_BELOW = 0b01110010,
    JMP_BELOW_OR_EQUAL = 0b01110110,
    JMP_PARITY = 0b01111010,
    JMP_OVERFLOW = 0b01110000,
    JMP_SIGN = 0b01111000,
    JMP_NOT_EQUAL = 0b01110101,
    JMP_NOT_LESS = 0b01111101,
    JMP_GREATER = 0b01111111,
    JMP_NOT_BELOW = 0b01110011,
    JMP_ABOVE = 0b01110111,
    JMP_NOT_PARITY = 0b01111011,
    JMP_NOT_OVERFLOW = 0b01110001,
    JMP_NOT_SIGN = 0b01111001,
    LOOP = 0b11100010,
    LOOP_WHILE_ZERO = 0b11100001,
    LOOP_WHILE_NOT_ZERO = 0b11100000,
    JMP_CX_ZERO = 0b11100011,
    ADD_IMMEDIATE_REG_MEM,
    SUB_IMMEDIATE_REG_MEM,
    CMP_IMMEDIATE_REG_MEM,
    NONE,
}

Mod_encodings :: enum u8 {
    MEMORY_MODE            = 0x0,
    REGISTER_MODE          = 0x3,
    MEMORY_MODE_8BIT_DISP  = 0x1,
    MEMORY_MODE_16BIT_DISP = 0x2,
}


Effective_address :: enum u8 {
    BX_PLUS_SI,
    BX_PLUS_DI,
    BP_PLUS_SI,
    BP_PLUS_DI,
    SI,
    DI,
    BP,
    BX,
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

register_wide_to_u8 := [Registers_wide]u8{
    .ax = 0x0,
    .cx = 0x1,
    .dx = 0x2,
    .bx = 0x3,
    .sp = 0x4,
    .bp = 0x5,
    .si = 0x6,
    .di = 0x7,
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

register_non_wide_to_u8 := [Registers_non_wide]u8 {
    .al = 0x0,
    .cl = 0x1,
    .dl = 0x2,
    .bl = 0x3,
    .ah = 0x4,
    .ch = 0x5,
    .dh = 0x6,
    .bh = 0x7,
}

Register :: union {
    Registers_wide,
    Registers_non_wide,
}

Instruction :: struct {
    op:    Op,
    d:     bool, // 1 bit , d as destination
    w:     bool, // 1 bit, w as wide
    s:     bool,
    mod:   Mod_encodings, // 2 bits
    reg:   Register, // 3 bits
    r_m:   u8, // 3 bits
    displ: i16, // can be 8 or 16 bits
    data:  u16, // can be 8 or 16 bits
}

Flags :: struct {
    sign: bool,
    zero: bool,
}
