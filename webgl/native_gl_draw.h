// Validate driver buffer reads before submitting native WebGL draw calls.
// SPDX-License-Identifier: BSD-2-Clause
#ifndef VOX_WEBGL_NATIVE_GL_DRAW_H
#define VOX_WEBGL_NATIVE_GL_DRAW_H
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static int vox_native_attribute_columns(GLenum type)
{
    switch (type) {
    case GL_FLOAT: case GL_FLOAT_VEC2: case GL_FLOAT_VEC3: case GL_FLOAT_VEC4:
    case GL_INT: case GL_INT_VEC2: case GL_INT_VEC3: case GL_INT_VEC4:
    case GL_UNSIGNED_INT: case GL_UNSIGNED_INT_VEC2:
    case GL_UNSIGNED_INT_VEC3: case GL_UNSIGNED_INT_VEC4: return 1;
    case GL_FLOAT_MAT2: case GL_FLOAT_MAT2x3: case GL_FLOAT_MAT2x4: return 2;
    case GL_FLOAT_MAT3: case GL_FLOAT_MAT3x2: case GL_FLOAT_MAT3x4: return 3;
    case GL_FLOAT_MAT4: case GL_FLOAT_MAT4x2: case GL_FLOAT_MAT4x3: return 4;
    default: return 0;
    }
}

static size_t vox_native_attribute_bytes(GLint components, GLenum type)
{
    // Desktop GL also accepts BGRA as the four-component size spelling.
    if (components == 0x80E1) components = 4;
    if (components < 1 || components > 4) return 0;
    switch (type) {
    case GL_BYTE: case GL_UNSIGNED_BYTE: return (size_t)components;
    case GL_SHORT: case GL_UNSIGNED_SHORT: case GL_HALF_FLOAT: return (size_t)components * 2;
    case GL_INT: case GL_UNSIGNED_INT: case GL_FLOAT:
    case 0x140C /* GL_FIXED */: return (size_t)components * 4;
    case 0x140A /* GL_DOUBLE */: return (size_t)components * 8;
    case 0x8D9F /* GL_INT_2_10_10_10_REV */:
    case GL_UNSIGNED_INT_2_10_10_10_REV: return components == 4 ? 4 : 0;
    case GL_UNSIGNED_INT_10F_11F_11F_REV: return components == 3 ? 4 : 0;
    default: return 0;
    }
}

// Desktop GL leaves reads from absent/undersized uniform-block bindings
// undefined. Check both the indexed range and its current buffer allocation;
// BufferData may have resized the allocation since BindBufferRange.
static int vox_native_uniform_block_bounds(GLuint program)
{
    GLint blocks = 0;
    glGetProgramiv(program, GL_ACTIVE_UNIFORM_BLOCKS, &blocks);
    if (blocks == 0) return 1;
    if (blocks < 0) { vox_native_gl_error(GL_INVALID_OPERATION); return 0; }

    GLint original = 0, maximum = 0;
    glGetIntegerv(GL_UNIFORM_BUFFER_BINDING, &original);
    glGetIntegerv(GL_MAX_UNIFORM_BUFFER_BINDINGS, &maximum);
    int valid = maximum > 0;
    for (GLint block = 0; valid && block < blocks; ++block) {
        GLint binding = -1, required = -1;
        glGetActiveUniformBlockiv(program, (GLuint)block, GL_UNIFORM_BLOCK_BINDING, &binding);
        glGetActiveUniformBlockiv(program, (GLuint)block, GL_UNIFORM_BLOCK_DATA_SIZE, &required);
        if (binding < 0 || binding >= maximum || required < 0) {
            valid = 0;
            break;
        }

        GLint buffer = 0;
        GLint64 start = -1, range = -1, allocation = 0;
        glGetIntegeri_v(GL_UNIFORM_BUFFER_BINDING, (GLuint)binding, &buffer);
        if (!buffer) { valid = 0; break; }
        glGetInteger64i_v(GL_UNIFORM_BUFFER_START, (GLuint)binding, &start);
        glGetInteger64i_v(GL_UNIFORM_BUFFER_SIZE, (GLuint)binding, &range);
        if (start < 0 || range < 0) { valid = 0; break; }

        glBindBuffer(GL_UNIFORM_BUFFER, (GLuint)buffer);
        glGetBufferParameteri64v(GL_UNIFORM_BUFFER, GL_BUFFER_SIZE, &allocation);
        GLint mapped = GL_FALSE;
        glGetBufferParameteriv(GL_UNIFORM_BUFFER, GL_BUFFER_MAPPED, &mapped);
        if (mapped || allocation < 0 || start > allocation) {
            valid = 0;
            break;
        }
        // BindBufferBase has no explicitly specified range and may report
        // SIZE=0. A zero-sized BindBufferRange is invalid, so only Base can
        // use this spelling; its extent follows subsequent BufferData calls.
        if (range == 0 && start == 0) range = allocation;
        if (range < required || range > allocation - start) valid = 0;
    }
    glBindBuffer(GL_UNIFORM_BUFFER, (GLuint)original);
    if (!valid) vox_native_gl_error(GL_INVALID_OPERATION);
    return valid;
}

