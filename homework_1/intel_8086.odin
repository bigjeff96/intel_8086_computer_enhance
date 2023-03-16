package intel_8086

import "core:fmt"
import "core:bytes"
import "core:os"
import "core:log"
import "core:math/bits"

main :: proc() {
    using bits
    data, ok := os.read_entire_file_from_filename("data/listing_0037_single_register_mov")
    if !ok {
	fmt.eprint("Can't read file")
	os.exit(1)
    }
    
    fmt.printf("%X\n", bitfield_extract(data[0], 0,2)) //last 2 bits of byte, here bitfield extract does matter here since
    fmt.printf("%X\n", bitfield_extract(data[0], 2, 8)) // doesn't matter here since leading zeros do fuck all
}

