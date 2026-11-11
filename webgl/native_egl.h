/* Copyright (c) 2026, Ladybird contributors
 * SPDX-License-Identifier: BSD-2-Clause
 * Services/Compositor/OpenGLContext.cpp CPU painting context creation.
 */
#ifndef VOX_WEBGL_NATIVE_EGL_H
#define VOX_WEBGL_NATIVE_EGL_H
#if defined(_WIN32) && !defined(VOX_EGL_IMPLEMENTATION)
#include "native_egl_api.h"
#else
#ifdef _WIN32
#define VOX_EGL_LINKAGE
#else
#define VOX_EGL_LINKAGE static
#endif
#include "native_gl_platform.h"
#include "native_gl_bounds.h"
#include "native_gl_compat.h"
#include "native_gl_readback.h"
#include "native_gl_shader.h"
#include "native_gl_draw.h"

static int vox_native_service_ready(void)
{
    VoxEGLContext* context = vox_native_gl_current();
    return context && !context->failed;
}

// Retain the service ABI while context creation uses the platform's GL API.
VOX_EGL_LINKAGE void* vox_egl_create(int version)
{
    return vox_native_gl_create(version);
}

VOX_EGL_LINKAGE int vox_egl_make_current(void* handle)
{
    return vox_native_gl_make_current((VoxEGLContext*)handle);
}

VOX_EGL_LINKAGE void vox_egl_destroy(void* handle)
{
    VoxEGLContext* context = (VoxEGLContext*)handle;
    if (!context) return;
    vox_native_shader_free_sources(&context->shader_sources);
    vox_native_compat_destroy(context);
    vox_native_readback_destroy(context);
    vox_native_gl_destroy(context);
}

// This must also restore the renderer after a failed native context.
VOX_EGL_LINKAGE void vox_gl_release_current(void) { vox_native_gl_release_current(); }

