#include <cstddef>
#include <cstdio>
#define GB_IMPLEMENTATION
#include "../gb.h"

struct Pair {
    f64 x, y;
};

enum Symbol_type {
    symbol_lcurly,
    symbol_rcurly,
    symbol_lsquare_bracket,
    symbol_rsquare_bracket,
    symbol_quotation_mark,
    symbol_identifier,
    symbol_colon,
    symbol_comma,
    symbol_number,
};

struct Symbol {
    Symbol_type type;
    char* start;
    size_t length;
};

int main(int argc, char** argv)
{

    gbFileContents json_file = gb_file_read_contents(gb_heap_allocator(), 1, "../pairs.json");
    defer(gb_file_free_contents(&json_file));

    char* json_str = (char*)json_file.data;
    size_t json_len = json_file.size;

    gbArray(Pair) pairs;
    gb_array_init(pairs, gb_heap_allocator());
    defer(gb_array_free(pairs));

    //{"pairs":[{"x0":1.238742348,"y0":70.49584239,"x1":64.2323243,"y1":170.230982938},{...}]}
    //{"pairs":[{"x0":-59.1758448354,"y0":17.0335329177,"x1":28.1998407729,"y1":96.4763927354},
    char* reader = json_str;

    GB_ASSERT(*reader == '{');

    while (reader - json_str < 89) {

        switch (*reader) {
        case '{': {
            printf("lcurly");
            reader++;
        } break;
            
        case '}': {
            printf("rcurly");
            reader++;
        } break;

        case '[': {
            printf("lsquare_bracket");
            reader++;
        } break;
            
        case ']': {
            printf("rsquare_bracket");
            reader++;
        } break;
            
        case '"': {
            printf("quotation");
            reader++;
        } break;

        case ':': {
            printf("colon");
            reader++;
        } break;

        case ',': {
            printf("comma");
            reader++;
        } break;

        default:
            printf("unknown");
            reader++;
        }
        
        printf("\n");
    }

    return 0;
}
