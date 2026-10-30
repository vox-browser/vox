#ifndef VOX_NATIVE_SKIA_IMAGE_COLOR_SPACE_H
#define VOX_NATIVE_SKIA_IMAGE_COLOR_SPACE_H

#include "native_image_color_profile.h"
#include "include/core/SkColorSpace.h"
#include "modules/skcms/skcms.h"
#include <algorithm>

static bool vox_store_image_color_space(SkColorSpace* space, float* values)
{
    skcms_TransferFunction transfer;
    skcms_Matrix3x3 gamut;
    if (!space || !space->isNumericalTransferFn(&transfer) || !space->toXYZD50(&gamut))
        return false;
    values[0] = -1;
    std::copy_n(&transfer.g, 7, values + 1);
    std::copy_n(&gamut.vals[0][0], 9, values + 8);
    return true;
}

static sk_sp<SkColorSpace> vox_image_color_space_from_profile(float const* values)
{
    if (!values) return SkColorSpace::MakeSRGB();
    skcms_TransferFunction transfer { values[0], 1, 0, 0, 0, 0, 0 };
    skcms_Matrix3x3 gamut = SkNamedGamut::kSRGB;
    if (values[0] == -1) {
        std::copy_n(values + 1, 7, &transfer.g);
        std::copy_n(values + 8, 9, &gamut.vals[0][0]);
    } else if (values[1] != 0 && !skcms_PrimariesToXYZD50(values[2], values[3], values[4],
            values[5], values[6], values[7], values[8], values[9], &gamut)) {
        return SkColorSpace::MakeSRGB();
    }
    auto space = SkColorSpace::MakeRGB(transfer, gamut);
    return space ? space : SkColorSpace::MakeSRGB();
}

#endif