VOX_EGL_LINKAGE void* vox_gl_fence_sync(unsigned condition, unsigned flags) {
    if (!vox_native_service_ready()) return 0;
    return glFenceSync(condition, flags);
}
VOX_EGL_LINKAGE unsigned vox_gl_client_wait_sync(void* sync, unsigned flags, unsigned long long timeout) {
    if (!vox_native_service_ready()) return 0;
    return glClientWaitSync(sync, flags, timeout);
}
VOX_EGL_LINKAGE void vox_gl_wait_sync(void* sync, unsigned flags, unsigned long long timeout) {
    if (!vox_native_service_ready()) return;
    glWaitSync(sync, flags, timeout);
}
VOX_EGL_LINKAGE void vox_gl_delete_sync(void* sync) {
    if (!vox_native_service_ready()) return;
    glDeleteSync(sync);
}
VOX_EGL_LINKAGE int vox_gl_get_sync_parameter(void* sync, unsigned pname)
{
    if (!vox_native_service_ready()) return 0;

    GLint result = 0;
    glGetSynciv(sync, pname, 1, NULL, &result);
    return result;
}
VOX_EGL_LINKAGE unsigned vox_gl_get_error(void)
{
    if (!vox_native_service_ready()) return 0;

    VoxEGLContext* context = vox_native_gl_current();
    if (context && context->pending_error) {
        GLenum error = context->pending_error;
        context->pending_error = GL_NO_ERROR;
        return error;
    }
    return glGetError();
}
VOX_EGL_LINKAGE int vox_gl_is_object(int kind, unsigned handle) {
    if (!vox_native_service_ready()) return 0;

    switch (kind) {
    case 0: return glIsBuffer(handle);
    case 1: return glIsFramebuffer(handle);
    case 2: return glIsRenderbuffer(handle);
    case 3: return glIsTexture(handle);
    case 9: return glIsShader(handle);
    case 10: return glIsProgram(handle);
    default: return GL_FALSE;
    }
}
VOX_EGL_LINKAGE char const* vox_gl_string(unsigned name) {
    if (!vox_native_service_ready()) return 0;
    return (char const*)glGetString(name);
}
VOX_EGL_LINKAGE int vox_gl_extension_count(void) {
    if (!vox_native_service_ready()) return 0;
    return vox_native_gl_extension_count();
}
VOX_EGL_LINKAGE char const* vox_gl_extension_at(unsigned index) {
    if (!vox_native_service_ready()) return 0;
    return vox_native_gl_extension_at(index);
}
// Native GL extensions are enabled by the driver; the V owner tracks WebGL opt-in.
VOX_EGL_LINKAGE void vox_gl_request_extension(char const* name) {
    if (!vox_native_service_ready()) return;
    (void)name;
}
VOX_EGL_LINKAGE void vox_egl_free_surface(void* handle)
{
    VoxEGLContext* context = handle;
    if (!vox_egl_make_current(handle)) return;
    if (context->framebuffer) glDeleteFramebuffers(1, &context->framebuffer);
    if (context->color_buffer) glDeleteTextures(1, &context->color_buffer);
    if (context->depth_buffer) glDeleteRenderbuffers(1, &context->depth_buffer);
    context->framebuffer = context->color_buffer = context->depth_buffer = 0;
}
VOX_EGL_LINKAGE int vox_egl_allocate_surface(void* handle, int width, int height, int depth, int stencil)
{
    VoxEGLContext* context = handle;
    if (!vox_egl_make_current(handle) || width <= 0 || height <= 0) return 0;
    GLint old_texture, old_renderbuffer, old_draw, old_read, old_unpack;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, &old_texture);
    glGetIntegerv(GL_RENDERBUFFER_BINDING, &old_renderbuffer);
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &old_draw);
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &old_read);
    glGetIntegerv(GL_PIXEL_UNPACK_BUFFER_BINDING, &old_unpack);
    GLuint old_default = context->framebuffer;
    if ((GLuint)old_texture == context->color_buffer) old_texture = 0;
    if ((GLuint)old_renderbuffer == context->depth_buffer) old_renderbuffer = 0;
    vox_egl_free_surface(handle);
    glGenTextures(1, &context->color_buffer);
    glBindTexture(GL_TEXTURE_2D, context->color_buffer);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, (GLuint)old_unpack);
    glGenFramebuffers(1, &context->framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, context->framebuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, context->color_buffer, 0);
    if (depth || stencil) {
        glGenRenderbuffers(1, &context->depth_buffer);
        glBindRenderbuffer(GL_RENDERBUFFER, context->depth_buffer);
        GLenum format = depth && stencil ? GL_DEPTH24_STENCIL8 : depth ? GL_DEPTH_COMPONENT24 : GL_STENCIL_INDEX8;
        GLenum attachment = depth && stencil ? GL_DEPTH_STENCIL_ATTACHMENT : depth ? GL_DEPTH_ATTACHMENT : GL_STENCIL_ATTACHMENT;
        glRenderbufferStorage(GL_RENDERBUFFER, format, width, height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, attachment, GL_RENDERBUFFER, context->depth_buffer);
    }
    int complete = glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;
    if (complete) vox_native_clear_bound_framebuffer(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
    glBindTexture(GL_TEXTURE_2D, (GLuint)old_texture);
    glBindRenderbuffer(GL_RENDERBUFFER, (GLuint)old_renderbuffer);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, (GLuint)old_draw == old_default ? context->framebuffer : (GLuint)old_draw);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, (GLuint)old_read == old_default ? context->framebuffer : (GLuint)old_read);
    glViewport(0, 0, width, height);
    return complete;
}
VOX_EGL_LINKAGE unsigned vox_egl_default_framebuffer(void* handle) { return handle ? ((VoxEGLContext*)handle)->framebuffer : 0; }
VOX_EGL_LINKAGE unsigned vox_egl_default_renderbuffer(void* handle) { return handle ? ((VoxEGLContext*)handle)->depth_buffer : 0; }
/* OpenGLContext::copy_default_framebuffer_to_cpu_painting_surface. */
VOX_EGL_LINKAGE int vox_egl_copy_drawing_buffer(void* handle, int width, int height, unsigned char* pixels)
{
    VoxEGLContext* context = handle;
    if (!vox_egl_make_current(handle) || !context->framebuffer || !pixels || width <= 0 || height <= 0) return 0;
    size_t row_bytes = 0, total_bytes = 0;
    if (!vox_native_size_mul((size_t)width, 4, &row_bytes)
        || !vox_native_size_mul(row_bytes, (size_t)height, &total_bytes)) return 0;
    vox_native_storage_preserve_errors();
    GLint original_framebuffer = 0, original_read_buffer = GL_COLOR_ATTACHMENT0;
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &original_framebuffer);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, context->framebuffer);
    glGetIntegerv(GL_READ_BUFFER, &original_read_buffer);
    glReadBuffer(GL_COLOR_ATTACHMENT0);
    /* Both WebGL versions use desktop GL. Presentation must always isolate
     * its tightly packed destination from every native pack setting. */
    VoxNativeReadPack pack = vox_native_read_begin_pack(1);
    GLint framebuffer_width = 0, framebuffer_height = 0;
    int success = vox_native_read_framebuffer_size(&framebuffer_width, &framebuffer_height);
    if (success && (width > framebuffer_width || height > framebuffer_height)) {
        vox_native_gl_error(GL_INVALID_OPERATION);
        success = 0;
    }
    for (int source_y = 0; success && source_y < height; ++source_y) {
        glReadPixels(0, source_y, width, 1, GL_RGBA, GL_UNSIGNED_BYTE,
            pixels + total_bytes - ((size_t)source_y + 1) * row_bytes);
        success = vox_native_storage_error() == GL_NO_ERROR;
    }
    vox_native_read_end_pack(pack);
    glReadBuffer((GLenum)original_read_buffer);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, (GLuint)original_framebuffer);
    return success;
}
/* OpenGLContext::clear_buffer_to_default_values. */
VOX_EGL_LINKAGE void vox_egl_clear_drawing_buffer(void* handle)
{
    VoxEGLContext* context = handle;
    if (!vox_egl_make_current(handle) || !context->framebuffer) return;
    GLint original_framebuffer;
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &original_framebuffer);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, context->framebuffer);
    GLint original_draw_buffer = 0;
    glGetIntegerv(GL_DRAW_BUFFER0, &original_draw_buffer);
    GLenum color = GL_COLOR_ATTACHMENT0;
    glDrawBuffers(1, &color);
    vox_native_clear_bound_framebuffer(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
    color = (GLenum)original_draw_buffer;
    glDrawBuffers(1, &color);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, (GLuint)original_framebuffer);
}
VOX_EGL_LINKAGE unsigned vox_gl_gen_object(int kind)
{
    if (!vox_native_service_ready()) return 0;

    GLuint result = 0;
    switch (kind) {
    case 0: glGenBuffers(1, &result); break;
    case 1: glGenFramebuffers(1, &result); vox_native_framebuffer_created(result); break;
    case 2: glGenRenderbuffers(1, &result); break;
    case 3: glGenTextures(1, &result); break;
    case 4: glGenQueries(1, &result); break;
    case 5: glGenSamplers(1, &result); break;
    case 6: glGenVertexArrays(1, &result); break;
    case 7: glGenVertexArrays(1, &result); break;
    case 8: glGenTransformFeedbacks(1, &result); break;
    }
    return result;
}
VOX_EGL_LINKAGE void vox_gl_delete_object(int kind, unsigned handle)
{
    if (!vox_native_service_ready()) return;

    switch (kind) {
    case 0: glDeleteBuffers(1, &handle); break;
    case 1: {
        GLint draw = 0, read = 0;
        glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &draw);
        glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &read);
        vox_native_framebuffer_deleted(handle);
        glDeleteFramebuffers(1, &handle);
        GLuint fallback = vox_native_gl_current()->framebuffer;
        if ((GLuint)draw == handle) glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fallback);
        if ((GLuint)read == handle) glBindFramebuffer(GL_READ_FRAMEBUFFER, fallback);
        break;
    }
    case 2: vox_native_readback_object_deleted(2, handle); glDeleteRenderbuffers(1, &handle); break;
    case 3: vox_native_readback_object_deleted(3, handle); vox_native_texture_deleted(handle); glDeleteTextures(1, &handle); break;
    case 4: glDeleteQueries(1, &handle); break;
    case 5: glDeleteSamplers(1, &handle); break;
    case 6: case 7: {
        GLint current = 0;
        glGetIntegerv(GL_VERTEX_ARRAY_BINDING, &current);
        glDeleteVertexArrays(1, &handle);
        if ((GLuint)current == handle) glBindVertexArray(vox_native_gl_current()->default_vertex_array);
        break;
    }
    case 8: glDeleteTransformFeedbacks(1, &handle); break;
    }
}
VOX_EGL_LINKAGE void vox_gl_begin_query(unsigned target, unsigned handle) {
    if (!vox_native_service_ready()) return;
    glBeginQuery(target, handle);
}
VOX_EGL_LINKAGE void vox_gl_end_query(unsigned target) {
    if (!vox_native_service_ready()) return;
    glEndQuery(target);
}
VOX_EGL_LINKAGE unsigned vox_gl_query_parameter(unsigned handle, unsigned pname) {
    if (!vox_native_service_ready()) return 0;
    GLuint result = 0; glGetQueryObjectuiv(handle, pname, &result); return result;
}
VOX_EGL_LINKAGE void vox_gl_bind_sampler(unsigned unit, unsigned handle) {
    if (!vox_native_service_ready()) return;
    glBindSampler(unit, handle);
}
VOX_EGL_LINKAGE void vox_gl_sampler_parameteri(unsigned handle, unsigned pname, int value) {
    if (!vox_native_service_ready()) return;
    glSamplerParameteri(handle, pname, value);
}
VOX_EGL_LINKAGE void vox_gl_sampler_parameterf(unsigned handle, unsigned pname, float value) {
    if (!vox_native_service_ready()) return;
    glSamplerParameterf(handle, pname, value);
}
VOX_EGL_LINKAGE float vox_gl_sampler_parameter(unsigned handle, unsigned pname) {
    if (!vox_native_service_ready()) return 0;
    GLfloat result = 0; if (vox_native_scalar_texture_parameter(pname)) glGetSamplerParameterfv(handle, pname, &result); return result;
}
VOX_EGL_LINKAGE void vox_gl_bind_vertex_array(unsigned handle, int oes)
{
    if (!vox_native_service_ready()) return;

    (void)oes;
    VoxEGLContext* context = vox_native_gl_current();
    glBindVertexArray(!handle && context ? context->default_vertex_array : handle);
}
VOX_EGL_LINKAGE int vox_gl_is_vertex_array(unsigned handle, int oes) {
    if (!vox_native_service_ready()) return 0;
    (void)oes; return glIsVertexArray(handle);
}
VOX_EGL_LINKAGE int vox_gl_vertex_attrib_parameter(unsigned index, unsigned pname) {
    if (!vox_native_service_ready()) return 0;
    GLint result = 0; if (pname == GL_CURRENT_VERTEX_ATTRIB) { vox_native_gl_error(GL_INVALID_ENUM); return 0; } glGetVertexAttribiv(index,pname,&result); return result;
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_float_parameter(unsigned index, float* result) {
    if (!vox_native_service_ready()) return;
    glGetVertexAttribfv(index,GL_CURRENT_VERTEX_ATTRIB,result);
}
VOX_EGL_LINKAGE long long vox_gl_vertex_attrib_offset(unsigned index) {
    if (!vox_native_service_ready()) return 0;
    void* result = NULL; glGetVertexAttribPointerv(index,GL_VERTEX_ATTRIB_ARRAY_POINTER,&result); return (intptr_t)result;
}
VOX_EGL_LINKAGE void vox_gl_bind_transform_feedback(unsigned target, unsigned handle) {
    if (!vox_native_service_ready()) return;
    glBindTransformFeedback(target,handle);
}
VOX_EGL_LINKAGE void vox_gl_begin_transform_feedback(unsigned mode) {
    if (!vox_native_service_ready()) return;
    glBeginTransformFeedback(mode);
}
VOX_EGL_LINKAGE void vox_gl_end_transform_feedback(void) {
    if (!vox_native_service_ready()) return;
    glEndTransformFeedback();
}
VOX_EGL_LINKAGE void vox_gl_pause_transform_feedback(void) {
    if (!vox_native_service_ready()) return;
    glPauseTransformFeedback();
}
VOX_EGL_LINKAGE void vox_gl_resume_transform_feedback(void) {
    if (!vox_native_service_ready()) return;
    glResumeTransformFeedback();
}
VOX_EGL_LINKAGE void vox_gl_transform_feedback_varyings(unsigned program, int count, void const* names, unsigned mode) {
    if (!vox_native_service_ready()) return;
    glTransformFeedbackVaryings(program,count,(char const* const*)names,mode);
}
VOX_EGL_LINKAGE void vox_gl_bind_buffer_base(unsigned target, unsigned index, unsigned buffer) {
    if (!vox_native_service_ready()) return;
    glBindBufferBase(target,index,buffer);
}
VOX_EGL_LINKAGE void vox_gl_bind_buffer_range(unsigned target, unsigned index, unsigned buffer, long long offset, long long size) {
    if (!vox_native_service_ready()) return;
    glBindBufferRange(target,index,buffer,(GLintptr)offset,(GLsizeiptr)size);
}
VOX_EGL_LINKAGE void vox_gl_bind_buffer(unsigned target, unsigned handle) {
    if (!vox_native_service_ready()) return;
    glBindBuffer(target, handle);
}
VOX_EGL_LINKAGE void vox_gl_buffer_data(unsigned target, long long size, void const* data, unsigned usage)
{
    if (!vox_native_service_ready()) return;

    if (size < 0 || (uint64_t)size > (uint64_t)PTRDIFF_MAX) { vox_native_gl_error(GL_INVALID_VALUE); return; }
    void* zero = NULL;
    if (!data && size) {
        zero = calloc(1, (size_t)size);
        if (!zero) { vox_native_gl_error(GL_OUT_OF_MEMORY); return; }
        data = zero;
    }
    glBufferData(target, (GLsizeiptr)size, data, usage);
    free(zero);
}
VOX_EGL_LINKAGE void vox_gl_buffer_sub_data(unsigned target, long long offset, long long size, void const* data) {
    if (!vox_native_service_ready()) return;
    glBufferSubData(target, (GLintptr)offset, (GLsizeiptr)size, data);
}
VOX_EGL_LINKAGE void vox_gl_copy_buffer_sub_data(unsigned read_target, unsigned write_target, long long read_offset, long long write_offset, long long size) {
    if (!vox_native_service_ready()) return;
    glCopyBufferSubData(read_target, write_target, (GLintptr)read_offset, (GLintptr)write_offset, (GLsizeiptr)size);
}
/* Services/Compositor/HostWebGLContext.cpp::read_buffer_sub_data. */
VOX_EGL_LINKAGE int vox_gl_read_buffer_sub_data(unsigned target, long long offset, long long size, void* data) {
    if (!vox_native_service_ready()) return 0;

    if (size == 0) return 1;
    void* mapped = glMapBufferRange(target, (GLintptr)offset, (GLsizeiptr)size, GL_MAP_READ_BIT);
    if (!mapped) return 0;
    memcpy(data, mapped, (size_t)size);
    glUnmapBuffer(target);
    return 1;
}
VOX_EGL_LINKAGE int vox_gl_buffer_parameter(unsigned target, unsigned pname) {
    if (!vox_native_service_ready()) return 0;

    GLint result = 0;
    glGetBufferParameteriv(target, pname, &result);
    return result;
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_pointer(unsigned index, int size, unsigned type, int normalized, int stride, long long offset) {
    if (!vox_native_service_ready()) return;
    glVertexAttribPointer(index, size, type, normalized, stride, (void const*)(intptr_t)offset);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_i_pointer(unsigned index, int size, unsigned type, int stride, long long offset) {
    if (!vox_native_service_ready()) return;
    glVertexAttribIPointer(index, size, type, stride, (void const*)(intptr_t)offset);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib1f(unsigned index, float x) {
    if (!vox_native_service_ready()) return;
    glVertexAttrib1f(index, x);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib2f(unsigned index, float x, float y) {
    if (!vox_native_service_ready()) return;
    glVertexAttrib2f(index, x, y);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib3f(unsigned index, float x, float y, float z) {
    if (!vox_native_service_ready()) return;
    glVertexAttrib3f(index, x, y, z);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib4f(unsigned index, float x, float y, float z, float w) {
    if (!vox_native_service_ready()) return;
    glVertexAttrib4f(index, x, y, z, w);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib1fv(unsigned index, float const* data) {
    if (!vox_native_service_ready()) return;
    glVertexAttrib1fv(index, data);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib2fv(unsigned index, float const* data) {
    if (!vox_native_service_ready()) return;
    glVertexAttrib2fv(index, data);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib3fv(unsigned index, float const* data) {
    if (!vox_native_service_ready()) return;
    glVertexAttrib3fv(index, data);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_floats(unsigned index, float const* data) {
    if (!vox_native_service_ready()) return;
    glVertexAttrib4fv(index, data);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_enable(unsigned index, int enabled) {
    if (!vox_native_service_ready()) return;
    if (enabled) glEnableVertexAttribArray(index); else glDisableVertexAttribArray(index);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_divisor(unsigned index, unsigned divisor, int version) {
    if (!vox_native_service_ready()) return;
    (void)version; glVertexAttribDivisor(index, divisor);
}
VOX_EGL_LINKAGE void vox_gl_draw_arrays(unsigned mode, int first, int count) {
    if (!vox_native_service_ready()) return;
    if (vox_native_validate_draw(mode, first, count, 0, 0, 1, 0)) glDrawArrays(mode, first, count);
}
VOX_EGL_LINKAGE void vox_gl_draw_elements(unsigned mode, int count, unsigned type, long long offset) {
    if (!vox_native_service_ready()) return;
    if (vox_native_validate_draw(mode, 0, count, type, offset, 1, 1)) glDrawElements(mode, count, type, (void const*)(intptr_t)offset);
}
VOX_EGL_LINKAGE void vox_gl_draw_arrays_instanced(unsigned mode, int first, int count, int instances, int version) {
    if (!vox_native_service_ready()) return;
    (void)version; if (vox_native_validate_draw(mode, first, count, 0, 0, instances, 0)) glDrawArraysInstanced(mode, first, count, instances);
}
VOX_EGL_LINKAGE void vox_gl_draw_elements_instanced(unsigned mode, int count, unsigned type, long long offset, int instances, int version) {
    if (!vox_native_service_ready()) return;
    (void)version; if (vox_native_validate_draw(mode, 0, count, type, offset, instances, 1)) glDrawElementsInstanced(mode, count, type, (void const*)(intptr_t)offset, instances);
}
VOX_EGL_LINKAGE void vox_gl_draw_range_elements(unsigned mode, unsigned start, unsigned end, int count, unsigned type, long long offset) {
    if (!vox_native_service_ready()) return;
    if (end < start) { vox_native_gl_error(GL_INVALID_VALUE); return; } if (vox_native_validate_draw(mode, 0, count, type, offset, 1, 1)) glDrawRangeElements(mode, start, end, count, type, (void const*)(intptr_t)offset);
}
VOX_EGL_LINKAGE void vox_gl_bind_framebuffer(unsigned target, unsigned handle) {
    if (!vox_native_service_ready()) return;
    glBindFramebuffer(target, handle);
}
VOX_EGL_LINKAGE void vox_gl_bind_renderbuffer(unsigned target, unsigned handle) {
    if (!vox_native_service_ready()) return;
    glBindRenderbuffer(target, handle);
}
VOX_EGL_LINKAGE void vox_gl_bind_texture(unsigned target, unsigned handle) {
    if (!vox_native_service_ready()) return;
    glBindTexture(target, handle);
}
VOX_EGL_LINKAGE unsigned vox_gl_framebuffer_status(unsigned target) {
    if (!vox_native_service_ready()) return 0;
    return glCheckFramebufferStatus(target);
}
VOX_EGL_LINKAGE void vox_gl_framebuffer_texture(unsigned target, unsigned attachment, unsigned texture_target, unsigned texture, int level)
{
    if (!vox_native_service_ready()) return;
    vox_native_storage_preserve_errors();
    glFramebufferTexture2D(target, attachment, texture_target, texture, level);
    if (vox_native_storage_error() == GL_NO_ERROR) vox_native_framebuffer_attachment_changed(target, attachment);
}
VOX_EGL_LINKAGE void vox_gl_framebuffer_renderbuffer(unsigned target, unsigned attachment, unsigned renderbuffer_target, unsigned renderbuffer)
{
    if (!vox_native_service_ready()) return;
    vox_native_storage_preserve_errors();
    glFramebufferRenderbuffer(target, attachment, renderbuffer_target, renderbuffer);
    if (vox_native_storage_error() == GL_NO_ERROR) vox_native_framebuffer_attachment_changed(target, attachment);
}
VOX_EGL_LINKAGE void vox_gl_renderbuffer_storage(unsigned target, unsigned format, int width, int height)
{
    if (!vox_native_service_ready()) return;

    vox_native_storage_preserve_errors();
    glRenderbufferStorage(target, format, width, height);
    if (vox_native_storage_error() != GL_NO_ERROR) return;
    if (width > 0 && height > 0) {
        vox_native_initialize_renderbuffer(format);
        if (vox_native_storage_error() != GL_NO_ERROR) vox_native_gl_current()->failed = 1;
    }
}
VOX_EGL_LINKAGE void vox_gl_tex_image2d(unsigned target, int level, int format, int width, int height, int border, unsigned pixel_format, unsigned type, int capacity, void const* data)
{
    if (!vox_native_service_ready()) return;

    if (!vox_native_texture_mutable(target)) return;
    const void* pixels; void* owned;
    if (!vox_native_unpack_pixels(2, width, height, 1, pixel_format, type, capacity, data, 1, &pixels, &owned)) return;
    vox_native_storage_preserve_errors();
    glTexImage2D(target, level, vox_native_texture_format(format, type), width, height, border,
        vox_native_pixel_format(pixel_format), vox_native_pixel_type(type), pixels);
    if (vox_native_storage_error() == GL_NO_ERROR) vox_native_texture_swizzle(target, format);
    free(owned);
}
// Compressed uploads retain the source byte count as their native imageSize.
VOX_EGL_LINKAGE void vox_gl_compressed_tex_image2d(unsigned target, int level, unsigned format, int width, int height, int border, int size, void const* data) {
    if (!vox_native_service_ready()) return;
    if (vox_native_texture_mutable(target)) glCompressedTexImage2D(target, level, format, width, height, border, size, data);
}
VOX_EGL_LINKAGE void vox_gl_compressed_tex_sub_image2d(unsigned target, int level, int x, int y, int width, int height, unsigned format, int size, void const* data) {
    if (!vox_native_service_ready()) return;
    glCompressedTexSubImage2D(target, level, x, y, width, height, format, size, data);
}
VOX_EGL_LINKAGE void vox_gl_compressed_tex_image3d(unsigned target, int level, unsigned format, int width, int height, int depth, int border, int size, void const* data) {
    if (!vox_native_service_ready()) return;
    if (vox_native_texture_mutable(target)) glCompressedTexImage3D(target, level, format, width, height, depth, border, size, data);
}
VOX_EGL_LINKAGE void vox_gl_compressed_tex_sub_image3d(unsigned target, int level, int x, int y, int z, int width, int height, int depth, unsigned format, int size, void const* data) {
    if (!vox_native_service_ready()) return;
    glCompressedTexSubImage3D(target, level, x, y, z, width, height, depth, format, size, data);
}
VOX_EGL_LINKAGE void vox_gl_tex_sub_image2d(unsigned target, int level, int x, int y, int width, int height, unsigned format, unsigned type, int capacity, void const* data)
{
    if (!vox_native_service_ready()) return;

    const void* pixels; void* owned;
    if (!vox_native_unpack_pixels(2, width, height, 1, format, type, capacity, data, 0, &pixels, &owned)) return;
    glTexSubImage2D(target, level, x, y, width, height, vox_native_pixel_format(format), vox_native_pixel_type(type), pixels);
}
VOX_EGL_LINKAGE void vox_gl_tex_parameteri(unsigned target, unsigned pname, int value) {
    if (!vox_native_service_ready()) return;
    vox_native_tex_parameter_i(target, pname, value);
}
VOX_EGL_LINKAGE void vox_gl_tex_parameterf(unsigned target, unsigned pname, float value) {
    if (!vox_native_service_ready()) return;
    vox_native_tex_parameter_f(target, pname, value);
}
VOX_EGL_LINKAGE void vox_gl_tex_storage2d(unsigned target, int levels, unsigned format, int width, int height) {
    if (!vox_native_service_ready()) return;
    vox_native_tex_storage_2d(target, levels, format, width, height);
}
VOX_EGL_LINKAGE void vox_gl_tex_storage3d(unsigned target, int levels, unsigned format, int width, int height, int depth) {
    if (!vox_native_service_ready()) return;
    vox_native_tex_storage_3d(target, levels, format, width, height, depth);
}
VOX_EGL_LINKAGE void vox_gl_tex_image3d(unsigned target, int level, int format, int width, int height, int depth, int border, unsigned pixel_format, unsigned type, int capacity, void const* data)
{
    if (!vox_native_service_ready()) return;

    if (!vox_native_texture_mutable(target)) return;
    const void* pixels; void* owned;
    if (!vox_native_unpack_pixels(3, width, height, depth, pixel_format, type, capacity, data, 1, &pixels, &owned)) return;
    vox_native_storage_preserve_errors();
    glTexImage3D(target, level, vox_native_texture_format(format, type), width, height, depth, border,
        vox_native_pixel_format(pixel_format), vox_native_pixel_type(type), pixels);
    if (vox_native_storage_error() == GL_NO_ERROR) vox_native_texture_swizzle(target, format);
    free(owned);
}
VOX_EGL_LINKAGE void vox_gl_tex_sub_image3d(unsigned target, int level, int x, int y, int z, int width, int height, int depth, unsigned format, unsigned type, int capacity, void const* data)
{
    if (!vox_native_service_ready()) return;

    const void* pixels; void* owned;
    if (!vox_native_unpack_pixels(3, width, height, depth, format, type, capacity, data, 0, &pixels, &owned)) return;
    glTexSubImage3D(target, level, x, y, z, width, height, depth, vox_native_pixel_format(format), vox_native_pixel_type(type), pixels);
}
VOX_EGL_LINKAGE void vox_gl_framebuffer_texture_layer(unsigned target, unsigned attachment, unsigned texture, int level, int layer)
{
    if (!vox_native_service_ready()) return;
    vox_native_storage_preserve_errors();
    glFramebufferTextureLayer(target, attachment, texture, level, layer);
    if (vox_native_storage_error() == GL_NO_ERROR) vox_native_framebuffer_attachment_changed(target, attachment);
}
VOX_EGL_LINKAGE void vox_gl_copy_tex_image2d(unsigned target, int level, unsigned format, int x, int y, int width, int height, int border)
{
    if (!vox_native_service_ready()) return;
    vox_native_copy_tex_image_2d(target, level, format, x, y, width, height, border);
}
VOX_EGL_LINKAGE void vox_gl_copy_tex_sub_image2d(unsigned target, int level, int x_offset, int y_offset, int x, int y, int width, int height)
{
    if (!vox_native_service_ready()) return;
    vox_native_copy_tex_sub_image_2d(target, level, x_offset, y_offset, x, y, width, height);
}
VOX_EGL_LINKAGE void vox_gl_draw_buffers(int count, unsigned const* buffers, int extension)
{
    if (!vox_native_service_ready()) return;
    (void)extension;
    GLint framebuffer = 0, maximum = 0;
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &framebuffer);
    glGetIntegerv(GL_MAX_DRAW_BUFFERS, &maximum);
    if (count < 0 || count > maximum || (count && !buffers)) { vox_native_gl_error(GL_INVALID_VALUE); return; }
    if ((GLuint)framebuffer == vox_native_gl_current()->framebuffer) {
        if (count != 1 || (buffers[0] != GL_BACK && buffers[0] != GL_NONE)) {
            vox_native_gl_error(GL_INVALID_OPERATION); return;
        }
        GLenum target = buffers[0] == GL_BACK ? GL_COLOR_ATTACHMENT0 : GL_NONE;
        glDrawBuffers(1, &target);
        return;
    }
    for (int i = 0; i < count; ++i) {
        if (buffers[i] != GL_NONE && buffers[i] != GL_COLOR_ATTACHMENT0 + (unsigned)i) {
            vox_native_gl_error(GL_INVALID_OPERATION); return;
        }
    }
    glDrawBuffers(count, buffers);
}
VOX_EGL_LINKAGE void vox_gl_read_buffer(unsigned source)
{
    if (!vox_native_service_ready()) return;
    GLint framebuffer = 0;
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &framebuffer);
    if ((GLuint)framebuffer == vox_native_gl_current()->framebuffer) {
        if (source != GL_BACK && source != GL_NONE) { vox_native_gl_error(GL_INVALID_OPERATION); return; }
        source = source == GL_BACK ? GL_COLOR_ATTACHMENT0 : GL_NONE;
    }
    glReadBuffer(source);
}
VOX_EGL_LINKAGE void vox_gl_blit_framebuffer(int sx0, int sy0, int sx1, int sy1, int dx0, int dy0, int dx1, int dy1, unsigned mask, unsigned filter) {
    if (!vox_native_service_ready()) return;
    glBlitFramebuffer(sx0, sy0, sx1, sy1, dx0, dy0, dx1, dy1, mask, filter);
}
VOX_EGL_LINKAGE void vox_gl_renderbuffer_storage_multisample(unsigned target, int samples, unsigned format, int width, int height)
{
    if (!vox_native_service_ready()) return;

    vox_native_storage_preserve_errors();
    glRenderbufferStorageMultisample(target, samples, format, width, height);
    if (vox_native_storage_error() != GL_NO_ERROR) return;
    if (width > 0 && height > 0) {
        vox_native_initialize_renderbuffer(format);
        if (vox_native_storage_error() != GL_NO_ERROR) vox_native_gl_current()->failed = 1;
    }
}
static int vox_native_invalidate_arguments(unsigned target, int count, unsigned const* attachments)
{
    if (target != GL_FRAMEBUFFER && target != GL_DRAW_FRAMEBUFFER && target != GL_READ_FRAMEBUFFER) {
        vox_native_gl_error(GL_INVALID_ENUM); return 0;
    }
    if (count < 0 || (count && !attachments)) { vox_native_gl_error(GL_INVALID_VALUE); return 0; }
    GLint maximum = 0, framebuffer = 0;
    glGetIntegerv(GL_MAX_COLOR_ATTACHMENTS, &maximum);
    glGetIntegerv(target == GL_READ_FRAMEBUFFER ? GL_READ_FRAMEBUFFER_BINDING : GL_DRAW_FRAMEBUFFER_BINDING, &framebuffer);
    int is_default = (GLuint)framebuffer == vox_native_gl_current()->framebuffer;
    for (int i = 0; i < count; ++i) {
        GLenum attachment = attachments[i];
        int valid = is_default ? (attachment == GL_COLOR || attachment == GL_DEPTH || attachment == GL_STENCIL)
            : (attachment == GL_DEPTH_ATTACHMENT || attachment == GL_STENCIL_ATTACHMENT
                || (attachment >= GL_COLOR_ATTACHMENT0 && attachment < GL_COLOR_ATTACHMENT0 + (unsigned)maximum));
        if (!valid) { vox_native_gl_error(GL_INVALID_ENUM); return 0; }
    }
    return 1;
}
// Discarding attachments is an optional optimization. Retain initialized data
// so a later sample/read cannot observe undefined driver storage.
VOX_EGL_LINKAGE void vox_gl_invalidate_framebuffer(unsigned target, int count, unsigned const* attachments)
{
    if (!vox_native_service_ready()) return;
    (void)vox_native_invalidate_arguments(target, count, attachments);
}
VOX_EGL_LINKAGE void vox_gl_invalidate_sub_framebuffer(unsigned target, int count, unsigned const* attachments, int x, int y, int width, int height)
{
    if (!vox_native_service_ready()) return;
    if (!vox_native_invalidate_arguments(target, count, attachments)) return;
    if (width < 0 || height < 0) { vox_native_gl_error(GL_INVALID_VALUE); return; }
    (void)x; (void)y;
}
VOX_EGL_LINKAGE int vox_gl_tex_parameter(unsigned target, unsigned pname) {
    if (!vox_native_service_ready()) return 0;
    GLint value = 0; if (vox_native_scalar_texture_parameter(pname)) vox_native_texture_parameter(target, pname, &value); return value;
}
VOX_EGL_LINKAGE float vox_gl_tex_float_parameter(unsigned target, unsigned pname) {
    if (!vox_native_service_ready()) return 0;
    GLfloat value = 0; vox_native_texture_float_parameter(target, pname, &value); return value;
}
VOX_EGL_LINKAGE int vox_gl_renderbuffer_parameter(unsigned target, unsigned pname) {
    if (!vox_native_service_ready()) return 0;
    GLint value = 0; glGetRenderbufferParameteriv(target, pname, &value); return value;
}
// WebGL2RenderingContextOverloads::read_pixels numeric offset variant.
VOX_EGL_LINKAGE void vox_gl_read_pixels_to_buffer(int x, int y, int width, int height, unsigned format, unsigned type, int64_t offset)
{
    if (!vox_native_service_ready()) return;
    vox_native_read_pixels_to_buffer(x, y, width, height, format, type, offset);
}
VOX_EGL_LINKAGE int vox_gl_read_pixels(int x, int y, int width, int height, unsigned format, unsigned type, int capacity, void* data)
{
    if (!vox_native_service_ready()) return 0;
    return vox_native_read_pixels(x, y, width, height, format, type, capacity, data);
}
VOX_EGL_LINKAGE void vox_gl_clear_color(float r, float g, float b, float a) {
    if (!vox_native_service_ready()) return;
    glClearColor(r, g, b, a);
}
VOX_EGL_LINKAGE void vox_gl_clear_depth(float value) {
    if (!vox_native_service_ready()) return;
    glClearDepthf(value);
}
VOX_EGL_LINKAGE void vox_gl_clear_stencil(int value) {
    if (!vox_native_service_ready()) return;
    glClearStencil(value);
}
VOX_EGL_LINKAGE void vox_gl_color_mask(int r, int g, int b, int a) {
    if (!vox_native_service_ready()) return;
    glColorMask(r, g, b, a);
}
VOX_EGL_LINKAGE void vox_gl_depth_mask(int value) {
    if (!vox_native_service_ready()) return;
    glDepthMask(value);
}
VOX_EGL_LINKAGE void vox_gl_clear(unsigned mask) {
    if (!vox_native_service_ready()) return;
    glClear(mask);
}
VOX_EGL_LINKAGE void vox_gl_viewport(int x, int y, int w, int h) {
    if (!vox_native_service_ready()) return;
    glViewport(x, y, w, h);
}
VOX_EGL_LINKAGE void vox_gl_scissor(int x, int y, int w, int h) {
    if (!vox_native_service_ready()) return;
    glScissor(x, y, w, h);
}
static int vox_native_webgl_capability(unsigned capability)
{
    switch (capability) {
    case GL_BLEND: case GL_CULL_FACE: case GL_DEPTH_TEST: case GL_DITHER:
    case GL_POLYGON_OFFSET_FILL: case GL_SAMPLE_ALPHA_TO_COVERAGE:
    case GL_SAMPLE_COVERAGE: case GL_SCISSOR_TEST: case GL_STENCIL_TEST: return 1;
    case GL_RASTERIZER_DISCARD:
        if (vox_native_gl_current()->version == 3) return 1;
    }
    vox_native_gl_error(GL_INVALID_ENUM);
    return 0;
}
VOX_EGL_LINKAGE void vox_gl_enable(unsigned cap)
{
    if (vox_native_service_ready() && vox_native_webgl_capability(cap)) glEnable(cap);
}
VOX_EGL_LINKAGE int vox_gl_is_enabled(unsigned cap)
{
    return vox_native_service_ready() && vox_native_webgl_capability(cap) ? glIsEnabled(cap) : 0;
}
VOX_EGL_LINKAGE void vox_gl_disable(unsigned cap)
{
    if (vox_native_service_ready() && vox_native_webgl_capability(cap)) glDisable(cap);
}
VOX_EGL_LINKAGE void vox_gl_pixel_storei(unsigned pname, int value) {
    if (!vox_native_service_ready()) return;
    switch (pname) {
    case GL_PACK_ALIGNMENT: case GL_UNPACK_ALIGNMENT:
        break;
    case GL_PACK_ROW_LENGTH: case GL_PACK_SKIP_PIXELS: case GL_PACK_SKIP_ROWS:
    case GL_UNPACK_ROW_LENGTH: case GL_UNPACK_SKIP_PIXELS: case GL_UNPACK_SKIP_ROWS:
    case GL_UNPACK_IMAGE_HEIGHT: case GL_UNPACK_SKIP_IMAGES:
        if (vox_native_gl_current()->version == 3) break;
        /* WebGL1 cannot opt into desktop-only pixel-transfer state. */
        vox_native_gl_error(GL_INVALID_ENUM);
        return;
    default:
        vox_native_gl_error(GL_INVALID_ENUM);
        return;
    }
    glPixelStorei(pname, value);
}
VOX_EGL_LINKAGE void vox_gl_active_texture(unsigned texture) {
    if (!vox_native_service_ready()) return;
    glActiveTexture(texture);
}
VOX_EGL_LINKAGE void vox_gl_blend_color(float r, float g, float b, float a) {
    if (!vox_native_service_ready()) return;
    glBlendColor(r,g,b,a);
}
VOX_EGL_LINKAGE void vox_gl_blend_equation(unsigned mode) {
    if (!vox_native_service_ready()) return;
    glBlendEquation(mode);
}
VOX_EGL_LINKAGE void vox_gl_blend_equation_separate(unsigned rgb, unsigned alpha) {
    if (!vox_native_service_ready()) return;
    glBlendEquationSeparate(rgb,alpha);
}
VOX_EGL_LINKAGE void vox_gl_blend_func(unsigned src, unsigned dst) {
    if (!vox_native_service_ready()) return;
    glBlendFunc(src,dst);
}
VOX_EGL_LINKAGE void vox_gl_blend_func_separate(unsigned srgb, unsigned drgb, unsigned sa, unsigned da) {
    if (!vox_native_service_ready()) return;
    glBlendFuncSeparate(srgb,drgb,sa,da);
}
VOX_EGL_LINKAGE void vox_gl_cull_face(unsigned mode) {
    if (!vox_native_service_ready()) return;
    glCullFace(mode);
}
VOX_EGL_LINKAGE void vox_gl_depth_func(unsigned function) {
    if (!vox_native_service_ready()) return;
    glDepthFunc(function);
}
VOX_EGL_LINKAGE void vox_gl_depth_range(float near_value, float far_value) {
    if (!vox_native_service_ready()) return;
    glDepthRangef(near_value,far_value);
}
VOX_EGL_LINKAGE void vox_gl_finish(void) {
    if (!vox_native_service_ready()) return;
    glFinish();
}
VOX_EGL_LINKAGE void vox_gl_flush(void) {
    if (!vox_native_service_ready()) return;
    glFlush();
}
VOX_EGL_LINKAGE void vox_gl_front_face(unsigned mode) {
    if (!vox_native_service_ready()) return;
    glFrontFace(mode);
}
VOX_EGL_LINKAGE void vox_gl_generate_mipmap(unsigned target) {
    if (!vox_native_service_ready()) return;
    glGenerateMipmap(target);
}
VOX_EGL_LINKAGE void vox_gl_hint(unsigned target, unsigned mode)
{
    if (!vox_native_service_ready()) return;

#if VOX_NATIVE_GL_DESKTOP
    if (target == GL_GENERATE_MIPMAP_HINT) {
        if (mode != GL_FASTEST && mode != GL_NICEST && mode != GL_DONT_CARE) vox_native_gl_error(GL_INVALID_ENUM);
        return;
    }
#endif
    glHint(target,mode);
}
VOX_EGL_LINKAGE void vox_gl_line_width(float value) {
    if (!vox_native_service_ready()) return;
    glLineWidth(value);
}
VOX_EGL_LINKAGE void vox_gl_polygon_offset(float factor, float units) {
    if (!vox_native_service_ready()) return;
    glPolygonOffset(factor,units);
}
VOX_EGL_LINKAGE void vox_gl_sample_coverage(float value, int invert) {
    if (!vox_native_service_ready()) return;
    glSampleCoverage(value,invert);
}
VOX_EGL_LINKAGE void vox_gl_stencil_func(unsigned function, int reference, unsigned mask) {
    if (!vox_native_service_ready()) return;
    glStencilFunc(function,reference,mask);
}
VOX_EGL_LINKAGE void vox_gl_stencil_func_separate(unsigned face, unsigned function, int reference, unsigned mask) {
    if (!vox_native_service_ready()) return;
    glStencilFuncSeparate(face,function,reference,mask);
}
VOX_EGL_LINKAGE void vox_gl_stencil_mask(unsigned mask) {
    if (!vox_native_service_ready()) return;
    glStencilMask(mask);
}
VOX_EGL_LINKAGE void vox_gl_stencil_mask_separate(unsigned face, unsigned mask) {
    if (!vox_native_service_ready()) return;
    glStencilMaskSeparate(face,mask);
}
VOX_EGL_LINKAGE void vox_gl_stencil_op(unsigned fail, unsigned depth_fail, unsigned pass) {
    if (!vox_native_service_ready()) return;
    glStencilOp(fail,depth_fail,pass);
}
VOX_EGL_LINKAGE void vox_gl_stencil_op_separate(unsigned face, unsigned fail, unsigned depth_fail, unsigned pass) {
    if (!vox_native_service_ready()) return;
    glStencilOpSeparate(face,fail,depth_fail,pass);
}
VOX_EGL_LINKAGE void vox_gl_clear_buffer_floats(unsigned buffer, int draw_buffer, float const* values) {
    if (!vox_native_service_ready()) return;
    glClearBufferfv(buffer,draw_buffer,values);
}
VOX_EGL_LINKAGE void vox_gl_clear_buffer_ints(unsigned buffer, int draw_buffer, int const* values) {
    if (!vox_native_service_ready()) return;
    glClearBufferiv(buffer,draw_buffer,values);
}
VOX_EGL_LINKAGE void vox_gl_clear_buffer_uints(unsigned buffer, int draw_buffer, unsigned const* values) {
    if (!vox_native_service_ready()) return;
    glClearBufferuiv(buffer,draw_buffer,values);
}
VOX_EGL_LINKAGE void vox_gl_clear_buffer_depth_stencil(unsigned buffer, int draw_buffer, float depth, int stencil) {
    if (!vox_native_service_ready()) return;
    glClearBufferfi(buffer,draw_buffer,depth,stencil);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_i4i(unsigned index, int x, int y, int z, int w) {
    if (!vox_native_service_ready()) return;
    glVertexAttribI4i(index, x, y, z, w);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_i4ui(unsigned index, unsigned x, unsigned y, unsigned z, unsigned w) {
    if (!vox_native_service_ready()) return;
    glVertexAttribI4ui(index, x, y, z, w);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_ints(unsigned index, int const* values) {
    if (!vox_native_service_ready()) return;
    glVertexAttribI4iv(index,values);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_uints(unsigned index, unsigned const* values) {
    if (!vox_native_service_ready()) return;
    glVertexAttribI4uiv(index,values);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_int_parameter(unsigned index, int* values) {
    if (!vox_native_service_ready()) return;
    glGetVertexAttribIiv(index,GL_CURRENT_VERTEX_ATTRIB,values);
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_uint_parameter(unsigned index, unsigned* values) {
    if (!vox_native_service_ready()) return;
    glGetVertexAttribIuiv(index,GL_CURRENT_VERTEX_ATTRIB,values);
}
VOX_EGL_LINKAGE void vox_gl_float_parameter(unsigned pname, float* values) {
    if (!vox_native_service_ready()) return;
    glGetFloatv(pname,values);
}
VOX_EGL_LINKAGE void vox_gl_int_parameter(unsigned pname, int* values) {
    if (!vox_native_service_ready()) return;
    vox_native_integer_parameter(pname,values);
}
VOX_EGL_LINKAGE unsigned vox_gl_create_shader(unsigned type) {
    if (!vox_native_service_ready()) return 0;
    if (type != GL_VERTEX_SHADER && type != GL_FRAGMENT_SHADER) { vox_native_gl_error(GL_INVALID_ENUM); return 0; } return glCreateShader(type);
}
VOX_EGL_LINKAGE unsigned vox_gl_create_program(void) {
    if (!vox_native_service_ready()) return 0;
    return glCreateProgram();
}
VOX_EGL_LINKAGE void vox_gl_shader_source(unsigned shader, char const* source, int length)
{
    if (!vox_native_service_ready()) return;

    VoxEGLContext* context = vox_native_gl_current();
    if (!context) return;
    if (length < 0 || !source) { vox_native_gl_error(GL_INVALID_VALUE); return; }
    if (!vox_native_shader_source(&context->shader_sources, shader, source, length, context->version))
        vox_native_gl_error(GL_OUT_OF_MEMORY);
}
VOX_EGL_LINKAGE void vox_gl_compile_shader(unsigned shader) {
    if (!vox_native_service_ready()) return;
    glCompileShader(shader);
}
VOX_EGL_LINKAGE void vox_gl_attach_shader(unsigned program, unsigned shader) {
    if (!vox_native_service_ready()) return;
    glAttachShader(program, shader);
}
VOX_EGL_LINKAGE void vox_gl_detach_shader(unsigned program, unsigned shader) {
    if (!vox_native_service_ready()) return;
    glDetachShader(program, shader);
}
VOX_EGL_LINKAGE void vox_gl_link_program(unsigned program) {
    if (!vox_native_service_ready()) return;
    glLinkProgram(program);
}
VOX_EGL_LINKAGE void vox_gl_use_program(unsigned program) {
    if (!vox_native_service_ready()) return;
    glUseProgram(program);
}
VOX_EGL_LINKAGE void vox_gl_validate_program(unsigned program) {
    if (!vox_native_service_ready()) return;
    glValidateProgram(program);
}
VOX_EGL_LINKAGE void vox_gl_delete_shader(unsigned shader)
{
    if (!vox_native_service_ready()) return;

    VoxEGLContext* context = vox_native_gl_current();
    if (context) vox_native_shader_delete_source(&context->shader_sources, shader);
    glDeleteShader(shader);
}
VOX_EGL_LINKAGE void vox_gl_delete_program(unsigned program) {
    if (!vox_native_service_ready()) return;
    glDeleteProgram(program);
}
VOX_EGL_LINKAGE int vox_gl_shader_parameter(unsigned shader, unsigned pname)
{
    if (!vox_native_service_ready()) return 0;

    VoxEGLContext* context = vox_native_gl_current();
    if (pname == GL_SHADER_SOURCE_LENGTH && context) {
        int length = vox_native_shader_source_length(context->shader_sources, shader);
        if (length >= 0) return length;
    }
    GLint value = 0; glGetShaderiv(shader, pname, &value); return value;
}
VOX_EGL_LINKAGE int vox_gl_shader_parameter_robust(unsigned shader, unsigned pname)
{
    if (!vox_native_service_ready()) return 0;

    VoxEGLContext* context = vox_native_gl_current();
    if (pname == GL_SHADER_SOURCE_LENGTH && context) {
        int length = vox_native_shader_source_length(context->shader_sources, shader);
        if (length >= 0) return length;
    }
    GLint value = 0; glGetShaderiv(shader, pname, &value); return value;
}
VOX_EGL_LINKAGE int vox_gl_program_parameter(unsigned program, unsigned pname) {
    if (!vox_native_service_ready()) return 0;
    GLint value = 0; if (vox_native_scalar_program_parameter(pname)) glGetProgramiv(program, pname, &value); return value;
}
VOX_EGL_LINKAGE int vox_gl_program_parameter_robust(unsigned program, unsigned pname) {
    if (!vox_native_service_ready()) return 0;
    return vox_gl_program_parameter(program, pname);
}
VOX_EGL_LINKAGE void vox_gl_shader_log(unsigned shader, int size, char* output) {
    if (!vox_native_service_ready()) return;
    glGetShaderInfoLog(shader, size, NULL, output);
}
VOX_EGL_LINKAGE void vox_gl_get_shader_source(unsigned shader, int size, char* output)
{
    if (!vox_native_service_ready()) return;

    VoxEGLContext* context = vox_native_gl_current();
    if (context && vox_native_shader_get_source(context->shader_sources, shader, size, output)) return;
    glGetShaderSource(shader, size, NULL, output);
}
VOX_EGL_LINKAGE void vox_gl_program_log(unsigned program, int size, char* output) {
    if (!vox_native_service_ready()) return;
    glGetProgramInfoLog(program, size, NULL, output);
}
VOX_EGL_LINKAGE int vox_gl_uniform_location(unsigned program, char const* name) {
    if (!vox_native_service_ready()) return 0;
    return glGetUniformLocation(program, name);
}
VOX_EGL_LINKAGE int vox_gl_attrib_location(unsigned program, char const* name) {
    if (!vox_native_service_ready()) return 0;
    return glGetAttribLocation(program, name);
}
VOX_EGL_LINKAGE void vox_gl_bind_attrib_location(unsigned program, unsigned index, char const* name) {
    if (!vox_native_service_ready()) return;
    glBindAttribLocation(program, index, name);
}
VOX_EGL_LINKAGE int vox_gl_active_info(unsigned program, unsigned index, int uniform, int capacity, char* name, int* size, unsigned* type)
{
    if (!vox_native_service_ready()) return 0;

    GLsizei length = 0;
    if (uniform)
        glGetActiveUniform(program, index, capacity, &length, size, type, name);
    else
        glGetActiveAttrib(program, index, capacity, &length, size, type, name);
    return length;
}
VOX_EGL_LINKAGE void vox_gl_uniform_indices(unsigned program, int count, void const* names, unsigned* result) {
    if (!vox_native_service_ready()) return;
    glGetUniformIndices(program,count,(char const* const*)names,result);
}
VOX_EGL_LINKAGE void vox_gl_active_uniforms(unsigned program, int count, unsigned const* indices, unsigned pname, int* result) {
    if (!vox_native_service_ready()) return;
    glGetActiveUniformsiv(program,count,indices,pname,result);
}
VOX_EGL_LINKAGE unsigned vox_gl_uniform_block_index(unsigned program, char const* name) {
    if (!vox_native_service_ready()) return 0;
    return glGetUniformBlockIndex(program,name);
}
VOX_EGL_LINKAGE void vox_gl_uniform_block_parameter(unsigned program, unsigned index, unsigned pname, int capacity, int* result)
{
    if (!vox_native_service_ready()) return;

    if (capacity < 0 || (capacity && !result)) { vox_native_gl_error(GL_INVALID_VALUE); return; }
    GLint count = 1;
    if (pname == GL_UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES)
        glGetActiveUniformBlockiv(program, index, GL_UNIFORM_BLOCK_ACTIVE_UNIFORMS, &count);
    if (count < 0 || count > capacity) { vox_native_gl_error(GL_INVALID_OPERATION); return; }
    if (count) glGetActiveUniformBlockiv(program, index, pname, result);
}
VOX_EGL_LINKAGE void vox_gl_uniform_block_name(unsigned program, unsigned index, int capacity, char* name) {
    if (!vox_native_service_ready()) return;
    glGetActiveUniformBlockName(program,index,capacity,NULL,name);
}
VOX_EGL_LINKAGE void vox_gl_uniform_block_binding(unsigned program, unsigned index, unsigned binding) {
    if (!vox_native_service_ready()) return;
    glUniformBlockBinding(program,index,binding);
}
VOX_EGL_LINKAGE void vox_gl_internalformat_parameter(unsigned target, unsigned format, unsigned pname, int capacity, int* result) {
    if (!vox_native_service_ready()) return;
    vox_native_internalformat_parameter(target,format,pname,capacity,result);
}
VOX_EGL_LINKAGE void vox_gl_shader_precision(unsigned shader, unsigned precision, int* range, int* bits) {
    if (!vox_native_service_ready()) return;
    vox_native_shader_precision(shader, precision, range, bits);
}
VOX_EGL_LINKAGE void vox_gl_uniform1f(int location, float x) {
    if (!vox_native_service_ready()) return;
    glUniform1f(location, x);
}
VOX_EGL_LINKAGE void vox_gl_uniform2f(int location, float x, float y) {
    if (!vox_native_service_ready()) return;
    glUniform2f(location, x, y);
}
VOX_EGL_LINKAGE void vox_gl_uniform3f(int location, float x, float y, float z) {
    if (!vox_native_service_ready()) return;
    glUniform3f(location, x, y, z);
}
VOX_EGL_LINKAGE void vox_gl_uniform4f(int location, float x, float y, float z, float w) {
    if (!vox_native_service_ready()) return;
    glUniform4f(location, x, y, z, w);
}
VOX_EGL_LINKAGE void vox_gl_uniform1i(int location, int x) {
    if (!vox_native_service_ready()) return;
    glUniform1i(location, x);
}
VOX_EGL_LINKAGE void vox_gl_uniform2i(int location, int x, int y) {
    if (!vox_native_service_ready()) return;
    glUniform2i(location, x, y);
}
VOX_EGL_LINKAGE void vox_gl_uniform3i(int location, int x, int y, int z) {
    if (!vox_native_service_ready()) return;
    glUniform3i(location, x, y, z);
}
VOX_EGL_LINKAGE void vox_gl_uniform4i(int location, int x, int y, int z, int w) {
    if (!vox_native_service_ready()) return;
    glUniform4i(location, x, y, z, w);
}
VOX_EGL_LINKAGE void vox_gl_uniform1ui(int location, unsigned x) {
    if (!vox_native_service_ready()) return;
    glUniform1ui(location, x);
}
VOX_EGL_LINKAGE void vox_gl_uniform2ui(int location, unsigned x, unsigned y) {
    if (!vox_native_service_ready()) return;
    glUniform2ui(location, x, y);
}
VOX_EGL_LINKAGE void vox_gl_uniform3ui(int location, unsigned x, unsigned y, unsigned z) {
    if (!vox_native_service_ready()) return;
    glUniform3ui(location, x, y, z);
}
VOX_EGL_LINKAGE void vox_gl_uniform4ui(int location, unsigned x, unsigned y, unsigned z, unsigned w) {
    if (!vox_native_service_ready()) return;
    glUniform4ui(location, x, y, z, w);
}
VOX_EGL_LINKAGE void vox_gl_uniform_floats(int location, int width, int count, float const* data)
{
    if (!vox_native_service_ready()) return;

    switch (width) {
    case 1: glUniform1fv(location, count, data); break;
    case 2: glUniform2fv(location, count, data); break;
    case 3: glUniform3fv(location, count, data); break;
    case 4: glUniform4fv(location, count, data); break;
    }
}
VOX_EGL_LINKAGE void vox_gl_uniform_ints(int location, int width, int count, int const* data)
{
    if (!vox_native_service_ready()) return;

    switch (width) {
    case 1: glUniform1iv(location, count, data); break;
    case 2: glUniform2iv(location, count, data); break;
    case 3: glUniform3iv(location, count, data); break;
    case 4: glUniform4iv(location, count, data); break;
    }
}
VOX_EGL_LINKAGE void vox_gl_uniform_uints(int location, int width, int count, unsigned const* data)
{
    if (!vox_native_service_ready()) return;

    switch (width) {
    case 1: glUniform1uiv(location, count, data); break;
    case 2: glUniform2uiv(location, count, data); break;
    case 3: glUniform3uiv(location, count, data); break;
    case 4: glUniform4uiv(location, count, data); break;
    }
}
VOX_EGL_LINKAGE void vox_gl_uniform_matrix(int location, int columns, int rows, int count, int transpose, float const* data)
{
    if (!vox_native_service_ready()) return;

    if (columns == 2 && rows == 2) glUniformMatrix2fv(location, count, transpose, data);
    else if (columns == 3 && rows == 3) glUniformMatrix3fv(location, count, transpose, data);
    else if (columns == 4 && rows == 4) glUniformMatrix4fv(location, count, transpose, data);
    else if (columns == 2 && rows == 3) glUniformMatrix2x3fv(location, count, transpose, data);
    else if (columns == 3 && rows == 2) glUniformMatrix3x2fv(location, count, transpose, data);
    else if (columns == 2 && rows == 4) glUniformMatrix2x4fv(location, count, transpose, data);
    else if (columns == 4 && rows == 2) glUniformMatrix4x2fv(location, count, transpose, data);
    else if (columns == 3 && rows == 4) glUniformMatrix3x4fv(location, count, transpose, data);
    else if (columns == 4 && rows == 3) glUniformMatrix4x3fv(location, count, transpose, data);
}
VOX_EGL_LINKAGE void vox_gl_get_uniform_floats(unsigned program, int location, float* data) {
    if (!vox_native_service_ready()) return;
    glGetUniformfv(program, location, data);
}
VOX_EGL_LINKAGE void vox_gl_get_uniform_ints(unsigned program, int location, int* data) {
    if (!vox_native_service_ready()) return;
    glGetUniformiv(program, location, data);
}
VOX_EGL_LINKAGE void vox_gl_get_uniform_uints(unsigned program, int location, unsigned* data) {
    if (!vox_native_service_ready()) return;
    glGetUniformuiv(program, location, data);
}

// Source WebGLRenderingContextImpl::get_parameter native result types/counts.
VOX_EGL_LINKAGE int vox_gl_parameter_shape(unsigned pname, int version) {
    switch (pname) {
    case GL_ACTIVE_TEXTURE:
    case GL_ALPHA_BITS:
    case GL_BLEND_DST_ALPHA:
    case GL_BLEND_DST_RGB:
    case GL_BLEND_EQUATION_ALPHA:
    case GL_BLEND_EQUATION_RGB:
    case GL_BLEND_SRC_ALPHA:
    case GL_BLEND_SRC_RGB:
    case GL_BLUE_BITS:
    case GL_CULL_FACE_MODE:
    case GL_DEPTH_BITS:
    case GL_DEPTH_FUNC:
    case GL_FRONT_FACE:
    case GL_GENERATE_MIPMAP_HINT:
    case GL_GREEN_BITS:
    case GL_IMPLEMENTATION_COLOR_READ_FORMAT:
    case GL_IMPLEMENTATION_COLOR_READ_TYPE:
    case GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS:
    case GL_MAX_CUBE_MAP_TEXTURE_SIZE:
    case GL_MAX_FRAGMENT_UNIFORM_VECTORS:
    case GL_MAX_RENDERBUFFER_SIZE:
    case GL_MAX_TEXTURE_IMAGE_UNITS:
    case GL_MAX_TEXTURE_SIZE:
    case GL_MAX_VARYING_VECTORS:
    case GL_MAX_VERTEX_ATTRIBS:
    case GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS:
    case GL_MAX_VERTEX_UNIFORM_VECTORS:
    case GL_PACK_ALIGNMENT:
    case GL_RED_BITS:
    case GL_SAMPLE_BUFFERS:
    case GL_SAMPLES:
    case GL_STENCIL_BACK_FAIL:
    case GL_STENCIL_BACK_FUNC:
    case GL_STENCIL_BACK_PASS_DEPTH_FAIL:
    case GL_STENCIL_BACK_PASS_DEPTH_PASS:
    case GL_STENCIL_BACK_REF:
    case GL_STENCIL_BACK_VALUE_MASK:
    case GL_STENCIL_BACK_WRITEMASK:
    case GL_STENCIL_BITS:
    case GL_STENCIL_CLEAR_VALUE:
    case GL_STENCIL_FAIL:
    case GL_STENCIL_FUNC:
    case GL_STENCIL_PASS_DEPTH_FAIL:
    case GL_STENCIL_PASS_DEPTH_PASS:
    case GL_STENCIL_REF:
    case GL_STENCIL_VALUE_MASK:
    case GL_STENCIL_WRITEMASK:
    case GL_SUBPIXEL_BITS:
    case GL_UNPACK_ALIGNMENT:
    case GL_FRAGMENT_SHADER_DERIVATIVE_HINT:
    case GL_MAX_COLOR_ATTACHMENTS:
    case GL_MAX_DRAW_BUFFERS:
        return 11;
    case GL_ALIASED_LINE_WIDTH_RANGE:
    case GL_ALIASED_POINT_SIZE_RANGE:
    case GL_DEPTH_RANGE:
        return 22;
    case GL_BLEND:
    case GL_CULL_FACE:
    case GL_DEPTH_TEST:
    case GL_DEPTH_WRITEMASK:
    case GL_DITHER:
    case GL_POLYGON_OFFSET_FILL:
    case GL_SAMPLE_ALPHA_TO_COVERAGE:
    case GL_SAMPLE_COVERAGE:
    case GL_SAMPLE_COVERAGE_INVERT:
    case GL_SCISSOR_TEST:
    case GL_STENCIL_TEST:
        return 31;
    case GL_BLEND_COLOR:
    case GL_COLOR_CLEAR_VALUE:
        return 24;
    case GL_COLOR_WRITEMASK:
        return 34;
    case GL_DEPTH_CLEAR_VALUE:
    case GL_LINE_WIDTH:
    case GL_POLYGON_OFFSET_FACTOR:
    case GL_POLYGON_OFFSET_UNITS:
    case GL_SAMPLE_COVERAGE_VALUE:
    case GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT:
        return 21;
    case GL_MAX_VIEWPORT_DIMS:
        return 12;
    case GL_RENDERER:
    case GL_SHADING_LANGUAGE_VERSION:
    case GL_VENDOR:
    case GL_VERSION:
        return 51;
    case GL_SCISSOR_BOX:
    case GL_VIEWPORT:
        return 14;
    case GL_MAX_SAMPLES:
    case GL_MAX_3D_TEXTURE_SIZE:
    case GL_MAX_ARRAY_TEXTURE_LAYERS:
    case GL_MAX_VERTEX_UNIFORM_COMPONENTS:
    case GL_MAX_UNIFORM_BUFFER_BINDINGS:
    case GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT:
    case GL_MAX_VERTEX_UNIFORM_BLOCKS:
    case GL_MAX_FRAGMENT_INPUT_COMPONENTS:
    case GL_MAX_FRAGMENT_UNIFORM_COMPONENTS:
    case GL_MAX_COMBINED_UNIFORM_BLOCKS:
    case GL_MAX_FRAGMENT_UNIFORM_BLOCKS:
    case GL_MAX_VARYING_COMPONENTS:
    case GL_MAX_ELEMENTS_INDICES:
    case GL_MAX_ELEMENTS_VERTICES:
    case GL_MAX_TRANSFORM_FEEDBACK_INTERLEAVED_COMPONENTS:
    case GL_MAX_TRANSFORM_FEEDBACK_SEPARATE_ATTRIBS:
    case GL_MAX_TRANSFORM_FEEDBACK_SEPARATE_COMPONENTS:
    case GL_MIN_PROGRAM_TEXEL_OFFSET:
    case GL_MAX_PROGRAM_TEXEL_OFFSET:
    case GL_MAX_VERTEX_OUTPUT_COMPONENTS:
    case GL_PACK_ROW_LENGTH:
    case GL_PACK_SKIP_ROWS:
    case GL_PACK_SKIP_PIXELS:
    case GL_UNPACK_IMAGE_HEIGHT:
    case GL_UNPACK_ROW_LENGTH:
    case GL_UNPACK_SKIP_IMAGES:
    case GL_UNPACK_SKIP_PIXELS:
    case GL_UNPACK_SKIP_ROWS:
        return version == 3 ? 11 : 0;
    case GL_MAX_UNIFORM_BLOCK_SIZE:
    case GL_MAX_COMBINED_VERTEX_UNIFORM_COMPONENTS:
    case GL_MAX_COMBINED_FRAGMENT_UNIFORM_COMPONENTS:
    case GL_MAX_ELEMENT_INDEX:
    case GL_MAX_SERVER_WAIT_TIMEOUT:
        return version == 3 ? 41 : 0;
    case GL_MAX_TEXTURE_LOD_BIAS:
        return version == 3 ? 21 : 0;
    case GL_TRANSFORM_FEEDBACK_ACTIVE:
    case GL_TRANSFORM_FEEDBACK_PAUSED:
    case GL_RASTERIZER_DISCARD:
        return version == 3 ? 31 : 0;
    default: return 0;
    }
}
VOX_EGL_LINKAGE void vox_gl_parameter(unsigned pname, int shape, double* output)
{
    if (!vox_native_service_ready()) return;

    VoxEGLContext* context = vox_native_gl_current();
    if (!context || !output) return;
    if (shape != vox_gl_parameter_shape(pname, context->version) || shape == 0 || shape == 51) {
        vox_native_gl_error(GL_INVALID_ENUM);
        return;
    }
    int count = shape % 10;
    if (count < 1 || count > 4) { vox_native_gl_error(GL_INVALID_OPERATION); return; }
    switch (shape / 10) {
    case 1: {
        GLint values[4] = {0}; vox_native_integer_parameter(pname, values);
        for (int i = 0; i < count; ++i) output[i] = values[i];
        break;
    }
    case 2: {
        GLfloat values[4] = {0};
#if VOX_NATIVE_GL_DESKTOP
        if (pname == GL_ALIASED_POINT_SIZE_RANGE) pname = GL_POINT_SIZE_RANGE;
#endif
        glGetFloatv(pname, values);
        for (int i = 0; i < count; ++i) output[i] = values[i];
        break;
    }
    case 3: {
        GLboolean values[4] = {0}; glGetBooleanv(pname, values);
        for (int i = 0; i < count; ++i) output[i] = values[i] == GL_TRUE;
        break;
    }
    case 4: {
        GLint64 value = 0;
#ifdef __APPLE__
        if (pname == GL_MAX_ELEMENT_INDEX) value = UINT32_MAX;
        else
#endif
        glGetInteger64v(pname, &value);
        output[0] = (double)value; break;
    }
    }
}
#endif // implementation
#endif // VOX_WEBGL_NATIVE_EGL_H
