/* Bounded framebuffer reads for the native WebGL service.
 * Included after native_gl_bounds.h and native_gl_compat.h.
 * SPDX-License-Identifier: BSD-2-Clause
 */
#ifndef VOX_WEBGL_NATIVE_GL_READBACK_H
#define VOX_WEBGL_NATIVE_GL_READBACK_H

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* Deleted images can remain attached to unbound framebuffers after their names
 * have been reused. Snapshot only those retained attachments while the original
 * object is still live; unrelated objects that reuse its name remain usable. */
typedef struct VoxNativeReadbackAttachment {
    GLenum attachment, kind;
    GLuint name;
    GLint width, height;
    struct VoxNativeReadbackAttachment* next;
} VoxNativeReadbackAttachment;

typedef struct VoxNativeReadbackFramebuffer {
    GLuint name;
    VoxNativeReadbackAttachment* retained;
    struct VoxNativeReadbackFramebuffer* next;
} VoxNativeReadbackFramebuffer;

static VoxNativeReadbackFramebuffer* vox_native_readback_framebuffer(GLuint name)
{
    VoxEGLContext* context = vox_native_gl_current();
    VoxNativeReadbackFramebuffer* item = context ? context->readback_objects : NULL;
    for (; item; item = item->next)
        if (item->name == name) return item;
    return NULL;
}

static VoxNativeReadbackAttachment* vox_native_readback_attachment(
    VoxNativeReadbackFramebuffer* framebuffer, GLenum attachment)
{
    VoxNativeReadbackAttachment* item = framebuffer ? framebuffer->retained : NULL;
    for (; item; item = item->next)
        if (item->attachment == attachment) return item;
    return NULL;
}

static void vox_native_framebuffer_created(GLuint name)
{
    VoxEGLContext* context = vox_native_gl_current();
    if (!context || !name || vox_native_readback_framebuffer(name)) return;
    VoxNativeReadbackFramebuffer* item = calloc(1, sizeof(*item));
    if (!item) {
        vox_native_gl_error(GL_OUT_OF_MEMORY);
        context->failed = 1;
        return;
    }
    item->name = name;
    item->next = context->readback_objects;
    context->readback_objects = item;
}

static void vox_native_readback_free_attachments(VoxNativeReadbackFramebuffer* framebuffer)
{
    VoxNativeReadbackAttachment* item = framebuffer->retained;
    while (item) {
        VoxNativeReadbackAttachment* next = item->next;
        free(item);
        item = next;
    }
}

static void vox_native_framebuffer_deleted(GLuint name)
{
    VoxEGLContext* context = vox_native_gl_current();
    VoxNativeReadbackFramebuffer* previous = NULL;
    VoxNativeReadbackFramebuffer* item = context ? context->readback_objects : NULL;
    while (item) {
        if (item->name == name) {
            if (previous) previous->next = item->next;
            else context->readback_objects = item->next;
            vox_native_readback_free_attachments(item);
            free(item);
            return;
        }
        previous = item;
        item = item->next;
    }
}

/* Call only after a successful attachment operation. Depth-stencil attachment
 * operations change both independently queried attachment points. */
static void vox_native_framebuffer_attachment_changed(GLenum target, GLenum attachment)
{
    GLint name = 0;
    glGetIntegerv(target == GL_READ_FRAMEBUFFER ? GL_READ_FRAMEBUFFER_BINDING
        : GL_DRAW_FRAMEBUFFER_BINDING, &name);
    VoxNativeReadbackFramebuffer* framebuffer = vox_native_readback_framebuffer((GLuint)name);
    if (!framebuffer) return;
    VoxNativeReadbackAttachment* previous = NULL;
    VoxNativeReadbackAttachment* item = framebuffer->retained;
    while (item) {
        VoxNativeReadbackAttachment* next = item->next;
        if (item->attachment == attachment || (attachment == GL_DEPTH_STENCIL_ATTACHMENT
                && (item->attachment == GL_DEPTH_ATTACHMENT || item->attachment == GL_STENCIL_ATTACHMENT))) {
            if (previous) previous->next = next;
            else framebuffer->retained = next;
            free(item);
        } else previous = item;
        item = next;
    }
}

static void vox_native_readback_destroy(VoxEGLContext* context)
{
    VoxNativeReadbackFramebuffer* item = context ? context->readback_objects : NULL;
    while (item) {
        VoxNativeReadbackFramebuffer* next = item->next;
        vox_native_readback_free_attachments(item);
        free(item);
        item = next;
    }
    if (context) context->readback_objects = NULL;
}

