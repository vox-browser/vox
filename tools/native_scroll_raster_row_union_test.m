#import <Cocoa/Cocoa.h>
#include <assert.h>
#include "../native_scroll_raster_darwin.h"

static void compare_store(size_t width, size_t height, size_t origin, size_t padding,
    int damage_count, int scenario) {
    size_t pitch = width * 4 + padding, canvas_rows = height + 4;
    size_t raster_bytes = width * height * 4, bytes = pitch * canvas_rows;
    uint8_t *pixels = malloc(bytes), *scalar = malloc(raster_bytes), *merged = malloc(raster_bytes);
    uint8_t *defaults = malloc(raster_bytes);
    assert(pixels && scalar && merged && defaults);
    for (size_t index = 0; index < bytes; ++index) pixels[index] = (uint8_t)(index * 37 + index / pitch);
    memset(scalar, 0xa5, raster_bytes); memset(merged, 0xa5, raster_bytes);
    memset(defaults, 0xa5, raster_bytes);
    VoxScrollRaster cache = {0};
    cache.width = width; cache.height = height; cache.row_origin = origin; cache.top = 2;
    cache.dirty_first = scenario == 0 ? 0 : height / 2;
    cache.dirty_rows = scenario == 0 ? height : scenario == 1 ? 0 : height - cache.dirty_first;
    cache.damage_row_count = damage_count;
    for (int index = 0; index < damage_count; ++index) {
        size_t first = scenario == 3 ? (size_t)index % height : height / 3;
        size_t count = scenario == 3 ? 1 : height - first;
        cache.damage_rows[index][0] = first; cache.damage_rows[index][1] = count;
    }
    cache.pixels = defaults;
    unsetenv("VOX_ENABLE_SCROLL_RASTER_ROW_UNION");
    unsetenv("VOX_DISABLE_SCROLL_RASTER_ROW_UNION");
    native_scroll_raster_store_rows(&cache, pixels, pitch);
    cache.pixels = scalar;
    setenv("VOX_ENABLE_SCROLL_RASTER_ROW_UNION", "1", 1);
    setenv("VOX_DISABLE_SCROLL_RASTER_ROW_UNION", "1", 1);
    native_scroll_raster_store_rows(&cache, pixels, pitch);
    cache.pixels = merged;
    unsetenv("VOX_DISABLE_SCROLL_RASTER_ROW_UNION");
    native_scroll_raster_store_rows(&cache, pixels, pitch);
    assert(!memcmp(scalar, merged, raster_bytes));
    assert(!memcmp(scalar, defaults, raster_bytes));
    for (size_t y = 0; y < canvas_rows; ++y)
        for (size_t x = 0; x < pitch; ++x)
            assert(pixels[y * pitch + x] == (uint8_t)((y * pitch + x) * 37 + y));
    free(pixels); free(scalar); free(merged); free(defaults);
}

int main(void) {
    size_t cases = 0;
    for (size_t width = 1; width <= 19; width += 3)
        for (size_t height = 1; height <= 23; height += 2)
            for (size_t origin = 0; origin < height; ++origin)
                for (int padding = 0; padding <= 12; padding += 12)
                    for (int damage = 0; damage <= 48; ++damage)
                        for (int scenario = 0; scenario < 4; ++scenario) {
                            compare_store(width, height, origin, padding, damage, scenario);
                            ++cases;
                        }
    printf("Scroll raster row union: %zu exact default/scalar/union ring and padded-pitch cases passed\n", cases);
    return 0;
}
