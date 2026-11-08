#pragma once
#include <CoreGraphics/CoreGraphics.h>
#include <cstdint>
#include <limits>

// Owned immutable provider bytes. Accept only the exact format/color space
// used by our isolated Quartz layers; all other images retain Quartz decoding.
class VoxImmutableRGBAImage {
    CFDataRef bytes_ = nullptr;
public:
    VoxImmutableRGBAImage() = default;
    VoxImmutableRGBAImage(VoxImmutableRGBAImage const&) = delete;
    VoxImmutableRGBAImage& operator=(VoxImmutableRGBAImage const&) = delete;
    ~VoxImmutableRGBAImage() { if (bytes_) CFRelease(bytes_); }
    bool load(CGImageRef image) {
        if (bytes_ || !image || CGImageIsMask(image) || CGImageGetDecode(image)
            || CGImageGetBitsPerComponent(image) != 8 || CGImageGetBitsPerPixel(image) != 32
            || CGImageGetAlphaInfo(image) != kCGImageAlphaPremultipliedLast
            || (CGImageGetBitmapInfo(image) & kCGBitmapByteOrderMask) != kCGBitmapByteOrder32Big)
            return false;
        auto expected = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto actual = CGImageGetColorSpace(image);
        bool srgb = expected && actual && CFEqual(expected, actual);
        if (expected) CGColorSpaceRelease(expected);
        size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
        size_t pitch = CGImageGetBytesPerRow(image);
        if (!srgb || !width || !height || width > SIZE_MAX / 4 || pitch < width * 4
            || pitch > size_t(std::numeric_limits<CFIndex>::max()) / height) return false;
        auto provider = CGImageGetDataProvider(image);
        if (!provider) return false;
        auto bytes = CGDataProviderCopyData(provider);
        if (!bytes) return false;
        if (size_t(CFDataGetLength(bytes)) < pitch * height) { CFRelease(bytes); return false; }
        bytes_ = bytes;
        return true;
    }
    uint8_t const* pixels() const { return bytes_ ? CFDataGetBytePtr(bytes_) : nullptr; }
};
