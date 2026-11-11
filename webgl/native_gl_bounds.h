// Native WebGL host-memory bounds and resource initialization.
// SPDX-License-Identifier: BSD-2-Clause
#ifndef VOX_WEBGL_NATIVE_GL_BOUNDS_H
#define VOX_WEBGL_NATIVE_GL_BOUNDS_H
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// ESSL/WebGL enums that are absent from some desktop core-profile headers.
#ifndef GL_ALPHA
#define GL_ALPHA 0x1906
#endif
#ifndef GL_LUMINANCE
#define GL_LUMINANCE 0x1909
#define GL_LUMINANCE_ALPHA 0x190A
#endif
#ifndef GL_RED_BITS
#define GL_RED_BITS 0x0D52
#define GL_GREEN_BITS 0x0D53
#define GL_BLUE_BITS 0x0D54
#define GL_ALPHA_BITS 0x0D55
#define GL_DEPTH_BITS 0x0D56
#define GL_STENCIL_BITS 0x0D57
#endif
#ifndef GL_GENERATE_MIPMAP_HINT
#define GL_GENERATE_MIPMAP_HINT 0x8192
#endif
#ifndef GL_ALIASED_POINT_SIZE_RANGE
#define GL_ALIASED_POINT_SIZE_RANGE 0x846D
#endif
#ifndef GL_MAX_VERTEX_UNIFORM_VECTORS
#define GL_MAX_VERTEX_UNIFORM_VECTORS 0x8DFB
#define GL_MAX_VARYING_VECTORS 0x8DFC
#define GL_MAX_FRAGMENT_UNIFORM_VECTORS 0x8DFD
#endif
#ifndef GL_IMPLEMENTATION_COLOR_READ_TYPE
#define GL_IMPLEMENTATION_COLOR_READ_TYPE 0x8B9A
#define GL_IMPLEMENTATION_COLOR_READ_FORMAT 0x8B9B
#endif
#ifndef GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT
#define GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT 0x84FF
#endif
#ifndef GL_TEXTURE_MAX_ANISOTROPY_EXT
#define GL_TEXTURE_MAX_ANISOTROPY_EXT 0x84FE
#endif
#ifndef GL_MAX_ELEMENT_INDEX
#define GL_MAX_ELEMENT_INDEX 0x8D6B
#endif
#ifndef GL_NUM_SAMPLE_COUNTS
#define GL_NUM_SAMPLE_COUNTS 0x9380
#endif
#ifndef GL_TEXTURE_IMMUTABLE_FORMAT
#define GL_TEXTURE_IMMUTABLE_FORMAT 0x912F
#endif
#ifndef GL_TEXTURE_IMMUTABLE_LEVELS
#define GL_TEXTURE_IMMUTABLE_LEVELS 0x82DF
#endif

static void vox_native_gl_error(GLenum error)
{
    VoxEGLContext* context = vox_native_gl_current();
    if (context && context->pending_error == GL_NO_ERROR)
        context->pending_error = error;
}

static int vox_native_size_add(size_t a, size_t b, size_t* result)
{
    if (b > SIZE_MAX - a) return 0;
    *result = a + b;
    return 1;
}

static int vox_native_size_mul(size_t a, size_t b, size_t* result)
{
    if (a && b > SIZE_MAX / a) return 0;
    *result = a * b;
    return 1;
}

