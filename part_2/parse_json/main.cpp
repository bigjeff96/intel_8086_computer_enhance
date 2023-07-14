#include <math.h>
#include <string.h>
#define GB_IMPLEMENTATION
#include "../gb.h"

struct Pair {
    f64 x0, y0, x1, y1;
};

struct String_slice {
    char* start;
    size_t length;
};
// int n = 3;
// /* print at most first three characters (safe) */
// printf("(%.*s)\n", n, string);

enum Symbol_type {
    symbol_none,
    symbol_lcurly,
    symbol_rcurly,
    symbol_lsquare_bracket,
    symbol_rsquare_bracket,
    symbol_quotation_mark,
    symbol_identifier,
    symbol_colon,
    symbol_comma,
    symbol_number,
    symbol_boolean,
    symbol_string,
};

struct Symbol {
    Symbol_type type;
    union {
        struct {
            String_slice id;
        };
        struct {
            String_slice str;
        };
        struct {
            f64 number;
        };
        struct {
            bool boolean;
        };
    };
};

void print_symbol(Symbol sym)
{
    switch (sym.type) {
    case symbol_lcurly: {
        printf("lcurly\n");
    } break;
    case symbol_rcurly: {
        printf("rcurly\n");
    } break;
    case symbol_lsquare_bracket: {
        printf("lsquare_bracket\n");
    } break;
    case symbol_rsquare_bracket: {
        printf("rsquare_bracket\n");
    } break;
    case symbol_quotation_mark: {
        printf("quotation mark\n");
    } break;
    case symbol_colon: {
        printf("colon\n");
    } break;
    case symbol_comma: {
        printf("comma\n");
    } break;
    case symbol_identifier: {
        printf("id : %.*s\n", sym.id.length, sym.id.start);
    } break;
    case symbol_string: {
        printf("id : %.*s\n", sym.str.length, sym.str.start);
    } break;
    case symbol_number: {
        printf("number : %.14g\n", sym.number);
    } break;
    case symbol_boolean: {
        printf("bool : %s\n", (sym.boolean ? "true" : "false"));
    }
    case symbol_none: {
        GB_PANIC("error");
    } break;
    }
}

double parser_number(String_slice number_slice)
{

    int numbers[20] = {};
    int numbers_count = 0;
    bool is_positive = true;
    int digits_before_point = 0;
    f64 result = 0;

    for (int i = 0; i < number_slice.length; i++) {
        if (i == 0 && !gb_char_is_digit(*number_slice.start)) {
            if (*number_slice.start == '-')
                is_positive = false;
        }

        if (gb_char_is_digit(number_slice.start[i])) {
            numbers[numbers_count++] = gb_digit_to_int(number_slice.start[i]);
        } else {
            digits_before_point = numbers_count;
        }
    }

    for (int i = 0; i < digits_before_point; i++) {
        result += double(numbers[i]) * pow(10., double(digits_before_point - 1 - i));
    }

    for (int i = digits_before_point; i < numbers_count; i++) {
        result += double(numbers[i]) * pow(10., double(-1 - (i - digits_before_point)));
    }

    return result * (is_positive ? 1. : -1.);
}

gbArray(Pair) get_pairs_from_json(const char* json_file_path)
{

    gbFileContents json_file = gb_file_read_contents(gb_heap_allocator(), 1, json_file_path);
    defer(gb_file_free_contents(&json_file));

    gbArray(Symbol) symbols;
    gb_array_init(symbols, gb_heap_allocator());
    defer(gb_array_free(symbols));

    gbArray(Pair) pairs;
    gb_array_init(pairs, gb_heap_allocator());

    //{"pairs":[{"x0":-59.1758448354,"y0":17.0335329177,"x1":28.1998407729,"y1":96.4763927354},
    char* json_str = (char*)json_file.data;
    char* reader = (char*)json_file.data;

    GB_ASSERT(*reader == '{');

    while (reader - json_str < json_file.size) {
        Symbol current_symbol;

        switch (*reader) {
        case '{': {
            current_symbol.type = symbol_lcurly;
            gb_array_append(symbols, current_symbol);
            reader++;
        } break;

        case '}': {
            current_symbol.type = symbol_rcurly;
            gb_array_append(symbols, current_symbol);
            reader++;
        } break;

        case '[': {
            current_symbol.type = symbol_lsquare_bracket;
            gb_array_append(symbols, current_symbol);
            reader++;
        } break;

        case ']': {
            current_symbol.type = symbol_rsquare_bracket;
            gb_array_append(symbols, current_symbol);
            reader++;
        } break;

        case '"': {
            current_symbol.type = symbol_quotation_mark;
            gb_array_append(symbols, current_symbol);
            reader++;
        } break;

        case ':': {
            current_symbol.type = symbol_colon;
            gb_array_append(symbols, current_symbol);
            reader++;
        } break;

        case ',': {
            current_symbol.type = symbol_comma;
            gb_array_append(symbols, current_symbol);
            reader++;
        } break;

        default:
            if (gb_char_is_alpha(*reader)) {
                current_symbol = { .type = symbol_identifier };
                char* start_id = reader;

                while (*start_id != '"') {
                    start_id++;
                }

                current_symbol.id.start = reader;
                current_symbol.id.length = (size_t(start_id) - size_t(reader)) / sizeof(char);
                gb_array_append(symbols, current_symbol);
                reader = start_id;
            } else if (gb_char_is_digit(*reader) || *reader == '-' || *reader == '+') {
                char* start_id = reader;

                while (*start_id != ',' && *start_id != '}' && *start_id != ']') {
                    start_id++;
                }

                String_slice number_slice;
                number_slice.start = reader;
                number_slice.length = (size_t(start_id) - size_t(reader)) / sizeof(char);
                f64 number = parser_number(number_slice);
                current_symbol = { .type = symbol_number };
                current_symbol.number = number;
                gb_array_append(symbols, current_symbol);
                reader = start_id;
            } else
                GB_PANIC("NOPE\n");
        }
    }

    for (int i = 0; i < gb_array_count(symbols); i++) {
        Symbol sym = symbols[i];
        if (sym.type == symbol_identifier) {
            if (!strncmp(sym.id.start, "x0", 2)) {
                Pair pair;
                i += 3;
                GB_ASSERT(symbols[i].type == symbol_number);
                pair.x0 = symbols[i].number;
                i += 6;
                GB_ASSERT(symbols[i].type == symbol_number);
                pair.y0 = symbols[i].number;
                i += 6;
                GB_ASSERT(symbols[i].type == symbol_number);
                pair.x1 = symbols[i].number;
                i += 6;
                GB_ASSERT(symbols[i].type == symbol_number);
                pair.y1 = symbols[i].number;
                gb_array_append(pairs, pair);
            }
        }
    }
    return pairs;
}

int main() { gbArray(Pair) pairs = get_pairs_from_json("../pairs.json"); }
