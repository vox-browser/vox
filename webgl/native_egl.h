/* Copyright (c) 2026, Ladybird contributors
 * SPDX-License-Identifier: BSD-2-Clause
 * Services/Compositor/OpenGLContext.cpp CPU painting context creation.
 */
#ifndef VOX_WEBGL_NATIVE_EGL_H
#define VOX_WEBGL_NATIVE_EGL_H
#include <stdlib.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <EGL/eglext_angle.h>
#define GL_GLEXT_PROTOTYPES 1
#include <GLES3/gl3.h>
#include <GLES2/gl2ext.h>
#include <GLES2/gl2ext_angle.h>

typedef struct {
    EGLDisplay display;
    EGLContext context;
    int version;
    GLuint framebuffer;
    GLuint color_buffer;
    GLuint depth_buffer;
} VoxEGLContext;

static void* vox_egl_create(int version)
{
    EGLAttrib display_attributes[] = {
        EGL_PLATFORM_ANGLE_TYPE_ANGLE,
#ifdef __APPLE__
        EGL_PLATFORM_ANGLE_TYPE_METAL_ANGLE,
#elif defined(_WIN32)
        EGL_PLATFORM_ANGLE_TYPE_D3D11_ANGLE,
#else
        EGL_PLATFORM_ANGLE_TYPE_OPENGL_ANGLE,
        EGL_PLATFORM_ANGLE_NATIVE_PLATFORM_TYPE_ANGLE, EGL_PLATFORM_SURFACELESS_MESA,
#endif
        EGL_NONE,
    };
    EGLDisplay display = eglGetPlatformDisplay(EGL_PLATFORM_ANGLE_ANGLE, EGL_DEFAULT_DISPLAY, display_attributes);
    EGLint major, minor;
    if (display == EGL_NO_DISPLAY || !eglInitialize(display, &major, &minor))
        return NULL;
    EGLint config_attributes[] = {
        EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, 24, EGL_STENCIL_SIZE, 8, EGL_NONE,
    };
    EGLConfig config;
    EGLint count;
    if (!eglChooseConfig(display, config_attributes, &config, 1, &count) || count == 0)
        return NULL;
    EGLint context_attributes[] = {
        EGL_CONTEXT_CLIENT_VERSION, version,
        EGL_CONTEXT_WEBGL_COMPATIBILITY_ANGLE, EGL_TRUE,
        EGL_ROBUST_RESOURCE_INITIALIZATION_ANGLE, EGL_TRUE,
        EGL_CONTEXT_OPENGL_BACKWARDS_COMPATIBLE_ANGLE, EGL_FALSE,
        EGL_NONE,
    };
    EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, context_attributes);
    if (context == EGL_NO_CONTEXT)
        return NULL;
    if (!eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, context)) {
        eglDestroyContext(display, context);
        return NULL;
    }
    VoxEGLContext* result = calloc(1, sizeof(VoxEGLContext));
    if (!result) {
        eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        eglDestroyContext(display, context);
        return NULL;
    }
    result->display = display;
    result->context = context;
    result->version = version;
    return result;
}

static int vox_egl_make_current(void* handle)
{
    VoxEGLContext* context = handle;
    return context && eglMakeCurrent(context->display, EGL_NO_SURFACE, EGL_NO_SURFACE, context->context);
}