static size_t vox_native_pixel_size(GLenum format, GLenum type)
{
    size_t components;
    switch (format) {
    case GL_ALPHA: case GL_LUMINANCE: case GL_RED: case GL_RED_INTEGER:
    case GL_DEPTH_COMPONENT: components = 1; break;
    case GL_LUMINANCE_ALPHA: case GL_RG: case GL_RG_INTEGER: components = 2; break;
    case GL_RGB: case GL_RGB_INTEGER: components = 3; break;
    case GL_RGBA: case GL_RGBA_INTEGER: components = 4; break;
    case GL_DEPTH_STENCIL: components = 1; break;
    default: return 0;
    }
    switch (type) {
    case GL_UNSIGNED_BYTE: case GL_BYTE: return components;
    case GL_UNSIGNED_SHORT: case GL_SHORT: case GL_HALF_FLOAT:
    case 0x8D61: return components * 2; // HALF_FLOAT_OES
    case GL_UNSIGNED_INT: case GL_INT: case GL_FLOAT: return components * 4;
    case GL_UNSIGNED_SHORT_5_6_5:
        return format == GL_RGB ? 2 : 0;
    case GL_UNSIGNED_SHORT_4_4_4_4: case GL_UNSIGNED_SHORT_5_5_5_1:
        return format == GL_RGBA ? 2 : 0;
    case GL_UNSIGNED_INT_2_10_10_10_REV:
        return format == GL_RGBA || format == GL_RGBA_INTEGER ? 4 : 0;
    case GL_UNSIGNED_INT_10F_11F_11F_REV: case GL_UNSIGNED_INT_5_9_9_9_REV:
        return format == GL_RGB ? 4 : 0;
    case GL_UNSIGNED_INT_24_8: return format == GL_DEPTH_STENCIL ? 4 : 0;
    case GL_FLOAT_32_UNSIGNED_INT_24_8_REV: return format == GL_DEPTH_STENCIL ? 8 : 0;
    default: return 0;
    }
}

// Compute the last byte touched, including row padding and all skip state.
// Do not call glGetError here: an earlier driver error must remain observable.
static int vox_native_pixel_extent(int pack, int dimensions, int width, int height,
    int depth, GLenum format, GLenum type, size_t* extent)
{
    *extent = 0;
    if (width < 0 || height < 0 || depth < 0) {
        vox_native_gl_error(GL_INVALID_VALUE);
        return 0;
    }
    size_t pixel = vox_native_pixel_size(format, type);
    if (!pixel) {
        vox_native_gl_error(GL_INVALID_ENUM);
        return 0;
    }
    if (!width || !height || !depth) return 1;
    GLint alignment = 4, row_length = 0, image_height = 0;
    GLint skip_pixels = 0, skip_rows = 0, skip_images = 0;
    glGetIntegerv(pack ? GL_PACK_ALIGNMENT : GL_UNPACK_ALIGNMENT, &alignment);
    glGetIntegerv(pack ? GL_PACK_ROW_LENGTH : GL_UNPACK_ROW_LENGTH, &row_length);
    glGetIntegerv(pack ? GL_PACK_SKIP_PIXELS : GL_UNPACK_SKIP_PIXELS, &skip_pixels);
    glGetIntegerv(pack ? GL_PACK_SKIP_ROWS : GL_UNPACK_SKIP_ROWS, &skip_rows);
    if (!pack && dimensions == 3) {
        glGetIntegerv(GL_UNPACK_IMAGE_HEIGHT, &image_height);
        glGetIntegerv(GL_UNPACK_SKIP_IMAGES, &skip_images);
    }
    if ((alignment != 1 && alignment != 2 && alignment != 4 && alignment != 8)
        || row_length < 0 || image_height < 0 || skip_pixels < 0 || skip_rows < 0 || skip_images < 0) {
        vox_native_gl_error(GL_INVALID_OPERATION);
        return 0;
    }
    if (pack && (uint64_t)(unsigned)skip_pixels + (unsigned)width > (uint64_t)(row_length ? row_length : width)) {
        vox_native_gl_error(GL_INVALID_OPERATION);
        return 0;
    }
    size_t row, image, offset, tail, value;
    if (!vox_native_size_mul((size_t)(row_length ? row_length : width), pixel, &row)
        || !vox_native_size_add(row, (size_t)alignment - 1, &row)) goto overflow;
    row &= ~((size_t)alignment - 1);
    if (!vox_native_size_mul((size_t)(image_height ? image_height : height), row, &image)
        || !vox_native_size_mul((size_t)skip_images, image, &offset)
        || !vox_native_size_mul((size_t)skip_rows, row, &value)
        || !vox_native_size_add(offset, value, &offset)
        || !vox_native_size_mul((size_t)skip_pixels, pixel, &value)
        || !vox_native_size_add(offset, value, &offset)
        || !vox_native_size_mul((size_t)(depth - 1), image, &tail)
        || !vox_native_size_add(offset, tail, &offset)
        || !vox_native_size_mul((size_t)(height - 1), row, &tail)
        || !vox_native_size_add(offset, tail, &offset)
        || !vox_native_size_mul((size_t)width, pixel, &tail)
        || !vox_native_size_add(offset, tail, extent)) goto overflow;
    return 1;
overflow:
    vox_native_gl_error(GL_INVALID_OPERATION);
    return 0;
}

