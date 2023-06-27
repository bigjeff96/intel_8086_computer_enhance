#include <cstddef>
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

struct Pair {
    f64 x,y;
};

Pair random_pair(f64 distance_from_border) {
    f64 x = f64_range(-90. + distance_from_border, 90. - distance_from_border);
    f64 y = f64_range(-180. + distance_from_border, 180. - distance_from_border);
    return Pair{.x = x, .y = y};
}

Pair make_pair_in_domain(Pair p) {
    Pair r;
    if (fabs(p.x) > 90.) {
        f64 sign = p.x >= 0. ? 1. : -1.;
        r.x =  sign * (90. - fmod(fabs(p.x), 90.));
    } else
        r.x = p.x;

    if (fabs(p.y) > 180.) {
        f64 sign = p.y >= 0. ? 1. : -1.;
        r.y = - sign * (180. - fmod(fabs(p.y), 180.));
    } else
        r.y = p.y;

    return r;
}


int main(int argc, char** argv)
{
    u64 buffer_size = gb_megabytes(1000);
    char* buffer = (char*)malloc(buffer_size);
    defer(free(buffer));
    gbArena arena = {};
    gb_arena_init_from_memory(&arena, buffer, buffer_size);
    gbAllocator aloc = gb_arena_allocator(&arena);

    size_t total_pairs = 1'000'000;
    srand48(time(NULL));
    gbString json_str = gb_string_make_reserve(aloc, buffer_size/2 - 100);

    f64 earth_radius = 6372.8;
    f64 average_haversine_distance = 0.;
    json_str = gb_string_append_fmt(json_str, "{\"pairs\":[");

    //Making 16 random points (so dividing total_pairs by 16), and for each point
    // making the points center around each point
    Pair centers[16] = {};
    f64 max_distance_from_center = 50.;
    gbArray(f64) distances;
    gb_array_init(distances, aloc);

    for (int i = 0; i < 16; i++) {
        centers[i] = random_pair(0.);
    }
    
    for (size_t i = 0; i < total_pairs; i++) {

        int index_c1 = rand() % 16;
        int index_c2 = rand() % 16;
        f64 x1 = centers[index_c1].x + f64_range(-max_distance_from_center, max_distance_from_center);
        f64 y1 = centers[index_c1].y + f64_range(-max_distance_from_center, max_distance_from_center);
        f64 x2 = centers[index_c2].x + f64_range(-max_distance_from_center, max_distance_from_center);
        f64 y2 = centers[index_c2].y + f64_range(-max_distance_from_center, max_distance_from_center);

        Pair p1 = {.x = x1, .y = y1};
        Pair p2 = {.x = x2, .y = y2};
        p1 = make_pair_in_domain(p1);
        p2 = make_pair_in_domain(p2);
            
        f64 distance = ReferenceHaversine(p1.x, p1.y, p2.x, p2.y, earth_radius);
        gb_array_append(distances, distance);
        average_haversine_distance += distance;
            
        if (i == total_pairs - 1) {
            json_str
                = gb_string_append_fmt(json_str, "{\"x0\":%.10g,\"y0\":%.10g,\"x1\":%.10g,\"y1\":%.10g}", x1, y1, x2, y2);
        } else {
            json_str
                = gb_string_append_fmt(json_str, "{\"x0\":%.10g,\"y0\":%.10g,\"x1\":%.10g,\"y1\":%.10g},", x1, y1, x2, y2);
        }
    }
    json_str = gb_string_append_fmt(json_str, "]}");

    u64 str_size = gb_string_length(json_str);
    average_haversine_distance = average_haversine_distance / (f64(total_pairs));

    printf("average distance: %.10g\n", average_haversine_distance);
    printf("string size is %zu bytes\n", str_size);

    FILE* json_file = fopen("pairs.json", "wb");
    GB_ASSERT(json_file);
    fwrite(json_str, 1, gb_string_length(json_str), json_file);
    defer(fclose(json_file));
    
    FILE* distance_file = fopen("distance.bin", "wb");
    GB_ASSERT(distance_file);
    fwrite(distances, sizeof(f64), gb_array_count(distances), distance_file);
    defer(fclose(distance_file));
    printf("all good\n");

    return 0;
}
