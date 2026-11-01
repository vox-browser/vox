#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

int main()
{
    unsetenv("VOX_DISABLE_SHARED_PICTURE_PIXELS");
    constexpr int width = 256, height = 128, pitch = width * 4;
    for (bool tagged : {false, true}) {
        auto space = tagged ? SkColorSpace::MakeSRGBLinear() : SkColorSpace::MakeSRGB();
        auto info = SkImageInfo::Make(width, height, kRGBA_8888_SkColorType, kPremul_SkAlphaType, space);
        std::vector<uint8_t> source(pitch * height);
        for (size_t i = 0; i < source.size(); i += 4) {
            source[i] = uint8_t(i * 13); source[i+1] = uint8_t(i / 7);
            source[i+2] = uint8_t(i / 11); source[i+3] = 255;
        }
        auto original = source;
        auto image = SkImages::RasterFromPixmapCopy(SkPixmap(info, source.data(), pitch));
        assert(image);
        sk_sp<SkImage> shared;
        sk_sp<SkData> token_bytes;
        {
            SharedPicturePixelsScope scope;
            auto copied = vox_encode_picture_image(image.get());
            assert(copied);
            token_bytes = scope.encode(copied);
            assert(token_bytes && token_bytes->size() == sizeof(VoxSharedPicturePixelsToken));
            shared = vox_decode_picture_image(token_bytes->data(), token_bytes->size());
            assert(shared && s_shared_picture_pixels.live_bytes() >= source.size());
            image.reset(); copied.reset();
            std::fill(source.begin(), source.end(), 17);
        }
        // The registry token has retired, while the decoded image still owns
        // its lease. Later pixel access must remain valid in the original space.
        assert(!vox_decode_picture_image(token_bytes->data(), token_bytes->size()));
        assert(s_shared_picture_pixels.live_bytes() >= original.size());
        assert(shared->readPixels(nullptr, info, source.data(), pitch, 0, 0));
        assert(source == original);
        auto payload = VoxSharedPicturePixelsToken{};
        std::memcpy(&payload, token_bytes->data(), sizeof(payload));
        payload.version++;
        assert(!vox_decode_picture_image(&payload, sizeof(payload)));
        shared.reset(); assert(!s_shared_picture_pixels.live_bytes());
    }
    for (int invalid_width : {0, 32768, 2}) {
        auto bytes = std::make_shared<std::vector<uint8_t>>(65536, 0);
        int32_t dimensions[] {invalid_width, 2};
        std::memcpy(bytes->data(), dimensions, sizeof(dimensions));
        auto token = s_shared_picture_pixels.insert(bytes, bytes->data(), bytes->size());
        assert(token);
        VoxSharedPicturePixelsToken payload; payload.token = token;
        assert(!vox_decode_picture_image(&payload, sizeof(payload)));
        s_shared_picture_pixels.retire(token);
        assert(!s_shared_picture_pixels.live_bytes());
    }
    std::cout << "Shared raster images preserve tagged/sRGB bytes after token retirement and caller mutation, reject stale tokens and release leases\n";
}