static int vox_native_buffer_extent(GLenum target, size_t offset, size_t bytes)
{
    GLint64 length = 0;
    glGetBufferParameteri64v(target, GL_BUFFER_SIZE, &length);
    if (length < 0 || (uint64_t)offset > (uint64_t)length
        || (uint64_t)bytes > (uint64_t)length - (uint64_t)offset) {
        vox_native_gl_error(GL_INVALID_OPERATION);
        return 0;
    }
    return 1;
}

// Client pointers and buffer offsets are deliberately separate. A null image
// without an unpack buffer allocates zeroed storage, as WebGL requires.
static int vox_native_unpack_pixels(int dimensions, int width, int height, int depth,
    GLenum format, GLenum type, int capacity, const void* data, int allocate,
    const void** pixels, void** owned)
{
    *pixels = data;
    *owned = NULL;
    if (capacity < 0) { vox_native_gl_error(GL_INVALID_VALUE); return 0; }
    size_t bytes;
    if (!vox_native_pixel_extent(0, dimensions, width, height, depth, format, type, &bytes)) return 0;
    GLint buffer = 0;
    glGetIntegerv(GL_PIXEL_UNPACK_BUFFER_BINDING, &buffer);
    if (data || buffer || !allocate) {
        GLint row_length = 0, skip_pixels = 0, image_height = 0, skip_rows = 0;
        glGetIntegerv(GL_UNPACK_ROW_LENGTH, &row_length);
        glGetIntegerv(GL_UNPACK_SKIP_PIXELS, &skip_pixels);
        if (dimensions == 3) {
            glGetIntegerv(GL_UNPACK_IMAGE_HEIGHT, &image_height);
            glGetIntegerv(GL_UNPACK_SKIP_ROWS, &skip_rows);
        }
        if ((uint64_t)(unsigned)skip_pixels + (unsigned)width > (uint64_t)(row_length ? row_length : width)
            || (dimensions == 3 && (uint64_t)(unsigned)skip_rows + (unsigned)height > (uint64_t)(image_height ? image_height : height))) {
            vox_native_gl_error(GL_INVALID_OPERATION);
            return 0;
        }
    }
    if (buffer) {
        if (capacity || data) { vox_native_gl_error(GL_INVALID_OPERATION); return 0; }
        return vox_native_buffer_extent(GL_PIXEL_UNPACK_BUFFER, 0, bytes);
    }
    if (!data && allocate) {
        if (!bytes) return 1;
        *owned = calloc(1, bytes);
        if (!*owned) { vox_native_gl_error(GL_OUT_OF_MEMORY); return 0; }
        *pixels = *owned;
        return 1;
    }
    if (bytes > (size_t)capacity || (bytes && !data)) {
        vox_native_gl_error(GL_INVALID_OPERATION);
        return 0;
    }
    return 1;
}

static GLenum vox_native_pixel_format(GLenum format)
{
#if VOX_NATIVE_GL_DESKTOP
    if (format == GL_ALPHA || format == GL_LUMINANCE) return GL_RED;
    if (format == GL_LUMINANCE_ALPHA) return GL_RG;
#endif
    return format;
}

static GLenum vox_native_pixel_type(GLenum type)
{
    return type == 0x8D61 ? GL_HALF_FLOAT : type;
}