static void vox_egl_destroy(void* handle)
{
    VoxEGLContext* context = handle;
    if (!context)
        return;
    eglMakeCurrent(context->display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroyContext(context->display, context->context);
    free(context);
}

static void* vox_gl_fence_sync(unsigned condition, unsigned flags) { return glFenceSync(condition, flags); }
static unsigned vox_gl_client_wait_sync(void* sync, unsigned flags, unsigned long long timeout) { return glClientWaitSync(sync, flags, timeout); }
static void vox_gl_wait_sync(void* sync, unsigned flags, unsigned long long timeout) { glWaitSync(sync, flags, timeout); }
static void vox_gl_delete_sync(void* sync) { glDeleteSync(sync); }
static int vox_gl_get_sync_parameter(void* sync, unsigned pname)
{
    GLint result = 0;
    glGetSynciv(sync, pname, 1, NULL, &result);
    return result;
}
static unsigned vox_gl_get_error(void) { return glGetError(); }
static void vox_egl_free_surface(void* handle)
{
    VoxEGLContext* context = handle;
    if (!vox_egl_make_current(handle)) return;
    if (context->framebuffer) glDeleteFramebuffers(1, &context->framebuffer);
    if (context->color_buffer) glDeleteTextures(1, &context->color_buffer);
    if (context->depth_buffer) glDeleteRenderbuffers(1, &context->depth_buffer);
    context->framebuffer = context->color_buffer = context->depth_buffer = 0;
}
static int vox_egl_allocate_surface(void* handle, int width, int height, int depth, int stencil)
{
    VoxEGLContext* context = handle;
    if (!vox_egl_make_current(handle)) return 0;
    vox_egl_free_surface(handle);
    glGenTextures(1, &context->color_buffer);
    glBindTexture(GL_TEXTURE_2D, context->color_buffer);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    GLint original_pixel_unpack_buffer = 0;
    if (context->version == 3) {
        glGetIntegerv(GL_PIXEL_UNPACK_BUFFER_BINDING, &original_pixel_unpack_buffer);
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    }
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    if (context->version == 3)
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, original_pixel_unpack_buffer);
    glViewport(0, 0, width, height);
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
    return glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;
}
static unsigned vox_egl_default_framebuffer(void* handle) { return handle ? ((VoxEGLContext*)handle)->framebuffer : 0; }
static unsigned vox_egl_default_renderbuffer(void* handle) { return handle ? ((VoxEGLContext*)handle)->depth_buffer : 0; }
static unsigned vox_gl_gen_object(int kind)
{
    GLuint result = 0;
    switch (kind) {
    case 0: glGenBuffers(1, &result); break;
    case 1: glGenFramebuffers(1, &result); break;
    case 2: glGenRenderbuffers(1, &result); break;
    case 3: glGenTextures(1, &result); break;
    }
    return result;
}
static void vox_gl_delete_object(int kind, unsigned handle)
{
    switch (kind) {
    case 0: glDeleteBuffers(1, &handle); break;
    case 1: glDeleteFramebuffers(1, &handle); break;
    case 2: glDeleteRenderbuffers(1, &handle); break;
    case 3: glDeleteTextures(1, &handle); break;
    }
}
static void vox_gl_bind_framebuffer(unsigned target, unsigned handle) { glBindFramebuffer(target, handle); }
static void vox_gl_bind_renderbuffer(unsigned target, unsigned handle) { glBindRenderbuffer(target, handle); }
static void vox_gl_bind_texture(unsigned target, unsigned handle) { glBindTexture(target, handle); }
static unsigned vox_gl_framebuffer_status(unsigned target) { return glCheckFramebufferStatus(target); }
static void vox_gl_framebuffer_texture(unsigned target, unsigned attachment, unsigned texture_target, unsigned texture, int level) { glFramebufferTexture2D(target, attachment, texture_target, texture, level); }
static void vox_gl_framebuffer_renderbuffer(unsigned target, unsigned attachment, unsigned renderbuffer_target, unsigned renderbuffer) { glFramebufferRenderbuffer(target, attachment, renderbuffer_target, renderbuffer); }
static void vox_gl_renderbuffer_storage(unsigned target, unsigned format, int width, int height) { glRenderbufferStorage(target, format, width, height); }
static void vox_gl_tex_image2d(unsigned target, int level, int format, int width, int height, int border, unsigned pixel_format, unsigned type, int capacity, void const* data) { glTexImage2DRobustANGLE(target, level, format, width, height, border, pixel_format, type, capacity, data); }
static void vox_gl_tex_sub_image2d(unsigned target, int level, int x, int y, int width, int height, unsigned format, unsigned type, int capacity, void const* data) { glTexSubImage2DRobustANGLE(target, level, x, y, width, height, format, type, capacity, data); }
static void vox_gl_tex_parameteri(unsigned target, unsigned pname, int value) { glTexParameteri(target, pname, value); }
static void vox_gl_tex_parameterf(unsigned target, unsigned pname, float value) { glTexParameterf(target, pname, value); }
static int vox_gl_read_pixels(int x, int y, int width, int height, unsigned format, unsigned type, int capacity, void* data)
{
    GLsizei written = 0;
    glReadPixelsRobustANGLE(x, y, width, height, format, type, capacity, &written, NULL, NULL, data);
    return written;
}
static void vox_gl_clear_color(float r, float g, float b, float a) { glClearColor(r, g, b, a); }
static void vox_gl_clear_depth(float value) { glClearDepthf(value); }
static void vox_gl_clear_stencil(int value) { glClearStencil(value); }
static void vox_gl_color_mask(int r, int g, int b, int a) { glColorMask(r, g, b, a); }
static void vox_gl_depth_mask(int value) { glDepthMask(value); }
static void vox_gl_clear(unsigned mask) { glClear(mask); }
static void vox_gl_viewport(int x, int y, int w, int h) { glViewport(x, y, w, h); }
static void vox_gl_scissor(int x, int y, int w, int h) { glScissor(x, y, w, h); }
static void vox_gl_enable(unsigned cap) { glEnable(cap); }
static void vox_gl_disable(unsigned cap) { glDisable(cap); }
static void vox_gl_pixel_storei(unsigned pname, int value) { glPixelStorei(pname, value); }
static unsigned vox_gl_create_shader(unsigned type) { return glCreateShader(type); }
static unsigned vox_gl_create_program(void) { return glCreateProgram(); }
static void vox_gl_shader_source(unsigned shader, char const* source, int length) { glShaderSource(shader, 1, &source, &length); }
static void vox_gl_compile_shader(unsigned shader) { glCompileShader(shader); }
static void vox_gl_attach_shader(unsigned program, unsigned shader) { glAttachShader(program, shader); }
static void vox_gl_detach_shader(unsigned program, unsigned shader) { glDetachShader(program, shader); }
static void vox_gl_link_program(unsigned program) { glLinkProgram(program); }
static void vox_gl_use_program(unsigned program) { glUseProgram(program); }
static void vox_gl_validate_program(unsigned program) { glValidateProgram(program); }
static void vox_gl_delete_shader(unsigned shader) { glDeleteShader(shader); }
static void vox_gl_delete_program(unsigned program) { glDeleteProgram(program); }
static int vox_gl_shader_parameter(unsigned shader, unsigned pname) { GLint value = 0; glGetShaderiv(shader, pname, &value); return value; }
static int vox_gl_program_parameter(unsigned program, unsigned pname) { GLint value = 0; glGetProgramiv(program, pname, &value); return value; }
static void vox_gl_shader_log(unsigned shader, int size, char* output) { glGetShaderInfoLog(shader, size, NULL, output); }
static void vox_gl_program_log(unsigned program, int size, char* output) { glGetProgramInfoLog(program, size, NULL, output); }
static int vox_gl_uniform_location(unsigned program, char const* name) { return glGetUniformLocation(program, name); }
static int vox_gl_attrib_location(unsigned program, char const* name) { return glGetAttribLocation(program, name); }
static void vox_gl_bind_attrib_location(unsigned program, unsigned index, char const* name) { glBindAttribLocation(program, index, name); }
static int vox_gl_active_info(unsigned program, unsigned index, int uniform, int capacity, char* name, int* size, unsigned* type)
{
    GLsizei length = 0;
    if (uniform)
        glGetActiveUniform(program, index, capacity, &length, size, type, name);
    else
        glGetActiveAttrib(program, index, capacity, &length, size, type, name);
    return length;
}
static void vox_gl_shader_precision(unsigned shader, unsigned precision, int* range, int* bits) { glGetShaderPrecisionFormat(shader, precision, range, bits); }
static void vox_gl_uniform_floats(int location, int width, int count, float const* data)
{
    switch (width) {
    case 1: glUniform1fv(location, count, data); break;
    case 2: glUniform2fv(location, count, data); break;
    case 3: glUniform3fv(location, count, data); break;
    case 4: glUniform4fv(location, count, data); break;
    }
}
static void vox_gl_uniform_ints(int location, int width, int count, int const* data)
{
    switch (width) {
    case 1: glUniform1iv(location, count, data); break;
    case 2: glUniform2iv(location, count, data); break;
    case 3: glUniform3iv(location, count, data); break;
    case 4: glUniform4iv(location, count, data); break;
    }
}
static void vox_gl_uniform_uints(int location, int width, int count, unsigned const* data)
{
    switch (width) {
    case 1: glUniform1uiv(location, count, data); break;
    case 2: glUniform2uiv(location, count, data); break;
    case 3: glUniform3uiv(location, count, data); break;
    case 4: glUniform4uiv(location, count, data); break;
    }
}
static void vox_gl_uniform_matrix(int location, int columns, int rows, int count, float const* data)
{
    if (columns == 2 && rows == 2) glUniformMatrix2fv(location, count, GL_FALSE, data);
    else if (columns == 3 && rows == 3) glUniformMatrix3fv(location, count, GL_FALSE, data);
    else if (columns == 4 && rows == 4) glUniformMatrix4fv(location, count, GL_FALSE, data);
    else if (columns == 2 && rows == 3) glUniformMatrix2x3fv(location, count, GL_FALSE, data);
    else if (columns == 3 && rows == 2) glUniformMatrix3x2fv(location, count, GL_FALSE, data);
    else if (columns == 2 && rows == 4) glUniformMatrix2x4fv(location, count, GL_FALSE, data);
    else if (columns == 4 && rows == 2) glUniformMatrix4x2fv(location, count, GL_FALSE, data);
    else if (columns == 3 && rows == 4) glUniformMatrix3x4fv(location, count, GL_FALSE, data);
    else if (columns == 4 && rows == 3) glUniformMatrix4x3fv(location, count, GL_FALSE, data);
}
static void vox_gl_get_uniform_floats(unsigned program, int location, float* data) { glGetUniformfv(program, location, data); }
static void vox_gl_get_uniform_ints(unsigned program, int location, int* data) { glGetUniformiv(program, location, data); }
static void vox_gl_get_uniform_uints(unsigned program, int location, unsigned* data) { glGetUniformuiv(program, location, data); }
#endif
