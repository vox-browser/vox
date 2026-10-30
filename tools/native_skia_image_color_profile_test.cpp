#include "../native_skia_text_darwin.cpp"
#include "include/encode/SkICC.h"
#include <array>
#include <cassert>
#include <cstdio>
static uint32_t read_u32(const uint8_t* p) { return uint32_t(p[0])<<24|uint32_t(p[1])<<16|uint32_t(p[2])<<8|p[3]; }
static void put_u32(uint8_t* p,uint32_t v) { for(int i=3;i>=0;--i){p[i]=v;v>>=8;} }
int main() {
    auto icc=SkWriteICCProfile(SkNamedTransferFn::kSRGB,SkNamedGamut::kDisplayP3);
    assert(icc);
    std::array<uint8_t,16> source{240,40,40,255,40,210,70,128,30,70,230,64,140,100,200,224};
    auto original=source;
    std::array<uint8_t,16> pixels{};
    VoxImageColorProfile profile{};
    assert(ladybird_v_skia_convert_icc_rgba(icc->data(),icc->size(),source.data(),2,2,pixels.data(),profile.values));
    assert(source==original);
    std::array<uint8_t,16> premul{240,40,40,255,20,105,35,128,8,18,58,64,123,88,176,224};
    assert(pixels==premul && profile.values[0]==-1);
    skcms_ICCProfile source_profile{};assert(skcms_Parse(icc->data(),icc->size(),&source_profile));
    auto expected=SkColorSpace::Make(source_profile);
    assert(SkColorSpace::Equals(expected.get(),vox_image_color_space_from_profile(profile.values).get()));
    ladybird_v_skia_set_image_color_profile(profile.values);
    assert(SkColorSpace::Equals(expected.get(),image_color_space().get()));
    ladybird_v_skia_set_image_color_profile(nullptr);
    assert(image_color_space()->isSRGB());
    assert(!ladybird_v_skia_convert_icc_rgba(nullptr,0,source.data(),2,2,pixels.data(),profile.values));
    assert(!ladybird_v_skia_convert_icc_rgba(icc->data(),icc->size(),source.data(),0,2,pixels.data(),profile.values));

    // Different channel curves cannot be represented by one SkColorSpace
    // transfer function. Preserve the existing original-profile fallback.
    auto* bytes=static_cast<const uint8_t*>(icc->data());
    std::vector<uint8_t> separate(bytes,bytes+icc->size());
    uint32_t count=read_u32(bytes+128);bool changed=false;
    for(uint32_t i=0;i<count;++i){size_t tag=132+i*12;if(std::memcmp(bytes+tag,"rTRC",4))continue;
        uint32_t offset=read_u32(bytes+tag+4),size=read_u32(bytes+tag+8);
        assert(size>=16&&!std::memcmp(bytes+offset,"para",4));
        size_t next=(separate.size()+3)&~size_t(3);separate.resize(next);
        separate.insert(separate.end(),bytes+offset,bytes+offset+size);
        put_u32(separate.data()+next+12,65536);put_u32(separate.data()+tag+4,next);
        put_u32(separate.data(),separate.size());changed=true;break;
    }
    assert(changed);
    skcms_ICCProfile parsed{};assert(skcms_Parse(separate.data(),separate.size(),&parsed));
    assert(!SkColorSpace::Make(parsed));
    assert(ladybird_v_skia_convert_icc_rgba(separate.data(),separate.size(),source.data(),2,2,pixels.data(),profile.values));
    assert(profile.values[0]==0 && source==original && pixels!=premul);
    for(size_t i=3;i<pixels.size();i+=4)assert(pixels[i]==source[i]);
    VoxImageColorProfile legacy{};legacy.values[0]=1.8f;
    skcms_TransferFunction transfer;auto gamma=vox_image_color_space_from_profile(legacy.values);
    assert(gamma&&gamma->isNumericalTransferFn(&transfer)&&transfer.g==1.8f);
    std::puts("PASS: ICC source pixels, numerical color-space transport and original-curve fallback");
}
