// Static sRGB AVIF decoding. Only owned pixel or packed-plane rows cross the boundary.
#include <avif/avif.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define VOX_AVIF_EXPORT __attribute__((visibility("default")))
#define VOX_AVIF_MAX_PIXELS (16u * 1024u * 1024u)
#define VOX_AVIF_MAX_INPUT (64u * 1024u * 1024u)

VOX_AVIF_EXPORT uint32_t vox_avif_api_version(void) { return 1; }
VOX_AVIF_EXPORT const char *vox_avif_codec_version(void) { return avifVersion(); }
VOX_AVIF_EXPORT int vox_avif_sniff(const uint8_t *bytes, uint64_t length)
{
    if (!bytes || length < 16 || length > VOX_AVIF_MAX_INPUT) return 0;
    avifROData input = { bytes, (size_t)length };
    return avifPeekCompatibleFileType(&input) != AVIF_FALSE;
}

static avifDecoder *vox_avif_open(const uint8_t *bytes, uint64_t length)
{
    if (!vox_avif_sniff(bytes, length)) return NULL;
    avifDecoder *decoder = avifDecoderCreate();
    if (!decoder) return NULL;
    decoder->maxThreads = 2;
    decoder->ignoreExif = AVIF_TRUE;
    decoder->ignoreXMP = AVIF_TRUE;
    decoder->imageSizeLimit = VOX_AVIF_MAX_PIXELS;
    decoder->imageDimensionLimit = 16384;
    decoder->imageCountLimit = 1;
    if (avifDecoderSetIOMemory(decoder, bytes, (size_t)length) != AVIF_RESULT_OK
        || avifDecoderParse(decoder) != AVIF_RESULT_OK || decoder->imageCount != 1)
        goto done;
    avifImage *image = decoder->image;
    // These cases need orientation, animation or color-management integration;
    // declining them is preferable to returning a wrongly tagged static frame.
    if (!image->width || !image->height || image->width > 16384 || image->height > 16384
        || (uint64_t)image->width * image->height > VOX_AVIF_MAX_PIXELS
        || image->icc.size || image->transformFlags != AVIF_TRANSFORM_NONE
        || (image->colorPrimaries != AVIF_COLOR_PRIMARIES_BT709
            && image->colorPrimaries != AVIF_COLOR_PRIMARIES_UNSPECIFIED)
        || (image->transferCharacteristics != AVIF_TRANSFER_CHARACTERISTICS_SRGB
            && image->transferCharacteristics != AVIF_TRANSFER_CHARACTERISTICS_UNSPECIFIED))
        goto done;
    if (avifDecoderNextImage(decoder) != AVIF_RESULT_OK) goto done;
    return decoder;
done:
    avifDecoderDestroy(decoder);
    return NULL;
}

VOX_AVIF_EXPORT uint8_t *vox_avif_decode(const uint8_t *bytes, uint64_t length,
    int premultiply, int32_t *width, int32_t *height, int32_t *pitch)
{
    if (width) *width = 0;
    if (height) *height = 0;
    if (pitch) *pitch = 0;
    if (!width || !height || !pitch) return NULL;
    avifDecoder *decoder = vox_avif_open(bytes, length);
    if (!decoder) return NULL;
    avifImage *image = decoder->image;
    avifRGBImage rgb;
    avifRGBImageSetDefaults(&rgb, image);
    rgb.depth = 8;
    rgb.format = AVIF_RGB_FORMAT_RGBA;
    rgb.chromaUpsampling = AVIF_CHROMA_UPSAMPLING_BILINEAR;
    rgb.alphaPremultiplied = premultiply ? AVIF_TRUE : AVIF_FALSE;
    rgb.rowBytes = image->width * 4;
    uint8_t *pixels = (uint8_t *)malloc((size_t)rgb.rowBytes * image->height);
    if (!pixels) goto done;
    rgb.pixels = pixels;
    if (avifImageYUVToRGB(image, &rgb) != AVIF_RESULT_OK) {
        free(pixels);
        pixels = NULL;
        goto done;
    }
    *width = (int32_t)image->width;
    *height = (int32_t)image->height;
    *pitch = (int32_t)rgb.rowBytes;
done:
    avifDecoderDestroy(decoder);
    return pixels;
}

// The native painter samples the original planes before BT.601 conversion.
// Subsampling follows the existing native JPEG markers: 0=444, 1=422, 2=420.
VOX_AVIF_EXPORT uint8_t *vox_avif_decode_yuv(const uint8_t *bytes, uint64_t length,
    int32_t *width, int32_t *height, int32_t *size, int32_t *subsampling)
{
    if (width) *width = 0;
    if (height) *height = 0;
    if (size) *size = 0;
    if (subsampling) *subsampling = 0;
    if (!width || !height || !size || !subsampling) return NULL;
    avifDecoder *decoder = vox_avif_open(bytes, length);
    if (!decoder) return NULL;
    avifImage *image = decoder->image;
    uint8_t *planes = NULL;
    if (decoder->alphaPresent || image->depth != 8 || image->yuvRange != AVIF_RANGE_FULL
        || (image->matrixCoefficients != AVIF_MATRIX_COEFFICIENTS_BT601
            && image->matrixCoefficients != AVIF_MATRIX_COEFFICIENTS_UNSPECIFIED)
        || (image->yuvFormat != AVIF_PIXEL_FORMAT_YUV444
            && image->yuvFormat != AVIF_PIXEL_FORMAT_YUV422
            && image->yuvFormat != AVIF_PIXEL_FORMAT_YUV420)) goto done;
    uint32_t cw = image->yuvFormat == AVIF_PIXEL_FORMAT_YUV444 ? image->width : (image->width + 1) / 2;
    uint32_t ch = image->yuvFormat == AVIF_PIXEL_FORMAT_YUV420 ? (image->height + 1) / 2 : image->height;
    size_t total = (size_t)image->width * image->height + 2 * (size_t)cw * ch;
    planes = (uint8_t *)malloc(total);
    if (!planes) goto done;
    size_t offset = 0;
    for (int p = 0; p < 3; ++p) {
        uint32_t w = p ? cw : image->width, h = p ? ch : image->height;
        if (!image->yuvPlanes[p] || image->yuvRowBytes[p] < w) {
            free(planes); planes = NULL; goto done;
        }
        for (uint32_t y = 0; y < h; ++y)
            memcpy(planes + offset + (size_t)y * w,
                image->yuvPlanes[p] + (size_t)y * image->yuvRowBytes[p], w);
        offset += (size_t)w * h;
    }
    *width = (int32_t)image->width;
    *height = (int32_t)image->height;
    *size = (int32_t)total;
    *subsampling = image->yuvFormat == AVIF_PIXEL_FORMAT_YUV444 ? 0
        : image->yuvFormat == AVIF_PIXEL_FORMAT_YUV422 ? 1 : 2;
done:
    avifDecoderDestroy(decoder);
    return planes;
}

VOX_AVIF_EXPORT void vox_avif_free(uint8_t *pixels) { free(pixels); }