static GLenum vox_native_texture_format(GLenum format, GLenum type)
{
#if VOX_NATIVE_GL_DESKTOP
    if (format == GL_ALPHA || format == GL_LUMINANCE)
        return type == GL_FLOAT ? GL_R32F : type == GL_HALF_FLOAT || type == 0x8D61 ? GL_R16F : GL_R8;
    if (format == GL_LUMINANCE_ALPHA)
        return type == GL_FLOAT ? GL_RG32F : type == GL_HALF_FLOAT || type == 0x8D61 ? GL_RG16F : GL_RG8;
    if (format == GL_RGB && type == GL_FLOAT) return GL_RGB32F;
    if (format == GL_RGB && (type == GL_HALF_FLOAT || type == 0x8D61)) return GL_RGB16F;
    if (format == GL_RGBA && type == GL_FLOAT) return GL_RGBA32F;
    if (format == GL_RGBA && (type == GL_HALF_FLOAT || type == 0x8D61)) return GL_RGBA16F;
#endif
    return format;
}

static void vox_native_texture_swizzle(GLenum target, GLenum format)
{
#if VOX_NATIVE_GL_DESKTOP
    if (target >= GL_TEXTURE_CUBE_MAP_POSITIVE_X && target <= GL_TEXTURE_CUBE_MAP_NEGATIVE_Z)
        target = GL_TEXTURE_CUBE_MAP;
    if (target != GL_TEXTURE_2D && target != GL_TEXTURE_CUBE_MAP
        && target != GL_TEXTURE_3D && target != GL_TEXTURE_2D_ARRAY) return;
    GLint rgba[4] = {GL_RED, GL_GREEN, GL_BLUE, GL_ALPHA};
    if (format == GL_ALPHA) { rgba[0] = rgba[1] = rgba[2] = GL_ZERO; rgba[3] = GL_RED; }
    if (format == GL_LUMINANCE || format == GL_LUMINANCE_ALPHA) {
        rgba[1] = rgba[2] = GL_RED;
        rgba[3] = format == GL_LUMINANCE ? GL_ONE : GL_GREEN;
    }
    glTexParameteriv(target, GL_TEXTURE_SWIZZLE_RGBA, rgba);
#else
    (void)target; (void)format;
#endif
}

static int vox_native_scalar_texture_parameter(GLenum pname)
{
    switch (pname) {
    case GL_TEXTURE_MAG_FILTER: case GL_TEXTURE_MIN_FILTER:
    case GL_TEXTURE_WRAP_S: case GL_TEXTURE_WRAP_T: case GL_TEXTURE_WRAP_R:
    case GL_TEXTURE_BASE_LEVEL: case GL_TEXTURE_MAX_LEVEL:
    case GL_TEXTURE_COMPARE_MODE: case GL_TEXTURE_COMPARE_FUNC:
    case GL_TEXTURE_MIN_LOD: case GL_TEXTURE_MAX_LOD:
    case GL_TEXTURE_IMMUTABLE_FORMAT: case GL_TEXTURE_IMMUTABLE_LEVELS:
    case GL_TEXTURE_MAX_ANISOTROPY_EXT: return 1;
    default: vox_native_gl_error(GL_INVALID_ENUM); return 0;
    }
}

static int vox_native_scalar_program_parameter(GLenum pname)
{
    switch (pname) {
    case GL_DELETE_STATUS: case GL_LINK_STATUS: case GL_VALIDATE_STATUS:
    case GL_INFO_LOG_LENGTH: case GL_ATTACHED_SHADERS:
    case GL_ACTIVE_ATTRIBUTES: case GL_ACTIVE_ATTRIBUTE_MAX_LENGTH:
    case GL_ACTIVE_UNIFORMS: case GL_ACTIVE_UNIFORM_MAX_LENGTH:
    case GL_TRANSFORM_FEEDBACK_BUFFER_MODE: case GL_TRANSFORM_FEEDBACK_VARYINGS:
    case GL_TRANSFORM_FEEDBACK_VARYING_MAX_LENGTH: case GL_ACTIVE_UNIFORM_BLOCKS:
    case GL_ACTIVE_UNIFORM_BLOCK_MAX_NAME_LENGTH: return 1;
    default: vox_native_gl_error(GL_INVALID_ENUM); return 0;
    }
}

