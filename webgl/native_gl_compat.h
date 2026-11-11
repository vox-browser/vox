/* Native OpenGL compatibility for the WebGL service.
 * Included after native_gl_platform.h and native_gl_bounds.h.
 */
#ifndef VOX_WEBGL_NATIVE_GL_COMPAT_H
#define VOX_WEBGL_NATIVE_GL_COMPAT_H

#include <limits.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#ifndef GL_TEXTURE_IMMUTABLE_FORMAT
#define GL_TEXTURE_IMMUTABLE_FORMAT 0x912F
#endif
#ifndef GL_TEXTURE_IMMUTABLE_LEVELS
#define GL_TEXTURE_IMMUTABLE_LEVELS 0x82DF
#endif
#ifndef GL_NUM_SAMPLE_COUNTS
#define GL_NUM_SAMPLE_COUNTS 0x9380
#endif

typedef struct VoxNativeTextureStorage {
    GLuint texture;
    GLint levels;
    GLint base_level;
    GLint max_level;
    struct VoxNativeTextureStorage* next;
} VoxNativeTextureStorage;

static VoxNativeTextureStorage* vox_native_storage_record(GLuint texture)
{
    VoxEGLContext* context = vox_native_gl_current();
    VoxNativeTextureStorage* item = context ? context->texture_storage : NULL;
    for (; item; item = item->next)
        if (item->texture == texture) return item;
    return NULL;
}

static void vox_native_texture_deleted(GLuint texture)
{
    VoxEGLContext* context = vox_native_gl_current();
    if (!context) return;
    VoxNativeTextureStorage* previous = NULL;
    VoxNativeTextureStorage* item = context->texture_storage;
    while (item) {
        if (item->texture == texture) {
            if (previous) previous->next = item->next;
            else context->texture_storage = item->next;
            free(item);
            return;
        }
        previous = item;
        item = item->next;
    }
}

static void vox_native_compat_destroy(VoxEGLContext* context)
{
    VoxNativeTextureStorage* item = context ? context->texture_storage : NULL;
    while (item) {
        VoxNativeTextureStorage* next = item->next;
        free(item);
        item = next;
    }
    if (context) context->texture_storage = NULL;
}

static GLenum vox_native_storage_target(GLenum target)
{
    if (target >= GL_TEXTURE_CUBE_MAP_POSITIVE_X && target <= GL_TEXTURE_CUBE_MAP_NEGATIVE_Z)
        return GL_TEXTURE_CUBE_MAP;
    return target;
}

static GLenum vox_native_storage_binding_name(GLenum target)
{
    switch (vox_native_storage_target(target)) {
    case GL_TEXTURE_2D: return GL_TEXTURE_BINDING_2D;
    case GL_TEXTURE_CUBE_MAP: return GL_TEXTURE_BINDING_CUBE_MAP;
    case GL_TEXTURE_3D: return GL_TEXTURE_BINDING_3D;
    case GL_TEXTURE_2D_ARRAY: return GL_TEXTURE_BINDING_2D_ARRAY;
    default: return 0;
    }
}

static GLuint vox_native_storage_binding(GLenum target)
{
    GLenum binding = vox_native_storage_binding_name(target);
    GLint texture = 0;
    if (!binding) { vox_native_gl_error(GL_INVALID_ENUM); return 0; }
    glGetIntegerv(binding, &texture);
    return (GLuint)texture;
}

/* The emulated immutable flag must guard every image-redefinition operation,
 * including CopyTexImage and CompressedTexImage. Subimages remain writable. */
static int vox_native_texture_mutable(GLenum target)
{
    GLenum normalized = vox_native_storage_target(target);
    if (!vox_native_storage_binding_name(normalized)) {
        vox_native_gl_error(GL_INVALID_ENUM);
        return 0;
    }
    GLuint texture = vox_native_storage_binding(normalized);
    if (!texture) { vox_native_gl_error(GL_INVALID_OPERATION); return 0; }
#ifdef __APPLE__
    GLint immutable = vox_native_storage_record(texture) != NULL;
#else
    GLint immutable = GL_FALSE;
    glGetTexParameteriv(normalized, GL_TEXTURE_IMMUTABLE_FORMAT, &immutable);
#endif
    if (immutable) { vox_native_gl_error(GL_INVALID_OPERATION); return 0; }
    return 1;
}

/* Internal probes must not consume an error left by an earlier WebGL command. */
static void vox_native_storage_preserve_errors(void)
{
    for (int i = 0; i < 16; ++i) {
        GLenum error = glGetError();
        if (error == GL_NO_ERROR) break;
        vox_native_gl_error(error);
    }
}

