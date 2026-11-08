#include "../native/include/native_jpegxl.h"
#include <jxl/encode.h>
#include <cassert>
#include <cstdio>
#include <fstream>
#include <string>
#include <vector>

static std::vector<uint8_t> encode(std::vector<uint8_t> const& pixels,
    int channels, int orientation=1, bool container=false, bool wide=false, bool animated=false)
{
    auto* encoder=JxlEncoderCreate(nullptr);
    assert(encoder);
    JxlBasicInfo info;
    JxlEncoderInitBasicInfo(&info);
    info.xsize=3;info.ysize=2;info.bits_per_sample=8;
    info.num_color_channels=channels==1?1:3;
    info.num_extra_channels=channels==4?1:0;
    info.alpha_bits=channels==4?8:0;
    info.uses_original_profile=JXL_TRUE;
    info.orientation=JxlOrientation(orientation);
    info.have_animation=animated;
    if(animated){info.animation.tps_numerator=1;info.animation.tps_denominator=1;}
    assert(JxlEncoderSetBasicInfo(encoder,&info)==JXL_ENC_SUCCESS);
    JxlColorEncoding color;
    JxlColorEncodingSetToSRGB(&color,channels==1);
    if(wide)color.primaries=JXL_PRIMARIES_P3;
    assert(JxlEncoderSetColorEncoding(encoder,&color)==JXL_ENC_SUCCESS);
    assert(JxlEncoderUseContainer(encoder,container)==JXL_ENC_SUCCESS);
    auto* frame=JxlEncoderFrameSettingsCreate(encoder,nullptr);
    assert(JxlEncoderSetFrameLossless(frame,JXL_TRUE)==JXL_ENC_SUCCESS);
    assert(JxlEncoderFrameSettingsSetOption(frame,JXL_ENC_FRAME_SETTING_KEEP_INVISIBLE,1)==JXL_ENC_SUCCESS);
    if(animated){
        JxlFrameHeader header;JxlEncoderInitFrameHeader(&header);header.duration=1;
        assert(JxlEncoderSetFrameHeader(frame,&header)==JXL_ENC_SUCCESS);
    }
    JxlPixelFormat format{uint32_t(channels),JXL_TYPE_UINT8,JXL_NATIVE_ENDIAN,0};
    assert(JxlEncoderAddImageFrame(frame,&format,pixels.data(),pixels.size())==JXL_ENC_SUCCESS);
    JxlEncoderCloseInput(encoder);
    std::vector<uint8_t> output(1024);
    uint8_t* next=output.data();size_t available=output.size();
    JxlEncoderStatus status;
    while((status=JxlEncoderProcessOutput(encoder,&next,&available))==JXL_ENC_NEED_MORE_OUTPUT){
        size_t used=next-output.data();output.resize(output.size()*2);
        next=output.data()+used;available=output.size()-used;
    }
    assert(status==JXL_ENC_SUCCESS);
    output.resize(next-output.data());
    JxlEncoderDestroy(encoder);
    return output;
}

static void check(std::vector<uint8_t> const& bytes,int width,int height,
    std::vector<uint8_t> const& expected)
{
    int32_t w=-1,h=-1,p=-1;
    auto* pixels=vox_jpegxl_decode_rgba(bytes.data(),bytes.size(),&w,&h,&p);
    assert(pixels&&w==width&&h==height&&p==width*4);
    assert(expected==std::vector<uint8_t>(pixels,pixels+size_t(p)*h));
    vox_jpegxl_free(pixels, uint64_t(p) * h);
}

static void rejected(std::vector<uint8_t> const& bytes)
{
    int32_t w=-1,h=-1,p=-1;
    assert(!vox_jpegxl_decode_rgba(bytes.data(),bytes.size(),&w,&h,&p));
    assert(w==0&&h==0&&p==0);
}

int main(int argc,char** argv)
{
    assert(vox_jpegxl_available());
    std::vector<uint8_t> rgba{255,0,0,255,0,255,0,128,0,0,255,0,
        20,80,160,128,250,200,100,255,255,255,255,255};
    auto raw=encode(rgba,4),container=encode(rgba,4,1,true),rotated=encode(rgba,4,6);
    check(raw,3,2,rgba);check(container,3,2,rgba);
    std::vector<uint8_t> orientation;
    for(int index:{3,0,4,1,5,2})orientation.insert(orientation.end(),rgba.begin()+index*4,rgba.begin()+index*4+4);
    check(rotated,2,3,orientation);
    auto gray=encode({0,17,64,128,200,255},1);
    std::vector<uint8_t> gray_rgba;
    for(uint8_t value:{0,17,64,128,200,255})gray_rgba.insert(gray_rgba.end(),{value,value,value,255});
    check(gray,3,2,gray_rgba);
    int32_t pw=0,ph=0,pp=0;
    auto* paint=vox_jpegxl_decode_paint_rgba(raw.data(),raw.size(),&pw,&ph,&pp);
    assert(paint&&pw==3&&ph==2&&pp==12);
    assert((std::vector<uint8_t>(paint,paint+24)==std::vector<uint8_t>{255,0,0,255,
        0,128,0,128,0,0,0,0,10,40,81,128,250,200,100,255,255,255,255,255}));
    vox_jpegxl_free(paint,24);
    auto wide=encode(rgba,4,1,false,true),animated=encode(rgba,4,1,false,false,true);
    rejected(wide);rejected(animated);rejected({});rejected({0xff,0x0a});rejected({1,2,3,4});
    for(size_t size:{size_t(1),size_t(5),raw.size()/2})rejected({raw.begin(),raw.begin()+size});
    if(argc==2){
        for(auto const& item:std::vector<std::pair<std::string,std::vector<uint8_t>>>{
            {"rgba.jxl",raw},{"rgba-container.jxl",container},{"orientation-6.jxl",rotated},
            {"gray.jxl",gray},{"wide-gamut.jxl",wide},{"animated.jxl",animated}}){
            std::ofstream file(std::string(argv[1])+"/"+item.first,std::ios::binary);
            file.write(reinterpret_cast<char const*>(item.second.data()),item.second.size());assert(file.good());
        }
    }
    std::puts("JPEG XL: exact RGBA, container, orientation, grayscale, rejection checks passed");
}