static int vox_native_read_texture_size(GLuint texture, GLint level, GLenum face,
    GLint* width, GLint* height)
{
    static const GLenum targets[] = {
        GL_TEXTURE_2D, GL_TEXTURE_CUBE_MAP, GL_TEXTURE_3D, GL_TEXTURE_2D_ARRAY
    };
    if (!glIsTexture(texture)) {
        vox_native_gl_error(GL_INVALID_OPERATION);
        return 0;
    }
    for (unsigned i = 0; i < sizeof(targets) / sizeof(targets[0]); ++i) {
        GLenum target = targets[i];
        if (face && target != GL_TEXTURE_CUBE_MAP) continue;
        GLint previous = 0;
        glGetIntegerv(vox_native_storage_binding_name(target), &previous);
        if (vox_native_storage_error() != GL_NO_ERROR) return 0;
        glBindTexture(target, texture);
        GLenum error = glGetError();
        if (error != GL_NO_ERROR) {
            /* A texture's target is fixed when first bound. Wrong-target
             * probes have no side effects and must not become WebGL errors. */
            if (error == GL_INVALID_OPERATION && !face) continue;
            vox_native_gl_error(error);
            vox_native_storage_preserve_errors();
            return 0;
        }
        GLenum image = face ? face : target;
        if (target == GL_TEXTURE_CUBE_MAP && !face) image = GL_TEXTURE_CUBE_MAP_POSITIVE_X;
        glGetTexLevelParameteriv(image, level, GL_TEXTURE_WIDTH, width);
        glGetTexLevelParameteriv(image, level, GL_TEXTURE_HEIGHT, height);
        error = vox_native_storage_error();
        glBindTexture(target, (GLuint)previous);
        if (vox_native_storage_error() != GL_NO_ERROR) return 0;
        return error == GL_NO_ERROR;
    }
    vox_native_gl_error(GL_INVALID_OPERATION);
    return 0;
}

static int vox_native_read_renderbuffer_size(GLuint renderbuffer, GLint* width, GLint* height)
{
    if (!glIsRenderbuffer(renderbuffer)) { vox_native_gl_error(GL_INVALID_OPERATION); return 0; }
    GLint previous = 0;
    glGetIntegerv(GL_RENDERBUFFER_BINDING, &previous);
    glBindRenderbuffer(GL_RENDERBUFFER, renderbuffer);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, height);
    GLenum error = vox_native_storage_error();
    glBindRenderbuffer(GL_RENDERBUFFER, (GLuint)previous);
    return vox_native_storage_error() == GL_NO_ERROR && error == GL_NO_ERROR;
}

/* Service object kinds: 2 is renderbuffer, 3 is texture. This hook runs before
 * deletion, while binding the object name still refers to the attached image. */
static void vox_native_readback_object_deleted(int kind, GLuint name)
{
    VoxEGLContext* context = vox_native_gl_current();
    if (!context || !name || (kind != 2 && kind != 3)) return;
    if (!(kind == 3 ? glIsTexture(name) : glIsRenderbuffer(name))) return;
    vox_native_storage_preserve_errors();
    GLint previous = 0, colors = 0;
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &previous);
    glGetIntegerv(GL_MAX_COLOR_ATTACHMENTS, &colors);
    GLenum expected = kind == 3 ? GL_TEXTURE : GL_RENDERBUFFER;
    VoxNativeReadbackFramebuffer* framebuffer = context->readback_objects;
    for (; framebuffer; framebuffer = framebuffer->next) {
        if (!glIsFramebuffer(framebuffer->name)) continue;
        glBindFramebuffer(GL_READ_FRAMEBUFFER, framebuffer->name);
        for (GLint i = 0; i < colors + 2; ++i) {
            GLenum attachment = i < colors ? GL_COLOR_ATTACHMENT0 + (GLuint)i
                : i == colors ? GL_DEPTH_ATTACHMENT : GL_STENCIL_ATTACHMENT;
            /* A prior deletion snapshot belongs to an older object even when
             * its numeric name happens to match the object being deleted now. */
            if (vox_native_readback_attachment(framebuffer, attachment)) continue;
            GLint object_kind = GL_NONE, object_name = 0;
            glGetFramebufferAttachmentParameteriv(GL_READ_FRAMEBUFFER, attachment,
                GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE, &object_kind);
            if (vox_native_storage_error() != GL_NO_ERROR) goto failed;
            if ((GLenum)object_kind != expected) continue;
            glGetFramebufferAttachmentParameteriv(GL_READ_FRAMEBUFFER, attachment,
                GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME, &object_name);
            if (vox_native_storage_error() != GL_NO_ERROR) goto failed;
            if ((GLuint)object_name != name) continue;
            GLint width = 0, height = 0;
            if (expected == GL_TEXTURE) {
                GLint level = 0, face = 0;
                glGetFramebufferAttachmentParameteriv(GL_READ_FRAMEBUFFER, attachment,
                    GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL, &level);
                glGetFramebufferAttachmentParameteriv(GL_READ_FRAMEBUFFER, attachment,
                    GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE, &face);
                if (vox_native_storage_error() != GL_NO_ERROR
                    || !vox_native_read_texture_size(name, level, (GLenum)face, &width, &height)) goto failed;
            } else if (!vox_native_read_renderbuffer_size(name, &width, &height)) goto failed;
            VoxNativeReadbackAttachment* item = malloc(sizeof(*item));
            if (!item) { vox_native_gl_error(GL_OUT_OF_MEMORY); goto failed; }
            *item = (VoxNativeReadbackAttachment){attachment, expected, name, width, height, framebuffer->retained};
            framebuffer->retained = item;
        }
    }
    glBindFramebuffer(GL_READ_FRAMEBUFFER, (GLuint)previous);
    return;