static GLenum vox_native_storage_error(void)
{
    GLenum error = glGetError();
    if (error != GL_NO_ERROR) {
        vox_native_gl_error(error);
        vox_native_storage_preserve_errors();
    }
    return error;
}

static int vox_native_texture_scalar_parameter(GLenum pname)
{
    switch (pname) {
    case GL_TEXTURE_MAG_FILTER: case GL_TEXTURE_MIN_FILTER:
    case GL_TEXTURE_WRAP_S: case GL_TEXTURE_WRAP_T: case GL_TEXTURE_WRAP_R:
    case GL_TEXTURE_BASE_LEVEL: case GL_TEXTURE_MAX_LEVEL:
    case GL_TEXTURE_MIN_LOD: case GL_TEXTURE_MAX_LOD:
    case GL_TEXTURE_COMPARE_MODE: case GL_TEXTURE_COMPARE_FUNC:
    case GL_TEXTURE_IMMUTABLE_FORMAT: case GL_TEXTURE_IMMUTABLE_LEVELS:
    case 0x84FE: /* GL_TEXTURE_MAX_ANISOTROPY_EXT */
        return 1;
    default: return 0;
    }
}

static int vox_native_texture_emulated_parameter(GLenum target, GLenum pname, GLint* result)
{
#ifdef __APPLE__
    if (pname == GL_TEXTURE_IMMUTABLE_FORMAT || pname == GL_TEXTURE_IMMUTABLE_LEVELS
        || pname == GL_TEXTURE_BASE_LEVEL || pname == GL_TEXTURE_MAX_LEVEL) {
        GLuint texture = vox_native_storage_binding(target);
        if (!texture) { vox_native_gl_error(GL_INVALID_OPERATION); return 1; }
        VoxNativeTextureStorage* record = vox_native_storage_record(texture);
        if (pname == GL_TEXTURE_IMMUTABLE_FORMAT) {
            *result = record ? GL_TRUE : GL_FALSE;
            return 1;
        }
        if (pname == GL_TEXTURE_IMMUTABLE_LEVELS) {
            *result = record ? record->levels : 0;
            return 1;
        }
        if (record) {
            *result = pname == GL_TEXTURE_BASE_LEVEL ? record->base_level : record->max_level;
            return 1;
        }
    }
#else
    (void)target; (void)pname; (void)result;
#endif
    return 0;
}

static void vox_native_texture_parameter(GLenum target, GLenum pname, GLint* result)
{
    if (!result) { vox_native_gl_error(GL_INVALID_VALUE); return; }
    *result = 0;
    if (vox_native_storage_target(target) != target || !vox_native_storage_binding_name(target)
        || !vox_native_texture_scalar_parameter(pname)) {
        vox_native_gl_error(GL_INVALID_ENUM);
        return;
    }
    if (!vox_native_texture_emulated_parameter(target, pname, result))
        glGetTexParameteriv(target, pname, result);
}

static void vox_native_texture_float_parameter(GLenum target, GLenum pname, GLfloat* result)
{
    if (!result) { vox_native_gl_error(GL_INVALID_VALUE); return; }
    *result = 0;
    if (vox_native_storage_target(target) != target || !vox_native_storage_binding_name(target)
        || !vox_native_texture_scalar_parameter(pname)) {
        vox_native_gl_error(GL_INVALID_ENUM);
        return;
    }
    GLint value = 0;
    if (vox_native_texture_emulated_parameter(target, pname, &value)) *result = (GLfloat)value;
    else glGetTexParameterfv(target, pname, result);
}

static void vox_native_storage_apply_levels(GLenum target, VoxNativeTextureStorage* record)
{
    GLint base = record->base_level < record->levels ? record->base_level : record->levels - 1;
    GLint maximum = record->max_level < record->levels ? record->max_level : record->levels - 1;
    if (maximum < base) maximum = base;
    glTexParameteri(target, GL_TEXTURE_BASE_LEVEL, base);
    glTexParameteri(target, GL_TEXTURE_MAX_LEVEL, maximum);
}

static void vox_native_tex_parameter_i(GLenum target, GLenum pname, GLint value)
{
#ifdef __APPLE__
    if ((pname == GL_TEXTURE_BASE_LEVEL || pname == GL_TEXTURE_MAX_LEVEL)
        && vox_native_storage_target(target) == target && vox_native_storage_binding_name(target)) {
        VoxNativeTextureStorage* record = vox_native_storage_record(vox_native_storage_binding(target));
        if (record) {
            if (value < 0) { vox_native_gl_error(GL_INVALID_VALUE); return; }
            if (pname == GL_TEXTURE_BASE_LEVEL) record->base_level = value;
            else record->max_level = value;
            vox_native_storage_apply_levels(target, record);
            return;
        }
    }
#endif
    glTexParameteri(target, pname, value);
}

