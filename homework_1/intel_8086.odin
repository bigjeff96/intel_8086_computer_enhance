package intel_8086

import "core:fmt"
import "core:bytes"
import "core:os"
import "core:math/bits"

main :: proc() {
    data, ok := os.read_entire_file_from_filename("data/listing_0037_single_register_mov")
    if !ok {
	fmt.eprint("error")
	os.exit(1)
    }

    zero_bit := bits.bitfield_extract_u8(data[0], 0,4)
    bits.to_le_u8(data[0])
    fmt.printf("%X\n",data[1])
    fmt.printf("%X\n",data[0] << 6 | 0x80)
    fmt.printf("%X\n",bits.bitfield_extract_u8(data[0] << 6 | 0x80, 6,8))
    //last 2 bits of byte, here bitfield extract does matter here since
    // doing data[0] << 6 puts the last 2 bits in the highest order position, giving the byte the wrong value, so we need to shift it back to the lowest order positions
    fmt.printf("%X\n", data[0] >> 2) //first 6 bytes
    fmt.printf("%X\n", bits.bitfield_extract_u8(data[0] >> 2, 0, 6)) // doesn't matter here since leading zeros do fuck all
}

bitfield_extract_u8   :: proc(value:   u8, offset, bits: uint) ->   u8 { return (value >> offset) &   u8(1<<bits - 1) }