failed:
    /* Incomplete bookkeeping must never permit a later out-of-bounds read. */
    context->failed = 1;
    glBindFramebuffer(GL_READ_FRAMEBUFFER, (GLuint)previous);
}

/* The effective framebuffer rectangle is the intersection of its attachments.
 * Query completeness before attempting to inspect any object. A native default
 * framebuffer is never exposed: Vox's drawing buffer is an owned framebuffer. */
static int vox_native_read_framebuffer_details(GLint* width, GLint* height,
    GLuint destination, GLint destination_level, GLenum destination_face)
{
    *width = *height = 0;
    vox_native_storage_preserve_errors();
    GLint framebuffer = 0, colors = 0;
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &framebuffer);
    GLenum status = glCheckFramebufferStatus(GL_READ_FRAMEBUFFER);
    if (vox_native_storage_error() != GL_NO_ERROR) return 0;
    if (!framebuffer || status != GL_FRAMEBUFFER_COMPLETE) {
        vox_native_gl_error(GL_INVALID_FRAMEBUFFER_OPERATION);
        return 0;
    }
    glGetIntegerv(GL_MAX_COLOR_ATTACHMENTS, &colors);
    if (vox_native_storage_error() != GL_NO_ERROR) return 0;
    VoxNativeReadbackFramebuffer* tracked = vox_native_readback_framebuffer((GLuint)framebuffer);
    int found = 0;
    for (GLint i = 0; i < colors + 2; ++i) {
        GLenum attachment = i < colors ? GL_COLOR_ATTACHMENT0 + (GLuint)i
            : i == colors ? GL_DEPTH_ATTACHMENT : GL_STENCIL_ATTACHMENT;
        GLint kind = GL_NONE, name = 0, image_width = 0, image_height = 0;
        glGetFramebufferAttachmentParameteriv(GL_READ_FRAMEBUFFER, attachment,
            GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE, &kind);
        if (vox_native_storage_error() != GL_NO_ERROR) return 0;
        if (kind == GL_NONE) continue;
        glGetFramebufferAttachmentParameteriv(GL_READ_FRAMEBUFFER, attachment,
            GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME, &name);
        if (vox_native_storage_error() != GL_NO_ERROR) return 0;
        VoxNativeReadbackAttachment* retained = vox_native_readback_attachment(tracked, attachment);
        if (retained) {
            if (retained->kind != (GLenum)kind || retained->name != (GLuint)name) {
                vox_native_gl_error(GL_INVALID_OPERATION);
                return 0;
            }
            image_width = retained->width;
            image_height = retained->height;
        } else if (kind == GL_RENDERBUFFER) {
            if (!vox_native_read_renderbuffer_size((GLuint)name, &image_width, &image_height)) return 0;
        } else if (kind == GL_TEXTURE) {
            GLint level = 0, face = 0;
            glGetFramebufferAttachmentParameteriv(GL_READ_FRAMEBUFFER, attachment,
                GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL, &level);
            glGetFramebufferAttachmentParameteriv(GL_READ_FRAMEBUFFER, attachment,
                GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE, &face);
            if (vox_native_storage_error() != GL_NO_ERROR) return 0;
            if (destination && (GLuint)name == destination && level == destination_level
                && (!face || !destination_face || (GLenum)face == destination_face)) {
                vox_native_gl_error(GL_INVALID_OPERATION);
                return 0;
            }
            if (!vox_native_read_texture_size((GLuint)name, level, (GLenum)face,
                    &image_width, &image_height)) return 0;
        } else {
            vox_native_gl_error(GL_INVALID_OPERATION);
            return 0;
        }
        if (!found || image_width < *width) *width = image_width;
        if (!found || image_height < *height) *height = image_height;
        found = 1;
    }
    if (!found || *width <= 0 || *height <= 0) {
        vox_native_gl_error(GL_INVALID_FRAMEBUFFER_OPERATION);
        return 0;
    }
    return 1;
}