static void vox_native_tex_parameter_f(GLenum target, GLenum pname, GLfloat value)
{
#ifdef __APPLE__
    if ((pname == GL_TEXTURE_BASE_LEVEL || pname == GL_TEXTURE_MAX_LEVEL)
        && vox_native_storage_target(target) == target && vox_native_storage_binding_name(target)) {
        VoxNativeTextureStorage* record = vox_native_storage_record(vox_native_storage_binding(target));
        if (record) {
            vox_native_storage_preserve_errors();
            glTexParameterf(target, pname, value);
            if (vox_native_storage_error() != GL_NO_ERROR) return;
            GLint converted = 0;
            glGetTexParameteriv(target, pname, &converted);
            vox_native_tex_parameter_i(target, pname, converted);
            return;
        }
    }
#endif
    glTexParameterf(target, pname, value);
}

typedef struct {
    GLenum format;
    GLenum type;
    size_t pixel_bytes;
    size_t block_bytes;
} VoxNativeStorageFormat;

/* Sized ES3 formats and compressed formats accepted by WebGL extensions.
 * The driver still validates that an optional compressed format is supported. */
static VoxNativeStorageFormat vox_native_storage_format(GLenum internal_format)
{
    switch (internal_format) {
#define VOX_STORAGE_FORMAT(internal, external, data_type, bytes) \
    case internal: return (VoxNativeStorageFormat){external, data_type, bytes, 0}
    VOX_STORAGE_FORMAT(GL_R8, GL_RED, GL_UNSIGNED_BYTE, 1);
    VOX_STORAGE_FORMAT(GL_R8_SNORM, GL_RED, GL_BYTE, 1);
    VOX_STORAGE_FORMAT(0x822A /* R16_EXT */, GL_RED, GL_UNSIGNED_SHORT, 2);
    VOX_STORAGE_FORMAT(0x8F98 /* R16_SNORM_EXT */, GL_RED, GL_SHORT, 2);
    VOX_STORAGE_FORMAT(GL_R16F, GL_RED, GL_HALF_FLOAT, 2);
    VOX_STORAGE_FORMAT(GL_R32F, GL_RED, GL_FLOAT, 4);
    VOX_STORAGE_FORMAT(GL_R8I, GL_RED_INTEGER, GL_BYTE, 1);
    VOX_STORAGE_FORMAT(GL_R8UI, GL_RED_INTEGER, GL_UNSIGNED_BYTE, 1);
    VOX_STORAGE_FORMAT(GL_R16I, GL_RED_INTEGER, GL_SHORT, 2);
    VOX_STORAGE_FORMAT(GL_R16UI, GL_RED_INTEGER, GL_UNSIGNED_SHORT, 2);
    VOX_STORAGE_FORMAT(GL_R32I, GL_RED_INTEGER, GL_INT, 4);
    VOX_STORAGE_FORMAT(GL_R32UI, GL_RED_INTEGER, GL_UNSIGNED_INT, 4);
    VOX_STORAGE_FORMAT(GL_RG8, GL_RG, GL_UNSIGNED_BYTE, 2);
    VOX_STORAGE_FORMAT(GL_RG8_SNORM, GL_RG, GL_BYTE, 2);
    VOX_STORAGE_FORMAT(0x822C /* RG16_EXT */, GL_RG, GL_UNSIGNED_SHORT, 4);
    VOX_STORAGE_FORMAT(0x8F99 /* RG16_SNORM_EXT */, GL_RG, GL_SHORT, 4);
    VOX_STORAGE_FORMAT(GL_RG16F, GL_RG, GL_HALF_FLOAT, 4);
    VOX_STORAGE_FORMAT(GL_RG32F, GL_RG, GL_FLOAT, 8);
    VOX_STORAGE_FORMAT(GL_RG8I, GL_RG_INTEGER, GL_BYTE, 2);
    VOX_STORAGE_FORMAT(GL_RG8UI, GL_RG_INTEGER, GL_UNSIGNED_BYTE, 2);
    VOX_STORAGE_FORMAT(GL_RG16I, GL_RG_INTEGER, GL_SHORT, 4);
    VOX_STORAGE_FORMAT(GL_RG16UI, GL_RG_INTEGER, GL_UNSIGNED_SHORT, 4);
    VOX_STORAGE_FORMAT(GL_RG32I, GL_RG_INTEGER, GL_INT, 8);
    VOX_STORAGE_FORMAT(GL_RG32UI, GL_RG_INTEGER, GL_UNSIGNED_INT, 8);
    VOX_STORAGE_FORMAT(GL_RGB8, GL_RGB, GL_UNSIGNED_BYTE, 3);
    VOX_STORAGE_FORMAT(GL_SRGB8, GL_RGB, GL_UNSIGNED_BYTE, 3);
    VOX_STORAGE_FORMAT(0x8054 /* RGB16_EXT */, GL_RGB, GL_UNSIGNED_SHORT, 6);
    VOX_STORAGE_FORMAT(0x8F9A /* RGB16_SNORM_EXT */, GL_RGB, GL_SHORT, 6);
    VOX_STORAGE_FORMAT(GL_RGB565, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, 2);
    VOX_STORAGE_FORMAT(GL_RGB8_SNORM, GL_RGB, GL_BYTE, 3);
    VOX_STORAGE_FORMAT(GL_R11F_G11F_B10F, GL_RGB, GL_UNSIGNED_INT_10F_11F_11F_REV, 4);
    VOX_STORAGE_FORMAT(GL_RGB9_E5, GL_RGB, GL_UNSIGNED_INT_5_9_9_9_REV, 4);
    VOX_STORAGE_FORMAT(GL_RGB16F, GL_RGB, GL_HALF_FLOAT, 6);
    VOX_STORAGE_FORMAT(GL_RGB32F, GL_RGB, GL_FLOAT, 12);
    VOX_STORAGE_FORMAT(GL_RGB8I, GL_RGB_INTEGER, GL_BYTE, 3);
    VOX_STORAGE_FORMAT(GL_RGB8UI, GL_RGB_INTEGER, GL_UNSIGNED_BYTE, 3);
    VOX_STORAGE_FORMAT(GL_RGB16I, GL_RGB_INTEGER, GL_SHORT, 6);
    VOX_STORAGE_FORMAT(GL_RGB16UI, GL_RGB_INTEGER, GL_UNSIGNED_SHORT, 6);
    VOX_STORAGE_FORMAT(GL_RGB32I, GL_RGB_INTEGER, GL_INT, 12);
    VOX_STORAGE_FORMAT(GL_RGB32UI, GL_RGB_INTEGER, GL_UNSIGNED_INT, 12);
    VOX_STORAGE_FORMAT(GL_RGBA8, GL_RGBA, GL_UNSIGNED_BYTE, 4);
    VOX_STORAGE_FORMAT(GL_SRGB8_ALPHA8, GL_RGBA, GL_UNSIGNED_BYTE, 4);
    VOX_STORAGE_FORMAT(0x805B /* RGBA16_EXT */, GL_RGBA, GL_UNSIGNED_SHORT, 8);
    VOX_STORAGE_FORMAT(0x8F9B /* RGBA16_SNORM_EXT */, GL_RGBA, GL_SHORT, 8);
    VOX_STORAGE_FORMAT(GL_RGBA8_SNORM, GL_RGBA, GL_BYTE, 4);
    VOX_STORAGE_FORMAT(GL_RGBA4, GL_RGBA, GL_UNSIGNED_SHORT_4_4_4_4, 2);
    VOX_STORAGE_FORMAT(GL_RGB5_A1, GL_RGBA, GL_UNSIGNED_SHORT_5_5_5_1, 2);
    VOX_STORAGE_FORMAT(GL_RGB10_A2, GL_RGBA, GL_UNSIGNED_INT_2_10_10_10_REV, 4);
    VOX_STORAGE_FORMAT(GL_RGBA16F, GL_RGBA, GL_HALF_FLOAT, 8);
    VOX_STORAGE_FORMAT(GL_RGBA32F, GL_RGBA, GL_FLOAT, 16);
    VOX_STORAGE_FORMAT(GL_RGBA8I, GL_RGBA_INTEGER, GL_BYTE, 4);
    VOX_STORAGE_FORMAT(GL_RGBA8UI, GL_RGBA_INTEGER, GL_UNSIGNED_BYTE, 4);
    VOX_STORAGE_FORMAT(GL_RGBA16I, GL_RGBA_INTEGER, GL_SHORT, 8);
    VOX_STORAGE_FORMAT(GL_RGBA16UI, GL_RGBA_INTEGER, GL_UNSIGNED_SHORT, 8);
    VOX_STORAGE_FORMAT(GL_RGBA32I, GL_RGBA_INTEGER, GL_INT, 16);
    VOX_STORAGE_FORMAT(GL_RGBA32UI, GL_RGBA_INTEGER, GL_UNSIGNED_INT, 16);
    VOX_STORAGE_FORMAT(GL_RGB10_A2UI, GL_RGBA_INTEGER, GL_UNSIGNED_INT_2_10_10_10_REV, 4);
    VOX_STORAGE_FORMAT(GL_DEPTH_COMPONENT16, GL_DEPTH_COMPONENT, GL_UNSIGNED_SHORT, 2);
    VOX_STORAGE_FORMAT(GL_DEPTH_COMPONENT24, GL_DEPTH_COMPONENT, GL_UNSIGNED_INT, 4);
    VOX_STORAGE_FORMAT(GL_DEPTH_COMPONENT32F, GL_DEPTH_COMPONENT, GL_FLOAT, 4);
    VOX_STORAGE_FORMAT(GL_DEPTH24_STENCIL8, GL_DEPTH_STENCIL, GL_UNSIGNED_INT_24_8, 4);
    VOX_STORAGE_FORMAT(GL_DEPTH32F_STENCIL8, GL_DEPTH_STENCIL, GL_FLOAT_32_UNSIGNED_INT_24_8_REV, 8);
#undef VOX_STORAGE_FORMAT
    case 0x9270: case 0x9271: /* R11 EAC, signed R11 EAC */
    case 0x9274: case 0x9275: /* RGB8 ETC2, sRGB8 ETC2 */
    case 0x9276: case 0x9277: /* ETC2 punch-through alpha */
    case 0x83F0: case 0x83F1: case 0x8C4C: case 0x8C4D: /* DXT1 */
    case 0x8DBB: case 0x8DBC: /* RGTC1 */
        return (VoxNativeStorageFormat){0, 0, 0, 8};
    case 0x9272: case 0x9273: /* RG11 EAC, signed RG11 EAC */
    case 0x9278: case 0x9279: /* RGBA8 ETC2 EAC, sRGB8 alpha8 ETC2 EAC */
    case 0x83F2: case 0x83F3: case 0x8C4E: case 0x8C4F: /* DXT3/5 */
    case 0x8DBD: case 0x8DBE: /* RGTC2 */
    case 0x8E8C: case 0x8E8D: case 0x8E8E: case 0x8E8F: /* BPTC */
        return (VoxNativeStorageFormat){0, 0, 0, 16};
    default: return (VoxNativeStorageFormat){0, 0, 0, 0};
    }
}

