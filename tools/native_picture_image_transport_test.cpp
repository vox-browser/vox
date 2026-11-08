#include "../native/include/native_picture_image_transport.h"
#include <array>
#include <cassert>
#include <cstdio>
#include <limits>
#include <vector>

int main()
{
    std::array<uint8_t,16> pixels {240,40,40,255,20,105,35,128,8,18,58,64,123,88,176,224};
    skcms_TransferFunction gamma {1.8f,1,0,0,0,0,0};
    std::array<sk_sp<SkColorSpace>,5> spaces {nullptr, SkColorSpace::MakeSRGB(),
        SkColorSpace::MakeSRGBLinear(),
        SkColorSpace::MakeRGB(SkNamedTransferFn::kSRGB,SkNamedGamut::kDisplayP3),
        SkColorSpace::MakeRGB(gamma,SkNamedGamut::kSRGB)};
    for (size_t index=0;index<spaces.size();++index) {
        auto info=SkImageInfo::Make(2,2,kRGBA_8888_SkColorType,kPremul_SkAlphaType,spaces[index]);
        auto image=SkImages::RasterFromPixmapCopy(SkPixmap(info,pixels.data(),8));
        assert(image);
        auto data=vox_encode_picture_image(image.get());
        assert(data);
        bool tagged=index>=2;
        assert(data->size()==pixels.size()+(tagged?80:8));
        int32_t words[3];std::memcpy(words,data->data(),tagged?12:8);
        assert(words[0]==(tagged?-1:2) && words[1]==2);
        if(tagged)assert(words[2]==2);
        assert(!std::memcmp(static_cast<uint8_t const*>(data->data())+(tagged?80:8),pixels.data(),pixels.size()));
        auto decoded=vox_decode_picture_image(data->data(),data->size());
        assert(decoded && decoded->width()==2 && decoded->height()==2);
        auto expected=spaces[index]?spaces[index]:SkColorSpace::MakeSRGB();
        assert(SkColorSpace::Equals(expected.get(),decoded->colorSpace()));
        std::array<uint8_t,16> copy {};
        assert(decoded->readPixels(nullptr,info.makeColorSpace(expected),copy.data(),8,0,0));
        assert(copy==pixels);
        for(size_t length=0;length<data->size();++length)
            assert(!vox_decode_picture_image(data->data(),length));
        std::vector<uint8_t> trailing(static_cast<uint8_t const*>(data->data()),
            static_cast<uint8_t const*>(data->data())+data->size());
        trailing.push_back(0);
        assert(!vox_decode_picture_image(trailing.data(),trailing.size()));
        if(tagged) {
            for(float invalid : {std::numeric_limits<float>::quiet_NaN(),
                    std::numeric_limits<float>::infinity()}) {
                auto bad=SkData::MakeWithCopy(data->data(),data->size());
                std::memcpy(static_cast<uint8_t*>(bad->writable_data())+12+4, &invalid,4);
                assert(!vox_decode_picture_image(bad->data(),bad->size()));
            }
            auto bad=SkData::MakeWithCopy(data->data(),data->size());
            float wrong_marker=1;
            std::memcpy(static_cast<uint8_t*>(bad->writable_data())+12,&wrong_marker,4);
            assert(!vox_decode_picture_image(bad->data(),bad->size()));
        }
    }
    assert(!vox_encode_picture_image(nullptr));
    assert(!vox_decode_picture_image(nullptr,0));
    for(int32_t width : {0,-2,16385,INT32_MAX}) {
        int32_t invalid[] {width,1,0,0};
        assert(!vox_decode_picture_image(invalid,sizeof(invalid)));
    }
    std::puts("5 image color spaces retain source pixels; legacy and malformed payload checks pass");
}