static int vox_native_read_framebuffer_size(GLint* width, GLint* height)
{
    return vox_native_read_framebuffer_details(width, height, 0, 0, 0);
}

typedef struct {
    GLint x, y;
    GLsizei width, height;
    size_t skip_x, skip_y;
} VoxNativeReadClip;

static VoxNativeReadClip vox_native_read_clip(GLint x, GLint y, GLsizei width,
    GLsizei height, GLint framebuffer_width, GLint framebuffer_height)
{
    int64_t left = x < 0 ? 0 : x, bottom = y < 0 ? 0 : y;
    int64_t right = (int64_t)x + width, top = (int64_t)y + height;
    if (right > framebuffer_width) right = framebuffer_width;
    if (top > framebuffer_height) top = framebuffer_height;
    if (right <= left || top <= bottom) return (VoxNativeReadClip){0};
    return (VoxNativeReadClip){(GLint)left, (GLint)bottom,
        (GLsizei)(right - left), (GLsizei)(top - bottom),
        (size_t)(left - x), (size_t)(bottom - y)};
}

typedef struct {
    GLint buffer, alignment, row_length, skip_pixels, skip_rows;
#if VOX_NATIVE_GL_DESKTOP
    GLint swap_bytes, lsb_first;
#endif
} VoxNativeReadPack;

static VoxNativeReadPack vox_native_read_begin_pack(int native_values)
{
    VoxNativeReadPack saved;
    glGetIntegerv(GL_PIXEL_PACK_BUFFER_BINDING, &saved.buffer);
    glGetIntegerv(GL_PACK_ALIGNMENT, &saved.alignment);
    glGetIntegerv(GL_PACK_ROW_LENGTH, &saved.row_length);
    glGetIntegerv(GL_PACK_SKIP_PIXELS, &saved.skip_pixels);
    glGetIntegerv(GL_PACK_SKIP_ROWS, &saved.skip_rows);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    glPixelStorei(GL_PACK_ROW_LENGTH, 0);
    glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
    glPixelStorei(GL_PACK_SKIP_ROWS, 0);
#if VOX_NATIVE_GL_DESKTOP
    glGetIntegerv(GL_PACK_SWAP_BYTES, &saved.swap_bytes);
    glGetIntegerv(GL_PACK_LSB_FIRST, &saved.lsb_first);
    if (native_values) {
        glPixelStorei(GL_PACK_SWAP_BYTES, GL_FALSE);
        glPixelStorei(GL_PACK_LSB_FIRST, GL_FALSE);
    }
#else
    (void)native_values;
#endif
    return saved;
}

static void vox_native_read_end_pack(VoxNativeReadPack saved)
{
    glPixelStorei(GL_PACK_ALIGNMENT, saved.alignment);
    glPixelStorei(GL_PACK_ROW_LENGTH, saved.row_length);
    glPixelStorei(GL_PACK_SKIP_PIXELS, saved.skip_pixels);
    glPixelStorei(GL_PACK_SKIP_ROWS, saved.skip_rows);
#if VOX_NATIVE_GL_DESKTOP
    glPixelStorei(GL_PACK_SWAP_BYTES, saved.swap_bytes);
    glPixelStorei(GL_PACK_LSB_FIRST, saved.lsb_first);
#endif
    glBindBuffer(GL_PIXEL_PACK_BUFFER, (GLuint)saved.buffer);
}

/* Preserve skipped bytes, row padding, and pixels outside the source rectangle.
 * One native row is first read into owned memory, so an invalid format/type or
 * integer component class cannot change the caller's destination. */