typedef struct {
    GLint buffer, alignment, row_length, image_height, skip_pixels, skip_rows, skip_images;
#if VOX_NATIVE_GL_DESKTOP
    GLint swap_bytes, lsb_first;
#endif
} VoxNativeStorageUnpack;

static VoxNativeStorageUnpack vox_native_storage_begin_unpack(void)
{
    VoxNativeStorageUnpack saved;
    glGetIntegerv(GL_PIXEL_UNPACK_BUFFER_BINDING, &saved.buffer);
    glGetIntegerv(GL_UNPACK_ALIGNMENT, &saved.alignment);
    glGetIntegerv(GL_UNPACK_ROW_LENGTH, &saved.row_length);
    glGetIntegerv(GL_UNPACK_IMAGE_HEIGHT, &saved.image_height);
    glGetIntegerv(GL_UNPACK_SKIP_PIXELS, &saved.skip_pixels);
    glGetIntegerv(GL_UNPACK_SKIP_ROWS, &saved.skip_rows);
    glGetIntegerv(GL_UNPACK_SKIP_IMAGES, &saved.skip_images);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
    glPixelStorei(GL_UNPACK_IMAGE_HEIGHT, 0);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);
    glPixelStorei(GL_UNPACK_SKIP_IMAGES, 0);
