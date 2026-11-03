#include "../native_webp_color_profile.h"
#include "include/core/SkData.h"
#include "include/encode/SkICC.h"
#include <array>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iterator>
#include <vector>

static uint32_t u32(uint8_t const* p) { return uint32_t(p[0])<<24|uint32_t(p[1])<<16|uint32_t(p[2])<<8|p[3]; }
static void put32(uint8_t* p,uint32_t v) { for(int i=3;i>=0;--i){p[i]=v;v>>=8;} }
int main(int argc, char** argv)
{
    std::array<uint8_t,8> original{254,128,1,128,140,100,200,224};
    auto srgb=SkWriteICCProfile(SkNamedTransferFn::kSRGB,SkNamedGamut::kSRGB);
    auto p3=SkWriteICCProfile(SkNamedTransferFn::kSRGB,SkNamedGamut::kDisplayP3);
    assert(srgb && p3);
    float profile[VOX_IMAGE_COLOR_PROFILE_VALUES];
    auto pixels=original;
    assert(vox_prepare_webp_icc_rgba(pixels.data(),2,(uint8_t const*)srgb->data(),srgb->size(),profile));
    std::array<uint8_t,8> truncated{127,64,0,128,122,87,175,224};
    assert(pixels==truncated && profile[0]==0);
    pixels=original;
    assert(vox_prepare_webp_icc_rgba(pixels.data(),2,(uint8_t const*)p3->data(),p3->size(),profile));
    assert(pixels==truncated && profile[0]==-1);
    skcms_ICCProfile parsed;assert(skcms_Parse(p3->data(),p3->size(),&parsed));
    assert(SkColorSpace::Equals(vox_image_color_space_from_profile(profile).get(),
        SkColorSpace::Make(parsed).get()));

    // Distinct channel curves require the original decode-time transform.
    auto* bytes=(uint8_t const*)p3->data();
    std::vector<uint8_t> separate(bytes,bytes+p3->size());
    bool changed=false;
    for(uint32_t i=0;i<u32(bytes+128);++i) {
        size_t tag=132+i*12;if(std::memcmp(bytes+tag,"rTRC",4))continue;
        uint32_t offset=u32(bytes+tag+4),size=u32(bytes+tag+8);
        size_t next=(separate.size()+3)&~size_t(3);separate.resize(next);
        separate.insert(separate.end(),bytes+offset,bytes+offset+size);
        put32(separate.data()+next+12,65536);put32(separate.data()+tag+4,next);
        put32(separate.data(),separate.size());changed=true;break;
    }
    assert(changed);
    assert(skcms_Parse(separate.data(),separate.size(),&parsed));
    assert(!SkColorSpace::Make(parsed));
    auto expected=original;pixels=original;
    assert(skcms_Transform(expected.data(),skcms_PixelFormat_RGBA_8888,skcms_AlphaFormat_Unpremul,
        &parsed,expected.data(),skcms_PixelFormat_RGBA_8888,skcms_AlphaFormat_PremulAsEncoded,skcms_sRGB_profile(),2));
    assert(vox_prepare_webp_icc_rgba(pixels.data(),2,separate.data(),separate.size(),profile));
    assert(pixels==expected && pixels!=truncated && profile[0]==0);
    pixels=original;profile[0]=-1;
    assert(!vox_prepare_webp_icc_rgba(pixels.data(),2,nullptr,0,profile));
    assert(pixels==original && profile[0]==0);
    assert(!vox_prepare_webp_icc_rgba(nullptr,2,bytes,p3->size(),profile));
    assert(!vox_prepare_webp_icc_rgba(pixels.data(),0,bytes,p3->size(),profile));
    assert(!vox_prepare_webp_icc_rgba(pixels.data(),2,bytes,p3->size(),nullptr));

    // Original publisher profile: equal sampled curves remain tagged rather
    // than being quantized through the CPU's different color transform.
    assert(argc==2);std::ifstream file(argv[1],std::ios::binary);
    std::vector<uint8_t> webp{std::istreambuf_iterator<char>(file),{}};
    bool found=false;
    for(size_t offset=12;offset+8<=webp.size();) {
        auto* chunk=webp.data()+offset;
        uint32_t size=uint32_t(chunk[4])|uint32_t(chunk[5])<<8|uint32_t(chunk[6])<<16|uint32_t(chunk[7])<<24;
        assert(size<=webp.size()-offset-8);
        if(!std::memcmp(chunk,"ICCP",4)) {
            assert(skcms_Parse(chunk+8,size,&parsed));assert(parsed.trc[0].table_entries==1024);
            pixels=original;
            assert(vox_prepare_webp_icc_rgba(pixels.data(),2,chunk+8,size,profile));
            assert(profile[0]==-1 && pixels==truncated);found=true;break;
        }
        offset+=8+size+(size&1);
    }
    assert(found);
    puts("PASS: WebP numerical ICC transport, truncating premultiplication, original-curve fallback and invalid inputs");
}
