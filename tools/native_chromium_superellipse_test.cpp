#include "../native_chromium_superellipse.h"
#include <cassert>
#include <cstdio>
#include <limits>
#include <vector>

int main()
{
    // Golden float coordinates come from normal-window Brave's captured
    // composer picture, including its border and inset shadow cutout.
    struct Golden { float x, y, width, height, radius; SkPoint a, b, midpoint; };
    Golden cases[] {
        {12, 72, 740, 52, 26, {730.726806640625f, 72},
            {738.606750488281f, 72.9738616943359f}, {744.816467285156f, 79.1835403442383f}},
        {13, 73, 738, 50, 25, {730.545043945313f, 73},
            {738.121887207031f, 73.936408996582f}, {744.0927734375f, 79.9072494506836f}},
        {4, 64, 756, 68, 34, {732.181213378906f, 64},
            {742.485778808594f, 65.2735137939453f}, {750.606140136719f, 73.3938598632813f}},
    };
    int checks = 0;
    for (auto const& item : cases) {
        auto rect = SkRRect::MakeRectXY(SkRect::MakeXYWH(item.x,item.y,item.width,item.height),item.radius,item.radius);
        auto path = vox_chromium_superellipse_path(rect, {1.1f,1.1f,1.1f,1.1f});
        std::vector<SkPoint> points(path.countPoints());
        path.getPoints({points.data(), points.size()});
        // Move, duplicate line, then two cubic control points and endpoint.
        for (auto pair : {std::pair{points[2],item.a},std::pair{points[3],item.b},std::pair{points[4],item.midpoint}}) {
            if (pair.first != pair.second) std::fprintf(stderr,"expected %.9g,%.9g actual %.9g,%.9g\n",
                pair.second.x(),pair.second.y(),pair.first.x(),pair.first.y());
            assert(pair.first == pair.second);
            ++checks;
        }
        assert(path.getBounds() == rect.rect()); ++checks;
    }
    auto rect = SkRRect::MakeRectXY(SkRect::MakeXYWH(10,20,100,40),12,8);
    for (float power : {-1.f, 0.f, .98f, 1.f, 1.1f, 1.25f, 2.f, 10.f}) {
        auto path = vox_chromium_superellipse_path(rect, {power,power,power,power});
        assert(path.isFinite() && !path.isEmpty()); ++checks;
    }
    for (float power : {std::numeric_limits<float>::infinity(),
            -std::numeric_limits<float>::infinity(), std::numeric_limits<float>::quiet_NaN()}) {
        auto path = vox_chromium_superellipse_path(rect, {power,power,power,power});
        assert(path.isFinite() && !path.isEmpty()); ++checks;
    }
    auto mixed = vox_chromium_superellipse_path(rect, {.98f,1.1f,1.25f,2});
    assert(mixed.isFinite() && !mixed.isEmpty() && mixed.contains(60,40)); ++checks;
    std::printf("Chromium superellipse geometry: %d checks passed\n", checks);
}
