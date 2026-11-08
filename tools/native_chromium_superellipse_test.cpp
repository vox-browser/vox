#include "../native/include/native_chromium_superellipse.h"
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
    // Full control-point sequences from the independent Brave fixture cover
    // spread shadows and below-round inset alignment, including path ordering.
    struct AlignedGolden { SkRRect rect, origin; float parameter; std::vector<SkPoint> points; };
    AlignedGolden aligned[] {
        {SkRRect::MakeRectXY(SkRect::MakeXYWH(32,232,716,68),34,34),
         SkRRect::MakeRectXY(SkRect::MakeXYWH(40,240,700,52),26,26),1.1f,
         {{66.0f,232.0f},
          {714.0f,232.0f},
          {720.181213378906f,232.0f},
          {730.485778808594f,233.273513793945f},
          {738.606140136719f,241.393859863281f},
          {746.726501464844f,249.514205932617f},
          {748.0f,259.818786621094f},
          {748.0f,266.0f},
          {748.0f,272.181213378906f},
          {746.726501464844f,282.485778808594f},
          {738.606140136719f,290.606140136719f},
          {730.485778808594f,298.726501464844f},
          {720.181213378906f,300.0f},
          {714.0f,300.0f},
          {66.0f,300.0f},
          {59.818775177002f,300.0f},
          {49.5142097473145f,298.726501464844f},
          {41.3938598632813f,290.606140136719f},
          {33.2735137939453f,282.485778808594f},
          {32.0f,272.181213378906f},
          {32.0f,266.0f},
          {32.0f,259.818786621094f},
          {33.2735137939453f,249.514205932617f},
          {41.3938598632813f,241.393859863281f},
          {49.5142097473145f,233.273513793945f},
          {59.818775177002f,232.0f},
          {66.0f,232.0f}}},
        {SkRRect::MakeRectXY(SkRect::MakeXYWH(39,239,702,54),27,27),
         SkRRect::MakeRectXY(SkRect::MakeXYWH(40,240,700,52),26,26),1.1f,
         {{66.0f,239.0f},
          {714.0f,239.0f},
          {718.908630371094f,239.0f},
          {727.091674804688f,240.011322021484f},
          {733.540161132813f,246.459838867188f},
          {739.988708496094f,252.908340454102f},
          {741.0f,261.091369628906f},
          {741.0f,266.0f},
          {741.0f,270.908630371094f},
          {739.988708496094f,279.091644287109f},
          {733.540161132813f,285.540161132813f},
          {727.091674804688f,291.988677978516f},
          {718.908630371094f,293.0f},
          {714.0f,293.0f},
          {66.0f,293.0f},
          {61.0913772583008f,293.0f},
          {52.9083442687988f,291.988677978516f},
          {46.459831237793f,285.540161132813f},
          {40.0113220214844f,279.091644287109f},
          {39.0f,270.908630371094f},
          {39.0f,266.0f},
          {39.0f,261.091369628906f},
          {40.0113220214844f,252.908340454102f},
          {46.459831237793f,246.459838867188f},
          {52.9083442687988f,240.011322021484f},
          {61.0913772583008f,239.0f},
          {66.0f,239.0f}}},
        {SkRRect::MakeRectXY(SkRect::MakeXYWH(41,441,698,50),27,19),
         SkRRect::MakeRectXY(SkRect::MakeXYWH(40,440,700,52),28,20),0.98f,
         {{67.9636383056641f,441.0f},
          {63.8150939941406f,441.005981445313f},
          {55.734375f,441.893768310547f},
          {49.0019683837891f,446.633239746094f},
          {42.2754859924316f,451.368530273438f},
          {41.0106887817383f,457.051361083984f},
          {41.0f,459.974151611328f},
          {41.0f,472.025848388672f},
          {41.0106887817383f,474.948638916016f},
          {42.2754859924316f,480.631469726563f},
          {49.0019683837891f,485.366760253906f},
          {55.734375f,490.106231689453f},
          {63.8150939941406f,490.994018554688f},
          {67.9636383056641f,491.0f},
          {712.036376953125f,491.0f},
          {716.184936523438f,490.994018554688f},
          {724.265625f,490.106231689453f},
          {730.998046875f,485.366760253906f},
          {737.726135253906f,480.630310058594f},
          {738.989929199219f,474.945861816406f},
          {739.0f,472.023712158203f},
          {739.0f,459.976287841797f},
          {738.989929199219f,457.054138183594f},
          {737.726135253906f,451.369689941406f},
          {730.998046875f,446.633239746094f},
          {724.265625f,441.893768310547f},
          {716.184936523438f,441.005981445313f},
          {712.036376953125f,441.0f},
          {67.9636383056641f,441.0f}}},
    };
    for (auto const& item : aligned) {
        auto k=item.parameter;
        auto path=vox_chromium_superellipse_path(item.rect,{k,k,k,k},&item.origin);
        std::vector<SkPoint> actual(path.countPoints());
        path.getPoints({actual.data(),actual.size()});
        assert(actual.size()==item.points.size());
        for(size_t i=0;i<actual.size();++i) {
            if(actual[i]!=item.points[i])std::fprintf(stderr,"aligned point %zu expected %.9g,%.9g actual %.9g,%.9g\n",
                i,item.points[i].x(),item.points[i].y(),actual[i].x(),actual[i].y());
            assert(actual[i]==item.points[i]);
        }
        ++checks;
    }
    std::printf("Chromium superellipse geometry: %d checks passed\n", checks);
}
