#pragma once

#include "include/core/SkPathBuilder.h"
#include "include/core/SkRRect.h"
#include <algorithm>
#include <array>
#include <cmath>

// The fitted half-corner coefficients follow Chromium's BSD-licensed geometry:
// https://chromium.googlesource.com/chromium/src/+/56f91169afcf3eb958b6aa2db9b213b63ed00ce0/third_party/blink/renderer/platform/geometry/path_builder.cc
// CSS superellipse(k) uses curvature 2^k, with k=1 retaining an exact conic.
inline SkPath vox_chromium_superellipse_path(SkRRect const& rect,
    std::array<float, 4> const& parameters)
{
    auto bounds = rect.rect();
    SkPathBuilder path;
    auto corner = [&](int index) {
        auto radius = rect.radii(static_cast<SkRRect::Corner>(index));
        float sx = index == 0 || index == 3 ? -1 : 1;
        float sy = index < 2 ? -1 : 1;
        SkPoint outside {sx < 0 ? bounds.left() : bounds.right(),
            sy < 0 ? bounds.top() : bounds.bottom()};
        SkPoint center {outside.x() - sx * radius.x(), outside.y() - sy * radius.y()};
        SkPoint start = index == 0 || index == 2
            ? SkPoint{outside.x(), center.y()} : SkPoint{center.x(), outside.y()};
        SkPoint end = index == 0 || index == 2
            ? SkPoint{center.x(), outside.y()} : SkPoint{outside.x(), center.y()};
        if (index == 1) path.moveTo(start);
        path.lineTo(start);
        float curvature = std::isnan(parameters[index]) ? 2.f : std::exp2(parameters[index]);
        if (curvature < 1) {
            std::swap(center, outside);
            curvature = 1 / std::max(curvature, .001f);
        }
        if (radius.x() <= 0 || radius.y() <= 0 || curvature >= 1000) {
            path.lineTo(outside).lineTo(end);
        } else if (curvature == 1) {
            path.lineTo(end);
        } else if (curvature == 2) {
            path.conicTo(outside, end, std::sqrt(.5f));
        } else {
            constexpr double fit[] {1.2430920942724248, 2.010479023614843,
                .32922901179443753, .2823023142212073, 1.3473704261055421,
                2.9149468637949814, .9106507102917086};
            float power = std::log2(curvature);
            float slope = fit[0] + (fit[6] - fit[0]) * .5
                * (1 + std::tanh(fit[5] * (power - fit[1])));
            float base = 1 / (1 + std::exp(-slope * (0 - fit[1])));
            float logistic = 1 / (1 + std::exp(-slope * (power - fit[1])));
            float tangent = (logistic - base) / (1 - base);
            float offset = fit[2] * std::exp(-fit[3] * std::pow(power, fit[4]));
            float middle = std::pow(.5, 1 / curvature);
            SkVector first = outside - start, second = start - center;
            auto map = [&](float u, float v) {
                return center + SkVector{first.x() * u, first.y() * u}
                    + SkVector{second.x() * v, second.y() * v};
            };
            path.cubicTo(map(tangent, 1), map(middle - offset, middle + offset),
                map(middle, middle));
            path.cubicTo(map(middle + offset, middle - offset), map(1, tangent), end);
        }
    };
    for (int index : {1, 2, 3, 0}) corner(index);
    path.close();
    return path.detach();
}