#if VOX_NATIVE_GL_DESKTOP
    glGetIntegerv(GL_UNPACK_SWAP_BYTES, &saved.swap_bytes);
    glGetIntegerv(GL_UNPACK_LSB_FIRST, &saved.lsb_first);
    glPixelStorei(GL_UNPACK_SWAP_BYTES, GL_FALSE);
    glPixelStorei(GL_UNPACK_LSB_FIRST, GL_FALSE);
#endif
    return saved;
}

static void vox_native_storage_end_unpack(VoxNativeStorageUnpack saved)
{
    glPixelStorei(GL_UNPACK_ALIGNMENT, saved.alignment);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, saved.row_length);
    glPixelStorei(GL_UNPACK_IMAGE_HEIGHT, saved.image_height);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, saved.skip_pixels);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, saved.skip_rows);
    glPixelStorei(GL_UNPACK_SKIP_IMAGES, saved.skip_images);
#if VOX_NATIVE_GL_DESKTOP
    glPixelStorei(GL_UNPACK_SWAP_BYTES, saved.swap_bytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, saved.lsb_first);
#endif
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, (GLuint)saved.buffer);
}

static int vox_native_storage_validate(GLenum target, GLint levels, GLsizei width,
    GLsizei height, GLsizei depth, int dimensions)
{
    if ((dimensions == 2 && target != GL_TEXTURE_2D && target != GL_TEXTURE_CUBE_MAP)
        || (dimensions == 3 && target != GL_TEXTURE_3D && target != GL_TEXTURE_2D_ARRAY)) {
        vox_native_gl_error(GL_INVALID_ENUM);
        return 0;
    }
    if (levels < 1 || width < 1 || height < 1 || depth < 1
        || (target == GL_TEXTURE_CUBE_MAP && width != height)) {
        vox_native_gl_error(GL_INVALID_VALUE);
        return 0;
    }
    GLint maximum_size = 0, maximum_layers = 0;
    glGetIntegerv(target == GL_TEXTURE_CUBE_MAP ? GL_MAX_CUBE_MAP_TEXTURE_SIZE
        : target == GL_TEXTURE_3D ? GL_MAX_3D_TEXTURE_SIZE : GL_MAX_TEXTURE_SIZE, &maximum_size);
    if (target == GL_TEXTURE_2D_ARRAY) glGetIntegerv(GL_MAX_ARRAY_TEXTURE_LAYERS, &maximum_layers);
    if (width > maximum_size || height > maximum_size
        || (target == GL_TEXTURE_3D && depth > maximum_size)
        || (target == GL_TEXTURE_2D_ARRAY && depth > maximum_layers)) {
        vox_native_gl_error(GL_INVALID_VALUE);
        return 0;
    }
    int largest = width > height ? width : height;
    if (target == GL_TEXTURE_3D && depth > largest) largest = depth;
    int maximum_levels = 1;
    while (largest > 1) { largest /= 2; ++maximum_levels; }
    if (levels > maximum_levels) {
        vox_native_gl_error(GL_INVALID_OPERATION);
        return 0;
    }
    return vox_native_texture_mutable(target);
}

