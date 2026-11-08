#pragma once
#include <cmath>

// Skia's ordered gradient dither repeats every eight device pixels from the
// raster surface origin. A bounded leaf must retain its owning layer's phase.
inline int vox_chromium_dither_phase(double coordinate, double origin, double scale)
{
    long offset = std::lround((coordinate - origin) * scale);
    return static_cast<int>((offset % 8 + 8) % 8);
}
