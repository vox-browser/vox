#pragma once
#include <cstdlib>
#include <cstring>

inline bool vox_large_shape_regions_enabled()
{
    static bool const enabled = [] {
        auto* value = std::getenv("VOX_ENABLE_LARGE_SHAPE_REGIONS");
        return value && !std::strcmp(value, "1") && !std::getenv("VOX_DISABLE_LARGE_SHAPE_REGIONS");
    }();
    return enabled;
}
