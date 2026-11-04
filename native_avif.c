// Static sRGB AVIF decoding. Only owned RGBA rows cross the engine boundary.
#include <avif/avif.h>
#include <stdint.h>
#include <stdlib.h>

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

VOX_AVIF_EXPORT uint8_t *vox_avif_decode(const uint8_t *bytes, uint64_t length,
    int premultiply, int32_t *width, int32_t *height, int32_t *pitch)
{
    if (width) *width = 0;
    if (height) *height = 0;
    if (pitch) *pitch = 0;
    if (!width || !height || !pitch || !vox_avif_sniff(bytes, length)) return NULL;
    avifDecoder *decoder = avifDecoderCreate();
    if (!decoder) return NULL;
    decoder->maxThreads = 2;
    decoder->ignoreExif = AVIF_TRUE;
    decoder->ignoreXMP = AVIF_TRUE;
    decoder->imageSizeLimit = VOX_AVIF_MAX_PIXELS;
    decoder->imageDimensionLimit = 16384;
    decoder->imageCountLimit = 1;
    uint8_t *pixels = NULL;
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
    avifRGBImage rgb;
    avifRGBImageSetDefaults(&rgb, image);
    rgb.depth = 8;
    rgb.format = AVIF_RGB_FORMAT_RGBA;
    rgb.chromaUpsampling = AVIF_CHROMA_UPSAMPLING_BILINEAR;
    rgb.alphaPremultiplied = premultiply ? AVIF_TRUE : AVIF_FALSE;
    rgb.rowBytes = image->width * 4;
    pixels = (uint8_t *)malloc((size_t)rgb.rowBytes * image->height);
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

VOX_AVIF_EXPORT void vox_avif_free(uint8_t *pixels) { free(pixels); }
