#pragma once

// Premultiplied sRGB texture sampling belongs to composition, after tile
// rasterization. This CPU adapter keeps the existing bitmap publication ABI;
// it does not claim that textures remain resident on the GPU.
static void retained_layer_lerp_rows(uint8_t* output, uint8_t const* above,
    uint8_t const* below, size_t bytes, float fraction)
{
    size_t offset = 0;
#if defined(__aarch64__)
    auto mix = [fraction](uint16x4_t a, uint16x4_t b) {
        auto af = vcvtq_f32_u32(vmovl_u16(a));
        auto bf = vcvtq_f32_u32(vmovl_u16(b));
        return vmovn_u32(vcvtnq_u32_f32(vaddq_f32(
            vmulq_n_f32(af, 1 - fraction), vmulq_n_f32(bf, fraction))));
    };
    for (; offset + 16 <= bytes; offset += 16) {
        auto a = vld1q_u8(above + offset), b = vld1q_u8(below + offset);
        auto al = vmovl_u8(vget_low_u8(a)), ah = vmovl_u8(vget_high_u8(a));
        auto bl = vmovl_u8(vget_low_u8(b)), bh = vmovl_u8(vget_high_u8(b));
        auto low = vcombine_u16(mix(vget_low_u16(al), vget_low_u16(bl)),
            mix(vget_high_u16(al), vget_high_u16(bl)));
        auto high = vcombine_u16(mix(vget_low_u16(ah), vget_low_u16(bh)),
            mix(vget_high_u16(ah), vget_high_u16(bh)));
        vst1q_u8(output + offset, vcombine_u8(vmovn_u16(low), vmovn_u16(high)));
    }
#endif
    for (; offset < bytes; ++offset)
        output[offset] = uint8_t(std::nearbyint(above[offset] * (1 - fraction) + below[offset] * fraction));
}
