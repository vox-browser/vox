#ifndef VOX_METAL_VERTEX_FORMATS_H
#define VOX_METAL_VERTEX_FORMATS_H
#include "drawing_buffer_darwin.h"
static unsigned vox_metal_vertex_scalar_size(unsigned format)
{
    unsigned const sizes[] = {4,1,1,2,2,4,4,2};
    return format < sizeof(sizes)/sizeof(*sizes) ? sizes[format] : 0;
}
static MTLVertexFormat vox_metal_vertex_format(unsigned format, unsigned components, unsigned normalized)
{
    if (components < 1 || components > 4) return MTLVertexFormatInvalid;
    unsigned n = components - 1;
    switch (format) {
    case 0: return (MTLVertexFormat)(MTLVertexFormatFloat + n);
    case 1:
        if (components == 1) return normalized ? MTLVertexFormatUCharNormalized : MTLVertexFormatUChar;
        return (MTLVertexFormat)((normalized ? MTLVertexFormatUChar2Normalized : MTLVertexFormatUChar2) + n - 1);
    case 2:
        if (components == 1) return normalized ? MTLVertexFormatCharNormalized : MTLVertexFormatChar;
        return (MTLVertexFormat)((normalized ? MTLVertexFormatChar2Normalized : MTLVertexFormatChar2) + n - 1);
    case 3:
        if (components == 1) return normalized ? MTLVertexFormatUShortNormalized : MTLVertexFormatUShort;
        return (MTLVertexFormat)((normalized ? MTLVertexFormatUShort2Normalized : MTLVertexFormatUShort2) + n - 1);
    case 4:
        if (components == 1) return normalized ? MTLVertexFormatShortNormalized : MTLVertexFormatShort;
        return (MTLVertexFormat)((normalized ? MTLVertexFormatShort2Normalized : MTLVertexFormatShort2) + n - 1);
    case 5: return normalized ? MTLVertexFormatInvalid : (MTLVertexFormat)(MTLVertexFormatUInt + n);
    case 6: return normalized ? MTLVertexFormatInvalid : (MTLVertexFormat)(MTLVertexFormatInt + n);
    case 7: return components == 1 ? MTLVertexFormatHalf : (MTLVertexFormat)(MTLVertexFormatHalf2 + n - 1);
    default: return MTLVertexFormatInvalid;
    }
}
#endif