static int vox_native_read_pixels_impl(GLint x, GLint y, GLsizei width, GLsizei height,
    GLenum format, GLenum type, size_t capacity, void* data, size_t* written)
{
    *written = 0;
    GLint buffer = 0;
    glGetIntegerv(GL_PIXEL_PACK_BUFFER_BINDING, &buffer);
    if (buffer) { vox_native_gl_error(GL_INVALID_OPERATION); return 0; }
    size_t extent = 0;
    if (!vox_native_pixel_extent(1, 2, width, height, 1, format, type, &extent)) return 0;
    if (extent > capacity || (extent && !data)) {
        vox_native_gl_error(GL_INVALID_OPERATION);
        return 0;
    }
    GLint framebuffer_width = 0, framebuffer_height = 0;
    if (!vox_native_read_framebuffer_size(&framebuffer_width, &framebuffer_height)) return 0;
    VoxNativeReadClip clip = vox_native_read_clip(x, y, width, height,
        framebuffer_width, framebuffer_height);
    size_t pixel = vox_native_pixel_size(format, type), row_bytes;
    if (!vox_native_size_mul((size_t)(clip.width ? clip.width : 1), pixel, &row_bytes)) {
        vox_native_gl_error(GL_OUT_OF_MEMORY);
        return 0;
    }
    /* Some packed representations have unused bits; begin with known bytes
     * even if the native conversion leaves those bits untouched. */
    void* row = calloc(1, row_bytes);
    if (!row) { vox_native_gl_error(GL_OUT_OF_MEMORY); return 0; }
    VoxNativeReadPack saved = vox_native_read_begin_pack(0);
    if (!width || !height) {
        glReadPixels(0, 0, 0, 0, format, vox_native_pixel_type(type), row);
        int success = vox_native_storage_error() == GL_NO_ERROR;
        vox_native_read_end_pack(saved);
        free(row);
        return success;
    }
    size_t stride = 0, start = 0, value = 0;
    if (!vox_native_size_mul((size_t)(saved.row_length ? saved.row_length : width), pixel, &stride)
        || !vox_native_size_add(stride, (size_t)saved.alignment - 1, &stride)) goto overflow;
    stride &= ~((size_t)saved.alignment - 1);
    if (!vox_native_size_add((size_t)saved.skip_rows, clip.skip_y, &value)
        || !vox_native_size_mul(value, stride, &start)
        || !vox_native_size_add((size_t)saved.skip_pixels, clip.skip_x, &value)
        || !vox_native_size_mul(value, pixel, &value)
        || !vox_native_size_add(start, value, &start)) goto overflow;
    if (!clip.width || !clip.height) {
        /* Validate the source/component class even for a wholly clipped read. */
        glReadPixels(0, 0, 1, 1, format, vox_native_pixel_type(type), row);
        if (vox_native_storage_error() != GL_NO_ERROR) goto failed;
    } else {
        for (GLint i = 0; i < clip.height; ++i) {
            glReadPixels(clip.x, clip.y + i, clip.width, 1,
                format, vox_native_pixel_type(type), row);
            if (vox_native_storage_error() != GL_NO_ERROR) goto failed;
            memcpy((unsigned char*)data + start + (size_t)i * stride, row, row_bytes);
        }
    }
    vox_native_read_end_pack(saved);
    free(row);
    *written = extent;
    return 1;
overflow:
    vox_native_gl_error(GL_INVALID_OPERATION);
failed:
    vox_native_read_end_pack(saved);
    free(row);
    return 0;
}

static int vox_native_read_pixels(GLint x, GLint y, GLsizei width, GLsizei height,
    GLenum format, GLenum type, int capacity, void* data)
{
    if (capacity < 0) { vox_native_gl_error(GL_INVALID_VALUE); return 0; }
    size_t written = 0;
    if (!vox_native_read_pixels_impl(x, y, width, height, format, type,
            (size_t)capacity, data, &written)) return 0;
    return (int)written;
}