static void vox_native_integer_parameter(GLenum pname, GLint* values)
{
#if VOX_NATIVE_GL_DESKTOP
    GLenum attachment = GL_COLOR_ATTACHMENT0, component = 0;
    switch (pname) {
    case GL_RED_BITS: component = GL_FRAMEBUFFER_ATTACHMENT_RED_SIZE; break;
    case GL_GREEN_BITS: component = GL_FRAMEBUFFER_ATTACHMENT_GREEN_SIZE; break;
    case GL_BLUE_BITS: component = GL_FRAMEBUFFER_ATTACHMENT_BLUE_SIZE; break;
    case GL_ALPHA_BITS: component = GL_FRAMEBUFFER_ATTACHMENT_ALPHA_SIZE; break;
    case GL_DEPTH_BITS: attachment = GL_DEPTH_ATTACHMENT; component = GL_FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE; break;
    case GL_STENCIL_BITS: attachment = GL_STENCIL_ATTACHMENT; component = GL_FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE; break;
    case GL_GENERATE_MIPMAP_HINT: values[0] = GL_DONT_CARE; return;
    case GL_MAX_VERTEX_UNIFORM_VECTORS:
        glGetIntegerv(GL_MAX_VERTEX_UNIFORM_COMPONENTS, values); values[0] /= 4; return;
    case GL_MAX_FRAGMENT_UNIFORM_VECTORS:
        glGetIntegerv(GL_MAX_FRAGMENT_UNIFORM_COMPONENTS, values); values[0] /= 4; return;
    case GL_MAX_VARYING_VECTORS:
        glGetIntegerv(GL_MAX_VARYING_COMPONENTS, values); values[0] /= 4; return;
    }
    if (component) {
        GLint kind = GL_NONE;
        glGetFramebufferAttachmentParameteriv(GL_DRAW_FRAMEBUFFER, attachment,
            GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE, &kind);
        if (kind == GL_NONE) { values[0] = 0; return; }
        glGetFramebufferAttachmentParameteriv(GL_DRAW_FRAMEBUFFER, attachment, component, values);
        return;
    }
#endif
    glGetIntegerv(pname, values);
}