static int vox_native_active_attributes(unsigned char** active, GLint* limit)
{
    *active = NULL;
    *limit = 0;
    GLint program = 0, linked = 0, count = 0, capacity = 0;
    glGetIntegerv(GL_CURRENT_PROGRAM, &program);
    if (!program) { vox_native_gl_error(GL_INVALID_OPERATION); return 0; }
    glGetProgramiv((GLuint)program, GL_LINK_STATUS, &linked);
    if (!linked) { vox_native_gl_error(GL_INVALID_OPERATION); return 0; }
    if (!vox_native_uniform_block_bounds((GLuint)program)) return 0;
    glGetProgramiv((GLuint)program, GL_ACTIVE_ATTRIBUTES, &count);
    if (!count) return 1;
    glGetProgramiv((GLuint)program, GL_ACTIVE_ATTRIBUTE_MAX_LENGTH, &capacity);
    glGetIntegerv(GL_MAX_VERTEX_ATTRIBS, limit);
    if (count < 0 || capacity <= 0 || *limit <= 0) {
        vox_native_gl_error(GL_INVALID_OPERATION);
        return 0;
    }
    unsigned char* result = calloc((size_t)*limit, 1);
    char* name = malloc((size_t)capacity);
    if (!result || !name) {
        free(result);
        free(name);
        vox_native_gl_error(GL_OUT_OF_MEMORY);
        return 0;
    }
    for (GLint index = 0; index < count; ++index) {
        GLint size = 0;
        GLenum type = 0;
        name[0] = name[capacity - 1] = '\0';
        glGetActiveAttrib((GLuint)program, (GLuint)index, capacity, NULL, &size, &type, name);
        GLint location = glGetAttribLocation((GLuint)program, name);
        if (location < 0) continue;
        int columns = vox_native_attribute_columns(type);
        if (!columns || size < 1 || location >= *limit
            || (uint64_t)size * (unsigned)columns > (uint64_t)(*limit - location)) {
            free(result);
            free(name);
            vox_native_gl_error(GL_INVALID_OPERATION);
            return 0;
        }
        for (GLint slot = 0; slot < size * columns; ++slot)
            result[location + slot] = 1;
    }
    free(name);
    *active = result;
    return 1;
}

static int vox_native_attribute_extent(GLuint attribute, size_t last_vertex, int instances)
{
    GLint enabled = 0;
    glGetVertexAttribiv(attribute, GL_VERTEX_ATTRIB_ARRAY_ENABLED, &enabled);
    if (!enabled) return 1;
    GLint buffer = 0, components = 0, type = 0, stride = 0, divisor = 0;
    void* pointer = NULL;
    glGetVertexAttribiv(attribute, GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING, &buffer);
    glGetVertexAttribiv(attribute, GL_VERTEX_ATTRIB_ARRAY_SIZE, &components);
    glGetVertexAttribiv(attribute, GL_VERTEX_ATTRIB_ARRAY_TYPE, &type);
    glGetVertexAttribiv(attribute, GL_VERTEX_ATTRIB_ARRAY_STRIDE, &stride);
    glGetVertexAttribiv(attribute, GL_VERTEX_ATTRIB_ARRAY_DIVISOR, &divisor);
    glGetVertexAttribPointerv(attribute, GL_VERTEX_ATTRIB_ARRAY_POINTER, &pointer);
    size_t bytes = vox_native_attribute_bytes(components, (GLenum)type);
    if (!buffer || !bytes || stride < 0) {
        vox_native_gl_error(GL_INVALID_OPERATION);
        return 0;
    }
    size_t last = (GLuint)divisor ? (size_t)(instances - 1) / (GLuint)divisor : last_vertex;
    size_t span, extent;
    if (!vox_native_size_mul(last, stride ? (size_t)stride : bytes, &span)
        || !vox_native_size_add(span, bytes, &extent)) {
        vox_native_gl_error(GL_INVALID_OPERATION);
        return 0;
    }
    glBindBuffer(GL_ARRAY_BUFFER, (GLuint)buffer);
    return vox_native_buffer_extent(GL_ARRAY_BUFFER, (size_t)(uintptr_t)pointer, extent);
}