static void vox_native_read_pixels_to_buffer(GLint x, GLint y, GLsizei width,
    GLsizei height, GLenum format, GLenum type, int64_t offset)
{
    GLint buffer = 0;
    glGetIntegerv(GL_PIXEL_PACK_BUFFER_BINDING, &buffer);
    if (!buffer || offset < 0 || (uint64_t)offset > (uint64_t)PTRDIFF_MAX) {
        vox_native_gl_error(GL_INVALID_OPERATION);
        return;
    }
    size_t extent = 0;
    if (!vox_native_pixel_extent(1, 2, width, height, 1, format, type, &extent)
        || !vox_native_buffer_extent(GL_PIXEL_PACK_BUFFER, (size_t)offset, extent)) return;
    size_t alignment = 1;
    switch (type) {
    case GL_SHORT: case GL_UNSIGNED_SHORT: case GL_HALF_FLOAT: case 0x8D61:
    case GL_UNSIGNED_SHORT_5_6_5: case GL_UNSIGNED_SHORT_4_4_4_4: case GL_UNSIGNED_SHORT_5_5_5_1:
        alignment = 2; break;
    case GL_INT: case GL_UNSIGNED_INT: case GL_FLOAT:
    case GL_UNSIGNED_INT_2_10_10_10_REV: case GL_UNSIGNED_INT_10F_11F_11F_REV:
    case GL_UNSIGNED_INT_5_9_9_9_REV: case GL_UNSIGNED_INT_24_8:
        alignment = 4; break;
    case GL_FLOAT_32_UNSIGNED_INT_24_8_REV: alignment = 8; break;
    }
    if ((uint64_t)offset % alignment) { vox_native_gl_error(GL_INVALID_OPERATION); return; }
    if (extent > (size_t)PTRDIFF_MAX) { vox_native_gl_error(GL_INVALID_OPERATION); return; }
    vox_native_storage_preserve_errors();
    void* mapped = NULL;
    if (extent) {
        mapped = glMapBufferRange(GL_PIXEL_PACK_BUFFER, (GLintptr)offset,
            (GLsizeiptr)extent, GL_MAP_WRITE_BIT);
        if (vox_native_storage_error() != GL_NO_ERROR) return;
        if (!mapped) { vox_native_gl_error(GL_OUT_OF_MEMORY); return; }
    }
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
    size_t written = 0;
    vox_native_read_pixels_impl(x, y, width, height, format, type, extent, mapped, &written);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, (GLuint)buffer);
    if (extent && !glUnmapBuffer(GL_PIXEL_PACK_BUFFER)) {
        /* A failed unmap leaves the buffer contents undefined. Do not permit
         * subsequent WebGL commands to read those contents. */
        vox_native_gl_error(GL_INVALID_OPERATION);
        vox_native_gl_current()->failed = 1;
    }
}

static int vox_native_copy_target(GLenum target, GLint level)
{
    if (target != GL_TEXTURE_2D && (target < GL_TEXTURE_CUBE_MAP_POSITIVE_X
            || target > GL_TEXTURE_CUBE_MAP_NEGATIVE_Z)) {
        vox_native_gl_error(GL_INVALID_ENUM);
        return 0;
    }
    GLint maximum = 0;
    glGetIntegerv(target == GL_TEXTURE_2D ? GL_MAX_TEXTURE_SIZE : GL_MAX_CUBE_MAP_TEXTURE_SIZE, &maximum);
    GLint maximum_level = 0;
    for (GLint size = maximum; size > 1; size /= 2) ++maximum_level;
    if (level < 0 || level > maximum_level) {
        vox_native_gl_error(GL_INVALID_VALUE);
        return 0;
    }
    if (!vox_native_storage_binding(target)) {
        vox_native_gl_error(GL_INVALID_OPERATION);
        return 0;
    }
    return 1;
}

static VoxNativeStorageFormat vox_native_copy_format(GLenum format)
{
    switch (format) {
    case GL_RED: return (VoxNativeStorageFormat){GL_RED, GL_UNSIGNED_BYTE, 1, 0};
    case GL_RG: return (VoxNativeStorageFormat){GL_RG, GL_UNSIGNED_BYTE, 2, 0};
    case GL_RGB: return (VoxNativeStorageFormat){GL_RGB, GL_UNSIGNED_BYTE, 3, 0};
    case GL_RGBA: return (VoxNativeStorageFormat){GL_RGBA, GL_UNSIGNED_BYTE, 4, 0};
    default: return vox_native_storage_format(format);
    }
}

/* Ask the native driver to validate the copy's format against the actual read
 * attachment before redefining the caller's texture. The probe reads one known
 * in-bounds pixel and is never visible to WebGL. */