/* Allocate a single zero row before changing the driver object. Each mip and
 * array layer is initialized without allocating a texture-sized host buffer. */
static void vox_native_tex_storage(GLenum target, GLint levels, GLenum internal_format,
    GLsizei width, GLsizei height, GLsizei depth, int dimensions)
{
    if (!vox_native_gl_current()) return;
    if (!vox_native_storage_validate(target, levels, width, height, depth, dimensions)) return;
    VoxNativeStorageFormat format = vox_native_storage_format(internal_format);
    if (!format.pixel_bytes && !format.block_bytes) {
        vox_native_gl_error(GL_INVALID_ENUM);
        return;
    }
    size_t elements = format.block_bytes ? ((size_t)width + 3) / 4 : (size_t)width;
    size_t element_bytes = format.block_bytes ? format.block_bytes : format.pixel_bytes;
    if (elements > SIZE_MAX / element_bytes) { vox_native_gl_error(GL_OUT_OF_MEMORY); return; }
    size_t row_bytes = elements * element_bytes;
    if (format.block_bytes && (row_bytes > INT_MAX
        || ((size_t)height + 3) / 4 > (size_t)INT_MAX / row_bytes
        || (size_t)depth > (size_t)INT_MAX / (row_bytes * (((size_t)height + 3) / 4)))) {
        vox_native_gl_error(GL_INVALID_VALUE);
        return;
    }
    void* zero = calloc(1, row_bytes);
    if (!zero) { vox_native_gl_error(GL_OUT_OF_MEMORY); return; }
    GLuint texture = vox_native_storage_binding(target);
#ifdef __APPLE__
    VoxNativeTextureStorage* record = calloc(1, sizeof(*record));
    if (!record) { free(zero); vox_native_gl_error(GL_OUT_OF_MEMORY); return; }
    record->texture = texture;
    record->levels = levels;
    glGetTexParameteriv(target, GL_TEXTURE_BASE_LEVEL, &record->base_level);
    glGetTexParameteriv(target, GL_TEXTURE_MAX_LEVEL, &record->max_level);
#endif
    vox_native_storage_preserve_errors();
    VoxNativeStorageUnpack unpack = vox_native_storage_begin_unpack();
    int allocated = 0, succeeded = vox_native_storage_error() == GL_NO_ERROR;
#ifndef __APPLE__
    if (succeeded) {
        if (dimensions == 2) glTexStorage2D(target, levels, internal_format, width, height);
        else glTexStorage3D(target, levels, internal_format, width, height, depth);
        succeeded = vox_native_storage_error() == GL_NO_ERROR;
        allocated = succeeded;
    }
#endif
    for (GLint level = 0; succeeded && level < levels; ++level) {
        int faces = target == GL_TEXTURE_CUBE_MAP ? 6 : 1;
        for (int face = 0; succeeded && face < faces; ++face) {
            GLenum image_target = faces == 6 ? GL_TEXTURE_CUBE_MAP_POSITIVE_X + (GLenum)face : target;
            size_t level_row_bytes = format.block_bytes
                ? (((size_t)width + 3) / 4) * format.block_bytes : (size_t)width * format.pixel_bytes;
#ifdef __APPLE__
            if (format.block_bytes) {
                GLsizei image_bytes = (GLsizei)(level_row_bytes * (((size_t)height + 3) / 4) * (size_t)depth);
                if (dimensions == 2)
                    glCompressedTexImage2D(image_target, level, internal_format, width, height, 0, image_bytes, NULL);
                else
                    glCompressedTexImage3D(image_target, level, internal_format, width, height, depth, 0, image_bytes, NULL);
            } else if (dimensions == 2) {
                glTexImage2D(image_target, level, internal_format, width, height, 0, format.format, format.type, NULL);
            } else {
                glTexImage3D(image_target, level, internal_format, width, height, depth, 0, format.format, format.type, NULL);
            }
            succeeded = vox_native_storage_error() == GL_NO_ERROR;
            if (!succeeded) break;
            allocated = 1;
#endif
            int row_step = format.block_bytes ? 4 : 1;
            for (int layer = 0; succeeded && layer < depth; ++layer) {
                for (int row = 0; succeeded && row < height;) {
                    int rows = height - row < row_step ? height - row : row_step;
                    if (format.block_bytes) {
                        if (dimensions == 2)
                            glCompressedTexSubImage2D(image_target, level, 0, row, width, rows,
                                internal_format, (GLsizei)level_row_bytes, zero);
                        else
                            glCompressedTexSubImage3D(image_target, level, 0, row, layer, width, rows, 1,
                                internal_format, (GLsizei)level_row_bytes, zero);
                    } else if (dimensions == 2) {
                        glTexSubImage2D(image_target, level, 0, row, width, 1, format.format, format.type, zero);
                    } else {
                        glTexSubImage3D(image_target, level, 0, row, layer, width, 1, 1, format.format, format.type, zero);
                    }
                    succeeded = vox_native_storage_error() == GL_NO_ERROR;
                    row += rows;
                }
            }
        }
        if (width > 1) width /= 2;
        if (height > 1) height /= 2;
        if (target == GL_TEXTURE_3D && depth > 1) depth /= 2;
    }
#ifdef __APPLE__
    /* Storage replaces the whole image array. Previously defined higher mips
     * must not remain attachable after the new immutable range is allocated. */
    if (succeeded) {
        GLint maximum = 0;
        glGetIntegerv(target == GL_TEXTURE_CUBE_MAP ? GL_MAX_CUBE_MAP_TEXTURE_SIZE
            : target == GL_TEXTURE_3D ? GL_MAX_3D_TEXTURE_SIZE : GL_MAX_TEXTURE_SIZE, &maximum);
        GLint maximum_levels = 1;
        while (maximum > 1) { maximum /= 2; ++maximum_levels; }
        for (GLint level = levels; succeeded && level < maximum_levels; ++level) {
            int faces = target == GL_TEXTURE_CUBE_MAP ? 6 : 1;
            for (int face = 0; succeeded && face < faces; ++face) {
                GLenum image_target = faces == 6 ? GL_TEXTURE_CUBE_MAP_POSITIVE_X + (GLenum)face : target;
                if (dimensions == 2)
                    glTexImage2D(image_target, level, GL_RGBA8, 0, 0, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
                else
                    glTexImage3D(image_target, level, GL_RGBA8, 0, 0, 0, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
                succeeded = vox_native_storage_error() == GL_NO_ERROR;
            }
        }
    }
#endif
    if (succeeded) {
        vox_native_texture_swizzle(target, internal_format);
        succeeded = vox_native_storage_error() == GL_NO_ERROR;
    }
    vox_native_storage_end_unpack(unpack);
    free(zero);
    if (!succeeded) {
        /* A deleted texture may remain attached to an unbound framebuffer.
         * Lose the context as well, so partially initialized images cannot be
         * observed through those retained attachments. */
        if (allocated) {
            glDeleteTextures(1, &texture);
            VoxEGLContext* context = vox_native_gl_current();
            if (context) context->failed = 1;
        }
#ifdef __APPLE__
        free(record);
#endif
        return;
    }
#ifdef __APPLE__
    VoxEGLContext* context = vox_native_gl_current();
    record->next = context->texture_storage;
    context->texture_storage = record;
    vox_native_storage_apply_levels(target, record);
#endif
}

static void vox_native_tex_storage_2d(GLenum target, GLint levels, GLenum format, GLsizei width, GLsizei height)
{
    vox_native_tex_storage(target, levels, format, width, height, 1, 2);
}

static void vox_native_tex_storage_3d(GLenum target, GLint levels, GLenum format,
    GLsizei width, GLsizei height, GLsizei depth)
{
    vox_native_tex_storage(target, levels, format, width, height, depth, 3);
}

static void vox_native_internalformat_parameter(GLenum target, GLenum format,
    GLenum pname, GLsizei capacity, GLint* result)
{
    if (capacity < 0 || (capacity && !result)) { vox_native_gl_error(GL_INVALID_VALUE); return; }
    if (target != GL_RENDERBUFFER || (pname != GL_NUM_SAMPLE_COUNTS && pname != GL_SAMPLES)) {
        vox_native_gl_error(GL_INVALID_ENUM);
        return;
    }
    if (!capacity) return;
#ifndef __APPLE__
    glGetInternalformativ(target, format, pname, capacity, result);
#else
    /* GL4.1 has no internalformat query. Probe the format itself instead of
     * returning fabricated powers of two derived from GL_MAX_SAMPLES. */
    vox_native_storage_preserve_errors();
    GLint original = 0, maximum = 0;
    glGetIntegerv(GL_RENDERBUFFER_BINDING, &original);
    glGetIntegerv(GL_MAX_SAMPLES, &maximum);
    if (maximum < 0 || (size_t)maximum > SIZE_MAX / sizeof(GLint)) {
        vox_native_gl_error(GL_OUT_OF_MEMORY);
        return;
    }
    GLint* samples = maximum ? calloc((size_t)maximum, sizeof(*samples)) : NULL;
    if (maximum && !samples) { vox_native_gl_error(GL_OUT_OF_MEMORY); return; }
    GLuint probe = 0;
    glGenRenderbuffers(1, &probe);
    glBindRenderbuffer(GL_RENDERBUFFER, probe);
    glRenderbufferStorage(GL_RENDERBUFFER, format, 1, 1);
    int succeeded = vox_native_storage_error() == GL_NO_ERROR;
    GLint count = 0;
    for (GLint requested = maximum; succeeded && requested > 0; --requested) {
        glRenderbufferStorageMultisample(GL_RENDERBUFFER, requested, format, 1, 1);
        GLenum error = glGetError();
        if (error == GL_INVALID_VALUE || error == GL_INVALID_OPERATION) continue;
        if (error != GL_NO_ERROR) {
            vox_native_gl_error(error);
            succeeded = 0;
            break;
        }
        GLint actual = 0;
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_SAMPLES, &actual);
        if (actual > 0 && (count == 0 || samples[count - 1] != actual)) samples[count++] = actual;
    }
    glBindRenderbuffer(GL_RENDERBUFFER, (GLuint)original);
    glDeleteRenderbuffers(1, &probe);
    if (succeeded) {
        if (pname == GL_NUM_SAMPLE_COUNTS) result[0] = count;
        else for (GLsizei i = 0; i < capacity && i < count; ++i) result[i] = samples[i];
    }
    free(samples);
#endif
}

static void vox_native_shader_precision(GLenum shader, GLenum precision, GLint* range, GLint* bits)
{
    if (!range || !bits) { vox_native_gl_error(GL_INVALID_VALUE); return; }
    range[0] = range[1] = *bits = 0;
    if ((shader != GL_VERTEX_SHADER && shader != GL_FRAGMENT_SHADER)
        || (precision != GL_LOW_FLOAT && precision != GL_MEDIUM_FLOAT && precision != GL_HIGH_FLOAT
            && precision != GL_LOW_INT && precision != GL_MEDIUM_INT && precision != GL_HIGH_INT)) {
        vox_native_gl_error(GL_INVALID_ENUM);
        return;
    }
    glGetShaderPrecisionFormat(shader, precision, range, bits);
}

#endif