static void vox_native_draw_restart(GLenum type, int indexed)
{
#if VOX_NATIVE_GL_DESKTOP
    VoxEGLContext* context = vox_native_gl_current();
    if (indexed && context && context->version == 3) {
        GLuint restart = type == GL_UNSIGNED_BYTE ? UINT8_MAX
            : type == GL_UNSIGNED_SHORT ? UINT16_MAX : UINT32_MAX;
        glEnable(GL_PRIMITIVE_RESTART);
        glPrimitiveRestartIndex(restart);
    } else {
        glDisable(GL_PRIMITIVE_RESTART);
    }
#else
    (void)type;
    (void)indexed;
#endif
}

// The adapter's callers use instances=1 for ordinary (non-instanced) draws.
static int vox_native_validate_draw(GLenum mode, int first, int count, GLenum type,
    long long offset, int instances, int indexed)
{
    switch (mode) {
    case GL_POINTS: case GL_LINES: case GL_LINE_LOOP: case GL_LINE_STRIP:
    case GL_TRIANGLES: case GL_TRIANGLE_STRIP: case GL_TRIANGLE_FAN: break;
    default: vox_native_gl_error(GL_INVALID_ENUM); return 0;
    }
    if (first < 0 || count < 0 || instances < 0 || offset < 0) {
        vox_native_gl_error(GL_INVALID_VALUE);
        return 0;
    }
    size_t index_bytes = 0;
    if (indexed) {
        switch (type) {
        case GL_UNSIGNED_BYTE: index_bytes = 1; break;
        case GL_UNSIGNED_SHORT: index_bytes = 2; break;
        case GL_UNSIGNED_INT: index_bytes = 4; break;
        default: vox_native_gl_error(GL_INVALID_ENUM); return 0;
        }
        if ((uint64_t)offset % index_bytes || (uint64_t)offset > (uint64_t)PTRDIFF_MAX) {
            vox_native_gl_error(GL_INVALID_OPERATION);
            return 0;
        }
    }
    vox_native_draw_restart(type, indexed);
    if (!count || !instances) return 1;
    size_t last_vertex = 0;
    int have_vertex = !indexed;
    if (indexed) {
        GLint buffer = 0;
        size_t bytes;
        glGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING, &buffer);
        if (!buffer || !vox_native_size_mul((size_t)count, index_bytes, &bytes)
            || bytes > (size_t)PTRDIFF_MAX) {
            vox_native_gl_error(GL_INVALID_OPERATION);
            return 0;
        }
        if (!vox_native_buffer_extent(GL_ELEMENT_ARRAY_BUFFER, (size_t)offset, bytes)) return 0;
        unsigned char const* indices = glMapBufferRange(GL_ELEMENT_ARRAY_BUFFER,
            (GLintptr)offset, (GLsizeiptr)bytes, GL_MAP_READ_BIT);
        if (!indices) return 0;
        VoxEGLContext* context = vox_native_gl_current();
        int restart_enabled = context && context->version == 3;
        uint32_t restart = index_bytes == 1 ? UINT8_MAX : index_bytes == 2 ? UINT16_MAX : UINT32_MAX;
        for (int i = 0; i < count; ++i) {
            uint32_t index;
            if (index_bytes == 1) index = indices[i];
            else if (index_bytes == 2) {
                uint16_t value;
                memcpy(&value, indices + (size_t)i * 2, sizeof(value));
                index = value;
            } else {
                memcpy(&index, indices + (size_t)i * 4, sizeof(index));
            }
            if (restart_enabled && index == restart) continue;
            if ((size_t)index > last_vertex) last_vertex = (size_t)index;
            have_vertex = 1;
        }
        if (!glUnmapBuffer(GL_ELEMENT_ARRAY_BUFFER)) {
            vox_native_gl_error(GL_INVALID_OPERATION);
            return 0;
        }
    } else if (!vox_native_size_add((size_t)first, (size_t)count - 1, &last_vertex)) {
        vox_native_gl_error(GL_INVALID_OPERATION);
        return 0;
    }
    if (!have_vertex) return 1;
    unsigned char* active;
    GLint limit;
    if (!vox_native_active_attributes(&active, &limit)) return 0;
    GLint original_buffer = 0;
    glGetIntegerv(GL_ARRAY_BUFFER_BINDING, &original_buffer);
    int valid = 1;
    for (GLint attribute = 0; attribute < limit && valid; ++attribute) {
        if (active[attribute])
            valid = vox_native_attribute_extent((GLuint)attribute, last_vertex, instances);
    }
    glBindBuffer(GL_ARRAY_BUFFER, (GLuint)original_buffer);
    free(active);
    return valid;
}

#endif