static int vox_native_copy_probe(GLenum target, GLenum format, GLenum* actual_format)
{
    GLenum binding_target = vox_native_storage_target(target);
    GLuint previous = vox_native_storage_binding(target), temporary = 0;
    vox_native_storage_preserve_errors();
    glGenTextures(1, &temporary);
    if (vox_native_storage_error() != GL_NO_ERROR) return 0;
    if (!temporary) { vox_native_gl_error(GL_OUT_OF_MEMORY); return 0; }
    glBindTexture(binding_target, temporary);
    glCopyTexImage2D(target, 0, format, 0, 0, 1, 1, 0);
    GLenum error = vox_native_storage_error();
    GLint actual = 0;
    if (error == GL_NO_ERROR) {
        glGetTexLevelParameteriv(target, 0, GL_TEXTURE_INTERNAL_FORMAT, &actual);
        error = vox_native_storage_error();
    }
    glBindTexture(binding_target, previous);
    glDeleteTextures(1, &temporary);
    if (vox_native_storage_error() != GL_NO_ERROR) return 0;
    if (error != GL_NO_ERROR) return 0;
    *actual_format = (GLenum)actual;
    return 1;
}

/* Desktop red/rg textures implement the legacy alpha/luminance formats using
 * a texture swizzle. Copying these formats requires source A or source R/A,
 * whereas native red/rg copies would incorrectly select source R or R/G. */
static GLenum vox_native_copy_legacy_format(GLenum target)
{
    GLint swizzle[4] = {0};
    glGetTexParameteriv(vox_native_storage_target(target), GL_TEXTURE_SWIZZLE_RGBA, swizzle);
    if (swizzle[0] == GL_ZERO && swizzle[1] == GL_ZERO && swizzle[2] == GL_ZERO && swizzle[3] == GL_RED)
        return GL_ALPHA;
    if (swizzle[0] == GL_RED && swizzle[1] == GL_RED && swizzle[2] == GL_RED && swizzle[3] == GL_GREEN)
        return GL_LUMINANCE_ALPHA;
    return 0;
}

static int vox_native_copy_clipped(GLenum target, GLint level, GLint x_offset,
    GLint y_offset, VoxNativeReadClip clip, GLenum legacy)
{
    if (!clip.width || !clip.height) {
        /* A zero-size native call still validates the source/destination class. */
        glCopyTexSubImage2D(target, level, x_offset, y_offset, 0, 0, 0, 0);
        return vox_native_storage_error() == GL_NO_ERROR;
    }
    GLint destination_x = x_offset + (GLint)clip.skip_x;
    GLint destination_y = y_offset + (GLint)clip.skip_y;
    if (!legacy) {
        glCopyTexSubImage2D(target, level, destination_x, destination_y,
            clip.x, clip.y, clip.width, clip.height);
        return vox_native_storage_error() == GL_NO_ERROR;
    }
    size_t bytes = 0;
    if (!vox_native_size_mul((size_t)clip.width, 4 * sizeof(GLfloat), &bytes)) {
        vox_native_gl_error(GL_OUT_OF_MEMORY);
        return 0;
    }
    GLfloat* row = calloc(1, bytes);
    if (!row) { vox_native_gl_error(GL_OUT_OF_MEMORY); return 0; }
    VoxNativeReadPack pack = vox_native_read_begin_pack(1);
    VoxNativeStorageUnpack unpack = vox_native_storage_begin_unpack();
    int success = 1;
    for (GLint y = 0; y < clip.height; ++y) {
        glReadPixels(clip.x, clip.y + y, clip.width, 1, GL_RGBA, GL_FLOAT, row);
        if (vox_native_storage_error() != GL_NO_ERROR) { success = 0; break; }
        if (legacy == GL_ALPHA) {
            for (GLint x = 0; x < clip.width; ++x) row[x] = row[(size_t)x * 4 + 3];
        } else {
            for (GLint x = 0; x < clip.width; ++x) {
                row[(size_t)x * 2] = row[(size_t)x * 4];
                row[(size_t)x * 2 + 1] = row[(size_t)x * 4 + 3];
            }
        }
        glTexSubImage2D(target, level, destination_x, destination_y + y, clip.width, 1,
            legacy == GL_ALPHA ? GL_RED : GL_RG, GL_FLOAT, row);
        if (vox_native_storage_error() != GL_NO_ERROR) { success = 0; break; }
    }
    vox_native_storage_end_unpack(unpack);
    vox_native_read_end_pack(pack);
    free(row);
    return success;
}

