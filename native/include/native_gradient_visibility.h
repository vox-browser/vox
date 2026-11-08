#pragma once

#include <cmath>

// Native gradient stops are straight RGBA plus an offset, five floats per
// stop. A zero-alpha CSS source-over draw cannot change its destination.
// Invalid or merely small alpha values must keep the ordinary renderer.
inline bool vox_gradient_stops_are_transparent(float const* stops, int count)
{
    if (!stops || count <= 0 || count > 65536) return false;
    for (int index = 0; index < count; ++index) {
        auto const* stop = stops + index * 5;
        if (stop[3] != 0) return false;
        for (int channel = 0; channel < 5; ++channel)
            if (!std::isfinite(stop[channel])) return false;
    }
    return true;
}