// glClear honors masks and the scissor. Resource initialization must not.
static void vox_native_clear_bound_framebuffer_format(GLbitfield mask, GLenum format)
{
    GLfloat color[4], depth;
    GLint stencil, front_mask, back_mask;
    GLboolean color_mask[4], depth_mask;
    GLboolean scissor = glIsEnabled(GL_SCISSOR_TEST);
    GLboolean discard = glIsEnabled(GL_RASTERIZER_DISCARD);
    glGetFloatv(GL_COLOR_CLEAR_VALUE, color);
    glGetFloatv(GL_DEPTH_CLEAR_VALUE, &depth);
    glGetIntegerv(GL_STENCIL_CLEAR_VALUE, &stencil);
    glGetBooleanv(GL_COLOR_WRITEMASK, color_mask);
    glGetBooleanv(GL_DEPTH_WRITEMASK, &depth_mask);
    glGetIntegerv(GL_STENCIL_WRITEMASK, &front_mask);
    glGetIntegerv(GL_STENCIL_BACK_WRITEMASK, &back_mask);
    glDisable(GL_SCISSOR_TEST);
    glDisable(GL_RASTERIZER_DISCARD);
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    glDepthMask(GL_TRUE);
    glStencilMaskSeparate(GL_FRONT, ~0u);
    glStencilMaskSeparate(GL_BACK, ~0u);
    glClearColor(0, 0, 0, 0);
    glClearDepthf(1);
    glClearStencil(0);
    if (mask & GL_COLOR_BUFFER_BIT) {
        GLint zero_i[4] = {0};
        GLuint zero_u[4] = {0};
        switch (format) {
        case GL_R8I: case GL_R16I: case GL_R32I:
        case GL_RG8I: case GL_RG16I: case GL_RG32I:
        case GL_RGB8I: case GL_RGB16I: case GL_RGB32I:
        case GL_RGBA8I: case GL_RGBA16I: case GL_RGBA32I:
            glClearBufferiv(GL_COLOR, 0, zero_i); mask &= ~GL_COLOR_BUFFER_BIT; break;
        case GL_R8UI: case GL_R16UI: case GL_R32UI:
        case GL_RG8UI: case GL_RG16UI: case GL_RG32UI:
        case GL_RGB8UI: case GL_RGB16UI: case GL_RGB32UI:
        case GL_RGBA8UI: case GL_RGBA16UI: case GL_RGBA32UI: case GL_RGB10_A2UI:
            glClearBufferuiv(GL_COLOR, 0, zero_u); mask &= ~GL_COLOR_BUFFER_BIT; break;
        }
    }
    if (mask) glClear(mask);
    glClearColor(color[0], color[1], color[2], color[3]);
    glClearDepthf(depth);
    glClearStencil(stencil);
    glColorMask(color_mask[0], color_mask[1], color_mask[2], color_mask[3]);
    glDepthMask(depth_mask);
    glStencilMaskSeparate(GL_FRONT, (GLuint)front_mask);
    glStencilMaskSeparate(GL_BACK, (GLuint)back_mask);
    if (scissor) glEnable(GL_SCISSOR_TEST);
    if (discard) glEnable(GL_RASTERIZER_DISCARD);
}

static void vox_native_clear_bound_framebuffer(GLbitfield mask)
{
    vox_native_clear_bound_framebuffer_format(mask, GL_RGBA8);
}

static void vox_native_initialize_renderbuffer(GLenum format)
{
    GLint renderbuffer = 0, draw = 0, read = 0;
    glGetIntegerv(GL_RENDERBUFFER_BINDING, &renderbuffer);
    if (!renderbuffer) return;
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &draw);
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &read);
    GLuint temporary = 0;
    glGenFramebuffers(1, &temporary);
    if (!temporary) {
        vox_native_gl_error(GL_OUT_OF_MEMORY);
        vox_native_gl_current()->failed = 1;
        return;
    }
    glBindFramebuffer(GL_FRAMEBUFFER, temporary);
    GLenum attachment = GL_COLOR_ATTACHMENT0;
    GLbitfield mask = GL_COLOR_BUFFER_BIT;
    switch (format) {
    case GL_DEPTH_COMPONENT16: case GL_DEPTH_COMPONENT24: case GL_DEPTH_COMPONENT32F:
        attachment = GL_DEPTH_ATTACHMENT; mask = GL_DEPTH_BUFFER_BIT; break;
    case GL_STENCIL_INDEX8:
        attachment = GL_STENCIL_ATTACHMENT; mask = GL_STENCIL_BUFFER_BIT; break;
    case GL_DEPTH24_STENCIL8: case GL_DEPTH32F_STENCIL8:
        attachment = GL_DEPTH_STENCIL_ATTACHMENT; mask = GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT; break;
    }
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, attachment, GL_RENDERBUFFER, (GLuint)renderbuffer);
    if (attachment != GL_COLOR_ATTACHMENT0) {
        GLenum none = GL_NONE;
        glDrawBuffers(1, &none);
        glReadBuffer(GL_NONE);
    }
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE) {
        vox_native_clear_bound_framebuffer_format(mask, format);
    } else {
        vox_native_gl_error(GL_INVALID_FRAMEBUFFER_OPERATION);
        vox_native_gl_current()->failed = 1;
    }
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, (GLuint)draw);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, (GLuint)read);
    glDeleteFramebuffers(1, &temporary);
}
#endif