static void vox_native_copy_tex_image_2d(GLenum target, GLint level, GLenum format,
    GLint x, GLint y, GLsizei width, GLsizei height, GLint border)
{
    if (width < 0 || height < 0 || border != 0) {
        vox_native_gl_error(GL_INVALID_VALUE);
        return;
    }
    vox_native_storage_preserve_errors();
    if (!vox_native_copy_target(target, level) || !vox_native_texture_mutable(target)) return;
    GLint maximum = 0;
    glGetIntegerv(target == GL_TEXTURE_2D ? GL_MAX_TEXTURE_SIZE : GL_MAX_CUBE_MAP_TEXTURE_SIZE, &maximum);
    maximum >>= level;
    if (width > maximum || height > maximum || (target != GL_TEXTURE_2D && width != height)) {
        vox_native_gl_error(GL_INVALID_VALUE);
        return;
    }
    GLint framebuffer_width = 0, framebuffer_height = 0;
    if (!vox_native_read_framebuffer_details(&framebuffer_width, &framebuffer_height,
            vox_native_storage_binding(target), level, target == GL_TEXTURE_2D ? 0 : target)) return;
    GLenum actual_format = 0;
    if (!vox_native_copy_probe(target, vox_native_texture_format(format, GL_UNSIGNED_BYTE), &actual_format)) return;
    VoxNativeStorageFormat storage = vox_native_copy_format(actual_format);
    if (!storage.pixel_bytes || storage.block_bytes) { vox_native_gl_error(GL_INVALID_ENUM); return; }
    size_t bytes = 0;
    if (!vox_native_size_mul((size_t)width, storage.pixel_bytes, &bytes)) {
        vox_native_gl_error(GL_OUT_OF_MEMORY);
        return;
    }
    void* zero = calloc(1, bytes ? bytes : 1);
    if (!zero) { vox_native_gl_error(GL_OUT_OF_MEMORY); return; }
    VoxNativeStorageUnpack unpack = vox_native_storage_begin_unpack();
    glTexImage2D(target, level, (GLint)actual_format, width, height, 0,
        storage.format, storage.type, NULL);
    if (vox_native_storage_error() != GL_NO_ERROR) {
        vox_native_storage_end_unpack(unpack);
        free(zero);
        return;
    }
    int initialized = 1;
    if (width) {
        for (GLint row = 0; row < height; ++row) {
            glTexSubImage2D(target, level, 0, row, width, 1, storage.format, storage.type, zero);
            if (vox_native_storage_error() != GL_NO_ERROR) { initialized = 0; break; }
        }
    }
    vox_native_texture_swizzle(target, format);
    if (vox_native_storage_error() != GL_NO_ERROR) initialized = 0;
    vox_native_storage_end_unpack(unpack);
    free(zero);
    if (!initialized) {
        vox_native_gl_current()->failed = 1;
        return;
    }
    VoxNativeReadClip clip = vox_native_read_clip(x, y, width, height,
        framebuffer_width, framebuffer_height);
    vox_native_copy_clipped(target, level, 0, 0, clip,
        format == GL_ALPHA || format == GL_LUMINANCE_ALPHA ? format : 0);
}

static void vox_native_copy_tex_sub_image_2d(GLenum target, GLint level,
    GLint x_offset, GLint y_offset, GLint x, GLint y, GLsizei width, GLsizei height)
{
    if (width < 0 || height < 0 || x_offset < 0 || y_offset < 0) {
        vox_native_gl_error(GL_INVALID_VALUE);
        return;
    }
    vox_native_storage_preserve_errors();
    if (!vox_native_copy_target(target, level)) return;
    GLint texture_width = 0, texture_height = 0, compressed = 0;
    glGetTexLevelParameteriv(target, level, GL_TEXTURE_WIDTH, &texture_width);
    glGetTexLevelParameteriv(target, level, GL_TEXTURE_HEIGHT, &texture_height);
    glGetTexLevelParameteriv(target, level, GL_TEXTURE_COMPRESSED, &compressed);
    if (vox_native_storage_error() != GL_NO_ERROR) return;
    if ((int64_t)x_offset + width > texture_width || (int64_t)y_offset + height > texture_height) {
        vox_native_gl_error(GL_INVALID_VALUE);
        return;
    }
    if (compressed) { vox_native_gl_error(GL_INVALID_OPERATION); return; }
    GLint framebuffer_width = 0, framebuffer_height = 0;
    if (!vox_native_read_framebuffer_details(&framebuffer_width, &framebuffer_height,
            vox_native_storage_binding(target), level, target == GL_TEXTURE_2D ? 0 : target)) return;
    VoxNativeReadClip clip = vox_native_read_clip(x, y, width, height,
        framebuffer_width, framebuffer_height);
    GLenum legacy = vox_native_copy_legacy_format(target);
    if (vox_native_storage_error() != GL_NO_ERROR) return;
    vox_native_copy_clipped(target, level, x_offset, y_offset, clip, legacy);
}

#endif
