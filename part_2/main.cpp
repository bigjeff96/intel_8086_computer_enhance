#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#define GB_IMPLEMENTATION
#include "gb.h"
#include <math.h>
#include "listings/listing_0065_haversine_formula.cpp"

f64 f64_range(f64 low, f64 high)
{
    f64 diff = high - low;
    return low + diff * drand48();
}

int main(int argc, char** argv)
{
    u64 buffer_size = gb_megabytes(155);
    char* buffer = (char*)malloc(buffer_size);
    gbArena arena = {};
    gb_arena_init_from_memory(&arena, buffer, buffer_size);
    gbAllocator aloc = gb_arena_allocator(&arena);

    size_t total_pairs = 2'000'000;
    srand48(time(NULL));
    gbString json_str = gb_string_make_reserve(aloc, buffer_size - 100);

    f64 earth_radius = 6372.8;
    f64 average_haversine_distance = 0.;
    json_str = gb_string_append_fmt(json_str, "{\"pairs\":[");

    for (size_t i = 0; i < total_pairs; i++) {
        //TODO: Implement the cluster method to improve the randomness in the results
        f64 x0 = f64_range(-90., 90.);
        f64 y0 = f64_range(-180., 180.);
        f64 x1 = f64_range(-90., 90.);
        f64 y1 = f64_range(-180., 180.);

        f64 distance = ReferenceHaversine(x0, y0, x1, y1, earth_radius);
        average_haversine_distance += distance;
        if (i == total_pairs - 1)
            json_str
                = gb_string_append_fmt(json_str, "{\"x0\":%.10g,\"y0\":%.10g,\"x1\":%.10g,\"y1\":%.10g}", x0, y0, x1, y1);
        else
            json_str
                = gb_string_append_fmt(json_str, "{\"x0\":%.10g,\"y0\":%.10g,\"x1\":%.10g,\"y1\":%.10g},", x0, y0, x1, y1);
    }
    json_str = gb_string_append_fmt(json_str, "]}");

    u64 str_size = gb_string_length(json_str);
    average_haversine_distance = average_haversine_distance / (f64(total_pairs));

    printf("average distance: %.10g\n", average_haversine_distance);
    printf("string size is %zu bytes\n", str_size);

    return 0;
}
