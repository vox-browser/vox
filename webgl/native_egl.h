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
#include <GLES3/gl3.h>

typedef struct {
    EGLDisplay display;
    EGLContext context;
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
    VoxEGLContext* result = malloc(sizeof(VoxEGLContext));
    if (!result) {
        eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        eglDestroyContext(display, context);
        return NULL;
    }
    result->display = display;
    result->context = context;
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
#endif
