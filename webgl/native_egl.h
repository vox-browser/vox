/* Copyright (c) 2026, Ladybird contributors
 * SPDX-License-Identifier: BSD-2-Clause
 * Services/Compositor/OpenGLContext.cpp CPU painting context creation.
 */
#ifndef VOX_WEBGL_NATIVE_EGL_H
#define VOX_WEBGL_NATIVE_EGL_H
#ifdef __APPLE__
#error "macOS WebGL uses the V Metal service, not EGL"
#endif
#if defined(_WIN32) && !defined(VOX_EGL_IMPLEMENTATION)
#include "native_egl_api.h"
#else
#ifdef _WIN32
#define VOX_EGL_LINKAGE
#else
#define VOX_EGL_LINKAGE static
#endif
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#define GL_GLEXT_PROTOTYPES 1
#include <GLES3/gl3.h>
#include <GLES2/gl2ext.h>
#ifdef _WIN32
#include "native_wgl.h"
#endif
#include "gles_adapter.h"

typedef struct {
#ifdef _WIN32
    VoxWGLContext windows;
#else
    EGLDisplay display;
    EGLContext context;
#endif
    int version;
    VoxGLESState state;
    GLuint framebuffer;
    GLuint color_buffer;
    GLuint depth_buffer;
} VoxEGLContext;

VOX_EGL_LINKAGE void* vox_egl_create(int version)
{ VOX_GLES_CALL;
    if (version!=2 && version!=3) return NULL;
#ifdef _WIN32
    VoxEGLContext* result=calloc(1,sizeof(VoxEGLContext));
    if(!result)return NULL;
    if(!vox_wgl_create(&result->windows)){free(result);return NULL;}
    result->state.windows=&result->windows;
#else
#ifdef __linux__
    EGLDisplay display=eglGetPlatformDisplay(EGL_PLATFORM_SURFACELESS_MESA,EGL_DEFAULT_DISPLAY,NULL);
#else
    EGLDisplay display=eglGetDisplay(EGL_DEFAULT_DISPLAY);
#endif
    EGLint major, minor;
    if (display == EGL_NO_DISPLAY || !eglInitialize(display, &major, &minor)) {
#ifdef __linux__
        display=eglGetDisplay(EGL_DEFAULT_DISPLAY);
        if(display==EGL_NO_DISPLAY || !eglInitialize(display,&major,&minor)) return NULL;
#else
        return NULL;
#endif
    }
    EGLint config_attributes[] = {
        EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE,
        EGL_OPENGL_ES3_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, 24, EGL_STENCIL_SIZE, 8, EGL_NONE,
    };
    EGLConfig config;
    EGLint count;
    if (!eglChooseConfig(display, config_attributes, &config, 1, &count) || count == 0)
        return NULL;
    if (!eglBindAPI(EGL_OPENGL_ES_API)) return NULL;
    EGLint context_attributes[] = {
        /* GLES3 supplies the WebGL1 extension commands without vendor dispatch. */
        EGL_CONTEXT_CLIENT_VERSION, 3,
        EGL_CONTEXT_OPENGL_ROBUST_ACCESS_EXT, EGL_TRUE,
        EGL_NONE,
    };
    EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, context_attributes);
    if (context == EGL_NO_CONTEXT)
        return NULL;
    if (!eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, context)) {
        eglDestroyContext(display, context);
        return NULL;
    }
    /* Never submit untrusted shaders to a context that ignored the requested
     * robust access flag. An unavailable guarantee means WebGL is unavailable. */
    GLboolean robust=GL_FALSE;
    glGetBooleanv(GL_CONTEXT_ROBUST_ACCESS_KHR,&robust);
    if(robust!=GL_TRUE || glGetError()!=GL_NO_ERROR) {
        eglMakeCurrent(display,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);
        eglDestroyContext(display,context);
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
    result->state.display=display;result->state.context=context;
#endif
    result->version = version;
    result->state.webgl_version=version;
    vox_gles_current=&result->state;
    if (version==3) glEnable(GL_PRIMITIVE_RESTART_FIXED_INDEX);
    GLint gl_major=0,gl_minor=0;glGetIntegerv(GL_MAJOR_VERSION,&gl_major);glGetIntegerv(GL_MINOR_VERSION,&gl_minor);
    if(gl_major>3 || (gl_major==3 && gl_minor>=1))
        result->state.texture_level_parameter=(void (GL_APIENTRYP)(GLenum,GLint,GLenum,GLint*))
#ifdef _WIN32
            (void*)vox_wgl.procedure("glGetTexLevelParameteriv");
#else
            eglGetProcAddress("glGetTexLevelParameteriv");
#endif
    return result;
}

VOX_EGL_LINKAGE int vox_egl_make_current(void* handle)
{ VOX_GLES_CALL;
    VoxEGLContext* context = handle;
#ifdef _WIN32
    if(!context || !vox_wgl.bind(context->windows.dc,context->windows.context))return 0;
#else
    if (!context || !eglMakeCurrent(context->display,EGL_NO_SURFACE,EGL_NO_SURFACE,context->context)) return 0;
#endif
    vox_gles_current=&context->state;
    return 1;
}

VOX_EGL_LINKAGE void vox_egl_destroy(void* handle)
{ VOX_GLES_CALL;
    VoxEGLContext* context = handle;
    if (!context)
        return;
#ifdef _WIN32
    vox_wgl_destroy(&context->windows);
#else
    if (eglGetCurrentContext()==context->context) {
        eglMakeCurrent(context->display,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);
        vox_gles_current=NULL;
    }
    eglDestroyContext(context->display, context->context);
#endif
    if(vox_gles_current==&context->state)vox_gles_current=NULL;
    free(context->state.extensions);
    free(context);
}

VOX_EGL_LINKAGE void* vox_gl_fence_sync(unsigned condition, unsigned flags) { VOX_GLES_CALL; return glFenceSync(condition, flags); }
VOX_EGL_LINKAGE unsigned vox_gl_client_wait_sync(void* sync, unsigned flags, unsigned long long timeout) { VOX_GLES_CALL; return glClientWaitSync(sync, flags, timeout); }
VOX_EGL_LINKAGE void vox_gl_wait_sync(void* sync, unsigned flags, unsigned long long timeout) { VOX_GLES_CALL; glWaitSync(sync, flags, timeout); }
VOX_EGL_LINKAGE void vox_gl_delete_sync(void* sync) { VOX_GLES_CALL; glDeleteSync(sync); }
VOX_EGL_LINKAGE int vox_gl_get_sync_parameter(void* sync, unsigned pname)
{ VOX_GLES_CALL;
    GLint result = 0;
    glGetSynciv(sync, pname, 1, NULL, &result);
    return result;
}
VOX_EGL_LINKAGE int vox_gl_is_sync(void* sync) { VOX_GLES_CALL; return glIsSync(sync); }
VOX_EGL_LINKAGE void vox_gl_attached_shaders(unsigned program, int capacity, int* count, unsigned* shaders) { VOX_GLES_CALL; glGetAttachedShaders(program, capacity, count, shaders); }
VOX_EGL_LINKAGE int vox_gl_query_target_parameter(unsigned target, unsigned pname) { VOX_GLES_CALL; GLint result=0;glGetQueryiv(target,pname,&result);return result; }
VOX_EGL_LINKAGE int vox_gl_framebuffer_attachment_parameter(unsigned target, unsigned attachment, unsigned pname) { VOX_GLES_CALL; GLint result=0;glGetFramebufferAttachmentParameteriv(target,attachment,pname,&result);return result; }
VOX_EGL_LINKAGE unsigned vox_gl_get_error(void) { VOX_GLES_CALL; return glGetError(); }
VOX_EGL_LINKAGE int vox_gl_is_object(int kind, unsigned handle) { VOX_GLES_CALL;
    switch (kind) {
    case 0: return glIsBuffer(handle);
    case 1: return glIsFramebuffer(handle);
    case 2: return glIsRenderbuffer(handle);
    case 3: return glIsTexture(handle);
    case 4: return glIsQuery(handle);
    case 5: return glIsSampler(handle);
    case 8: return glIsTransformFeedback(handle);
    case 9: return glIsShader(handle);
    case 10: return glIsProgram(handle);
    default: return GL_FALSE;
    }
}
VOX_EGL_LINKAGE char const* vox_gl_string(unsigned name) { VOX_GLES_CALL; return (char const*)glGetString(name); }
VOX_EGL_LINKAGE void vox_gl_request_extension(char const* name) { VOX_GLES_CALL; glRequestExtensionANGLE(name); }
VOX_EGL_LINKAGE void vox_egl_free_surface(void* handle)
{ VOX_GLES_CALL;
    VoxEGLContext* context = handle;
    if (!vox_egl_make_current(handle)) return;
    if (context->framebuffer) glDeleteFramebuffers(1, &context->framebuffer);
    if (context->color_buffer) glDeleteTextures(1, &context->color_buffer);
    if (context->depth_buffer) glDeleteRenderbuffers(1, &context->depth_buffer);
    context->framebuffer = context->color_buffer = context->depth_buffer = 0;
}
VOX_EGL_LINKAGE int vox_egl_allocate_surface(void* handle, int width, int height, int depth, int stencil)
{ VOX_GLES_CALL;
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
    glTexImage2DRobustANGLE(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0, NULL);
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
VOX_EGL_LINKAGE unsigned vox_egl_default_framebuffer(void* handle) { VOX_GLES_CALL; return handle ? ((VoxEGLContext*)handle)->framebuffer : 0; }
VOX_EGL_LINKAGE unsigned vox_egl_default_renderbuffer(void* handle) { VOX_GLES_CALL; return handle ? ((VoxEGLContext*)handle)->depth_buffer : 0; }
/* OpenGLContext::copy_default_framebuffer_to_cpu_painting_surface. */
VOX_EGL_LINKAGE int vox_egl_copy_drawing_buffer(void* handle, int width, int height, unsigned char* pixels)
{ VOX_GLES_CALL;
    VoxEGLContext* context = handle;
    if (!vox_egl_make_current(handle) || !context->framebuffer || !pixels) return 0;
    GLenum target = context->version == 3 ? GL_READ_FRAMEBUFFER : GL_FRAMEBUFFER;
    GLenum binding = context->version == 3 ? GL_READ_FRAMEBUFFER_BINDING : GL_FRAMEBUFFER_BINDING;
    GLint original_framebuffer, original_read_buffer = GL_COLOR_ATTACHMENT0, original_alignment;
    glGetIntegerv(binding, &original_framebuffer);
    if (context->version == 3) glGetIntegerv(GL_READ_BUFFER, &original_read_buffer);
    glBindFramebuffer(target,context->framebuffer);
    if (context->version == 3) glReadBuffer(GL_COLOR_ATTACHMENT0);
    glGetIntegerv(GL_PACK_ALIGNMENT,&original_alignment);
    glPixelStorei(GL_PACK_ALIGNMENT,4);
    GLint original_buffer = 0, original_row_length = 0, original_skip_pixels = 0, original_skip_rows = 0;
    if (context->version == 3) {
        glGetIntegerv(GL_PIXEL_PACK_BUFFER_BINDING,&original_buffer);
        glBindBuffer(GL_PIXEL_PACK_BUFFER,0);
        glGetIntegerv(GL_PACK_ROW_LENGTH,&original_row_length);
        glGetIntegerv(GL_PACK_SKIP_PIXELS,&original_skip_pixels);
        glGetIntegerv(GL_PACK_SKIP_ROWS,&original_skip_rows);
        glPixelStorei(GL_PACK_ROW_LENGTH,0);
        glPixelStorei(GL_PACK_SKIP_PIXELS,0);
        glPixelStorei(GL_PACK_SKIP_ROWS,0);
    }
    for (int source_y = 0; source_y < height; ++source_y)
        glReadPixels(0,source_y,width,1,GL_RGBA,GL_UNSIGNED_BYTE,pixels+(size_t)(height-source_y-1)*width*4);
    if (context->version == 3) {
        glPixelStorei(GL_PACK_ROW_LENGTH,original_row_length);
        glPixelStorei(GL_PACK_SKIP_PIXELS,original_skip_pixels);
        glPixelStorei(GL_PACK_SKIP_ROWS,original_skip_rows);
        glBindBuffer(GL_PIXEL_PACK_BUFFER,original_buffer);
    }
    glPixelStorei(GL_PACK_ALIGNMENT,original_alignment);
    glBindFramebuffer(target,original_framebuffer);
    if (context->version == 3) glReadBuffer(original_read_buffer);
    return 1;
}
/* OpenGLContext::clear_buffer_to_default_values. */
VOX_EGL_LINKAGE void vox_egl_clear_drawing_buffer(void* handle)
{ VOX_GLES_CALL;
    VoxEGLContext* context = handle;
    if (!vox_egl_make_current(handle) || !context->framebuffer) return;
    GLenum target = context->version == 3 ? GL_DRAW_FRAMEBUFFER : GL_FRAMEBUFFER;
    GLenum binding = context->version == 3 ? GL_DRAW_FRAMEBUFFER_BINDING : GL_FRAMEBUFFER_BINDING;
    GLint original_framebuffer, original_renderbuffer, stencil;
    GLfloat color[4], depth;
    glGetIntegerv(binding,&original_framebuffer);
    glGetIntegerv(GL_RENDERBUFFER_BINDING,&original_renderbuffer);
    glBindFramebuffer(target,context->framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER,context->depth_buffer);
    glGetFloatv(GL_COLOR_CLEAR_VALUE,color);
    glGetFloatv(GL_DEPTH_CLEAR_VALUE,&depth);
    glGetIntegerv(GL_STENCIL_CLEAR_VALUE,&stencil);
    glClearColor(0,0,0,0); glClearDepthf(1); glClearStencil(0);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT|GL_STENCIL_BUFFER_BIT);
    glClearColor(color[0],color[1],color[2],color[3]); glClearDepthf(depth); glClearStencil(stencil);
    glBindFramebuffer(target,original_framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER,original_renderbuffer);
}
VOX_EGL_LINKAGE unsigned vox_gl_gen_object(int kind)
{ VOX_GLES_CALL;
    GLuint result = 0;
    switch (kind) {
    case 0: glGenBuffers(1, &result); break;
    case 1: glGenFramebuffers(1, &result); break;
    case 2: glGenRenderbuffers(1, &result); break;
    case 3: glGenTextures(1, &result); break;
    case 4: glGenQueries(1, &result); break;
    case 5: glGenSamplers(1, &result); break;
    case 6: glGenVertexArrays(1, &result); break;
    case 7: glGenVertexArraysOES(1, &result); break;
    case 8: glGenTransformFeedbacks(1, &result); break;
    }
    return result;
}
VOX_EGL_LINKAGE void vox_gl_delete_object(int kind, unsigned handle)
{ VOX_GLES_CALL;
    switch (kind) {
    case 0: glDeleteBuffers(1, &handle); break;
    case 1: glDeleteFramebuffers(1, &handle); break;
    case 2: glDeleteRenderbuffers(1, &handle); break;
    case 3: glDeleteTextures(1, &handle); break;
    case 4: glDeleteQueries(1, &handle); break;
    case 5: glDeleteSamplers(1, &handle); break;
    case 6: glDeleteVertexArrays(1, &handle); break;
    case 7: glDeleteVertexArraysOES(1, &handle); break;
    case 8: glDeleteTransformFeedbacks(1, &handle); break;
    }
}
VOX_EGL_LINKAGE void vox_gl_begin_query(unsigned target, unsigned handle) { VOX_GLES_CALL; glBeginQuery(target, handle); }
VOX_EGL_LINKAGE void vox_gl_end_query(unsigned target) { VOX_GLES_CALL; glEndQuery(target); }
VOX_EGL_LINKAGE unsigned vox_gl_query_parameter(unsigned handle, unsigned pname) { VOX_GLES_CALL; GLuint result = 0; glGetQueryObjectuivRobustANGLE(handle, pname, 1, NULL, &result); return result; }
VOX_EGL_LINKAGE void vox_gl_bind_sampler(unsigned unit, unsigned handle) { VOX_GLES_CALL; glBindSampler(unit, handle); }
VOX_EGL_LINKAGE void vox_gl_sampler_parameteri(unsigned handle, unsigned pname, int value) { VOX_GLES_CALL; glSamplerParameteri(handle, pname, value); }
VOX_EGL_LINKAGE void vox_gl_sampler_parameterf(unsigned handle, unsigned pname, float value) { VOX_GLES_CALL; glSamplerParameterf(handle, pname, value); }
VOX_EGL_LINKAGE float vox_gl_sampler_parameter(unsigned handle, unsigned pname) { VOX_GLES_CALL; GLfloat result = 0; glGetSamplerParameterfvRobustANGLE(handle, pname, 1, NULL, &result); return result; }
VOX_EGL_LINKAGE void vox_gl_bind_vertex_array(unsigned handle, int oes) { VOX_GLES_CALL; if (oes) glBindVertexArrayOES(handle); else glBindVertexArray(handle); }
VOX_EGL_LINKAGE int vox_gl_is_vertex_array(unsigned handle, int oes) { VOX_GLES_CALL; return oes ? glIsVertexArrayOES(handle) : glIsVertexArray(handle); }
VOX_EGL_LINKAGE int vox_gl_vertex_attrib_parameter(unsigned index, unsigned pname) { VOX_GLES_CALL; GLint result = 0; glGetVertexAttribivRobustANGLE(index,pname,1,NULL,&result); return result; }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_float_parameter(unsigned index, float* result) { VOX_GLES_CALL; glGetVertexAttribfvRobustANGLE(index,GL_CURRENT_VERTEX_ATTRIB,4,NULL,result); }
VOX_EGL_LINKAGE long long vox_gl_vertex_attrib_offset(unsigned index) { VOX_GLES_CALL; void* result = NULL; glGetVertexAttribPointervRobustANGLE(index,GL_VERTEX_ATTRIB_ARRAY_POINTER,1,NULL,&result); return (intptr_t)result; }
VOX_EGL_LINKAGE void vox_gl_bind_transform_feedback(unsigned target, unsigned handle) { VOX_GLES_CALL; glBindTransformFeedback(target,handle); }
VOX_EGL_LINKAGE void vox_gl_begin_transform_feedback(unsigned mode) { VOX_GLES_CALL; glBeginTransformFeedback(mode); }
VOX_EGL_LINKAGE void vox_gl_end_transform_feedback(void) { VOX_GLES_CALL; glEndTransformFeedback(); }
VOX_EGL_LINKAGE void vox_gl_pause_transform_feedback(void) { VOX_GLES_CALL; glPauseTransformFeedback(); }
VOX_EGL_LINKAGE void vox_gl_resume_transform_feedback(void) { VOX_GLES_CALL; glResumeTransformFeedback(); }
VOX_EGL_LINKAGE void vox_gl_transform_feedback_varyings(unsigned program, int count, void const* names, unsigned mode) { VOX_GLES_CALL; glTransformFeedbackVaryings(program,count,(char const* const*)names,mode); }
VOX_EGL_LINKAGE void vox_gl_bind_buffer_base(unsigned target, unsigned index, unsigned buffer) { VOX_GLES_CALL; glBindBufferBase(target,index,buffer); }
VOX_EGL_LINKAGE void vox_gl_bind_buffer_range(unsigned target, unsigned index, unsigned buffer, long long offset, long long size) { VOX_GLES_CALL; glBindBufferRange(target,index,buffer,(GLintptr)offset,(GLsizeiptr)size); }
VOX_EGL_LINKAGE void vox_gl_bind_buffer(unsigned target, unsigned handle) { VOX_GLES_CALL; glBindBuffer(target, handle); }
VOX_EGL_LINKAGE void vox_gl_buffer_data(unsigned target, long long size, void const* data, unsigned usage) { VOX_GLES_CALL; glBufferData(target, (GLsizeiptr)size, data, usage); }
VOX_EGL_LINKAGE void vox_gl_buffer_sub_data(unsigned target, long long offset, long long size, void const* data) { VOX_GLES_CALL; glBufferSubData(target, (GLintptr)offset, (GLsizeiptr)size, data); }
VOX_EGL_LINKAGE void vox_gl_copy_buffer_sub_data(unsigned read_target, unsigned write_target, long long read_offset, long long write_offset, long long size) { VOX_GLES_CALL; glCopyBufferSubData(read_target, write_target, (GLintptr)read_offset, (GLintptr)write_offset, (GLsizeiptr)size); }
/* Services/Compositor/HostWebGLContext.cpp::read_buffer_sub_data. */
VOX_EGL_LINKAGE int vox_gl_read_buffer_sub_data(unsigned target, long long offset, long long size, void* data) { VOX_GLES_CALL;
    if (size<0 || offset<0 || (size && !data)) {vox_gles_error(GL_INVALID_VALUE);return 0;}
    if (size == 0) return 1;
    void* mapped = glMapBufferRange(target, (GLintptr)offset, (GLsizeiptr)size, GL_MAP_READ_BIT);
    if (!mapped) return 0;
    memcpy(data, mapped, (size_t)size);
    glUnmapBuffer(target);
    return 1;
}
VOX_EGL_LINKAGE int vox_gl_buffer_parameter(unsigned target, unsigned pname) { VOX_GLES_CALL;
    GLint result = 0;
    glGetBufferParameterivRobustANGLE(target, pname, 1, NULL, &result);
    return result;
}
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_pointer(unsigned index, int size, unsigned type, int normalized, int stride, long long offset) { VOX_GLES_CALL; glVertexAttribPointer(index, size, type, normalized, stride, (void const*)(intptr_t)offset); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_i_pointer(unsigned index, int size, unsigned type, int stride, long long offset) { VOX_GLES_CALL; glVertexAttribIPointer(index, size, type, stride, (void const*)(intptr_t)offset); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib1f(unsigned index, float x) { VOX_GLES_CALL; glVertexAttrib1f(index, x); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib2f(unsigned index, float x, float y) { VOX_GLES_CALL; glVertexAttrib2f(index, x, y); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib3f(unsigned index, float x, float y, float z) { VOX_GLES_CALL; glVertexAttrib3f(index, x, y, z); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib4f(unsigned index, float x, float y, float z, float w) { VOX_GLES_CALL; glVertexAttrib4f(index, x, y, z, w); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib1fv(unsigned index, float const* data) { VOX_GLES_CALL; glVertexAttrib1fv(index, data); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib2fv(unsigned index, float const* data) { VOX_GLES_CALL; glVertexAttrib2fv(index, data); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib3fv(unsigned index, float const* data) { VOX_GLES_CALL; glVertexAttrib3fv(index, data); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_floats(unsigned index, float const* data) { VOX_GLES_CALL; glVertexAttrib4fv(index, data); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_enable(unsigned index, int enabled) { VOX_GLES_CALL; if (enabled) glEnableVertexAttribArray(index); else glDisableVertexAttribArray(index); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_divisor(unsigned index, unsigned divisor, int version) { VOX_GLES_CALL; if (version == 3) glVertexAttribDivisor(index, divisor); else glVertexAttribDivisorANGLE(index, divisor); }
VOX_EGL_LINKAGE void vox_gl_draw_arrays(unsigned mode, int first, int count) { VOX_GLES_CALL; glDrawArrays(mode, first, count); }
VOX_EGL_LINKAGE void vox_gl_draw_elements(unsigned mode, int count, unsigned type, long long offset) { VOX_GLES_CALL; glDrawElements(mode, count, type, (void const*)(intptr_t)offset); }
VOX_EGL_LINKAGE void vox_gl_draw_arrays_instanced(unsigned mode, int first, int count, int instances, int version) { VOX_GLES_CALL; if (version == 3) glDrawArraysInstanced(mode, first, count, instances); else glDrawArraysInstancedANGLE(mode, first, count, instances); }
VOX_EGL_LINKAGE void vox_gl_draw_elements_instanced(unsigned mode, int count, unsigned type, long long offset, int instances, int version) { VOX_GLES_CALL; if (version == 3) glDrawElementsInstanced(mode, count, type, (void const*)(intptr_t)offset, instances); else glDrawElementsInstancedANGLE(mode, count, type, (void const*)(intptr_t)offset, instances); }
VOX_EGL_LINKAGE void vox_gl_draw_range_elements(unsigned mode, unsigned start, unsigned end, int count, unsigned type, long long offset) { VOX_GLES_CALL; glDrawRangeElements(mode, start, end, count, type, (void const*)(intptr_t)offset); }
VOX_EGL_LINKAGE void vox_gl_bind_framebuffer(unsigned target, unsigned handle) { VOX_GLES_CALL; glBindFramebuffer(target, handle); }
VOX_EGL_LINKAGE void vox_gl_bind_renderbuffer(unsigned target, unsigned handle) { VOX_GLES_CALL; glBindRenderbuffer(target, handle); }
VOX_EGL_LINKAGE void vox_gl_bind_texture(unsigned target, unsigned handle) { VOX_GLES_CALL; glBindTexture(target, handle); }
VOX_EGL_LINKAGE unsigned vox_gl_framebuffer_status(unsigned target) { VOX_GLES_CALL; return glCheckFramebufferStatus(target); }
VOX_EGL_LINKAGE void vox_gl_framebuffer_texture(unsigned target, unsigned attachment, unsigned texture_target, unsigned texture, int level) { VOX_GLES_CALL; glFramebufferTexture2D(target, attachment, texture_target, texture, level); }
VOX_EGL_LINKAGE void vox_gl_framebuffer_renderbuffer(unsigned target, unsigned attachment, unsigned renderbuffer_target, unsigned renderbuffer) { VOX_GLES_CALL; glFramebufferRenderbuffer(target, attachment, renderbuffer_target, renderbuffer); }
VOX_EGL_LINKAGE void vox_gl_renderbuffer_storage(unsigned target, unsigned format, int width, int height) { VOX_GLES_CALL; glRenderbufferStorage(target, format, width, height); }
VOX_EGL_LINKAGE void vox_gl_tex_image2d(unsigned target, int level, int format, int width, int height, int border, unsigned pixel_format, unsigned type, int capacity, void const* data) { VOX_GLES_CALL; glTexImage2DRobustANGLE(target, level, format, width, height, border, pixel_format, type, capacity, data); }
// This ANGLE ABI exposes core compressed entry points. Source imageSize and
// dataSize are identical; the native imageSize remains the exact input bound.
VOX_EGL_LINKAGE void vox_gl_compressed_tex_image2d(unsigned target, int level, unsigned format, int width, int height, int border, int size, void const* data) { VOX_GLES_CALL; glCompressedTexImage2D(target, level, format, width, height, border, size, data); }
VOX_EGL_LINKAGE void vox_gl_compressed_tex_sub_image2d(unsigned target, int level, int x, int y, int width, int height, unsigned format, int size, void const* data) { VOX_GLES_CALL; glCompressedTexSubImage2D(target, level, x, y, width, height, format, size, data); }
VOX_EGL_LINKAGE void vox_gl_compressed_tex_image3d(unsigned target, int level, unsigned format, int width, int height, int depth, int border, int size, void const* data) { VOX_GLES_CALL; glCompressedTexImage3D(target, level, format, width, height, depth, border, size, data); }
VOX_EGL_LINKAGE void vox_gl_compressed_tex_sub_image3d(unsigned target, int level, int x, int y, int z, int width, int height, int depth, unsigned format, int size, void const* data) { VOX_GLES_CALL; glCompressedTexSubImage3D(target, level, x, y, z, width, height, depth, format, size, data); }
VOX_EGL_LINKAGE void vox_gl_tex_sub_image2d(unsigned target, int level, int x, int y, int width, int height, unsigned format, unsigned type, int capacity, void const* data) { VOX_GLES_CALL; glTexSubImage2DRobustANGLE(target, level, x, y, width, height, format, type, capacity, data); }
VOX_EGL_LINKAGE void vox_gl_tex_parameteri(unsigned target, unsigned pname, int value) { VOX_GLES_CALL; glTexParameteri(target, pname, value); }
VOX_EGL_LINKAGE void vox_gl_tex_parameterf(unsigned target, unsigned pname, float value) { VOX_GLES_CALL; glTexParameterf(target, pname, value); }
VOX_EGL_LINKAGE void vox_gl_tex_storage2d(unsigned target, int levels, unsigned format, int width, int height) { VOX_GLES_CALL; glTexStorage2D(target, levels, format, width, height); }
VOX_EGL_LINKAGE void vox_gl_tex_storage3d(unsigned target, int levels, unsigned format, int width, int height, int depth) { VOX_GLES_CALL; glTexStorage3D(target, levels, format, width, height, depth); }
VOX_EGL_LINKAGE void vox_gl_tex_image3d(unsigned target, int level, int format, int width, int height, int depth, int border, unsigned pixel_format, unsigned type, int capacity, void const* data) { VOX_GLES_CALL; glTexImage3DRobustANGLE(target, level, format, width, height, depth, border, pixel_format, type, capacity, data); }
VOX_EGL_LINKAGE void vox_gl_tex_sub_image3d(unsigned target, int level, int x, int y, int z, int width, int height, int depth, unsigned format, unsigned type, int capacity, void const* data) { VOX_GLES_CALL; glTexSubImage3DRobustANGLE(target, level, x, y, z, width, height, depth, format, type, capacity, data); }
VOX_EGL_LINKAGE void vox_gl_framebuffer_texture_layer(unsigned target, unsigned attachment, unsigned texture, int level, int layer) { VOX_GLES_CALL; glFramebufferTextureLayer(target, attachment, texture, level, layer); }
VOX_EGL_LINKAGE void vox_gl_copy_tex_image2d(unsigned target, int level, unsigned format, int x, int y, int width, int height, int border) { VOX_GLES_CALL; glCopyTexImage2D(target, level, format, x, y, width, height, border); }
VOX_EGL_LINKAGE void vox_gl_copy_tex_sub_image2d(unsigned target, int level, int x_offset, int y_offset, int x, int y, int width, int height) { VOX_GLES_CALL; glCopyTexSubImage2D(target, level, x_offset, y_offset, x, y, width, height); }
VOX_EGL_LINKAGE void vox_gl_draw_buffers(int count, unsigned const* buffers, int extension) { VOX_GLES_CALL; if (extension) glDrawBuffersEXT(count, buffers); else glDrawBuffers(count, buffers); }
VOX_EGL_LINKAGE void vox_gl_read_buffer(unsigned source) { VOX_GLES_CALL; glReadBuffer(source); }
VOX_EGL_LINKAGE void vox_gl_blit_framebuffer(int sx0, int sy0, int sx1, int sy1, int dx0, int dy0, int dx1, int dy1, unsigned mask, unsigned filter) { VOX_GLES_CALL; glBlitFramebuffer(sx0, sy0, sx1, sy1, dx0, dy0, dx1, dy1, mask, filter); }
VOX_EGL_LINKAGE void vox_gl_renderbuffer_storage_multisample(unsigned target, int samples, unsigned format, int width, int height) { VOX_GLES_CALL; glRenderbufferStorageMultisample(target, samples, format, width, height); }
VOX_EGL_LINKAGE void vox_gl_invalidate_framebuffer(unsigned target, int count, unsigned const* attachments) { VOX_GLES_CALL; glInvalidateFramebuffer(target, count, attachments); }
VOX_EGL_LINKAGE void vox_gl_invalidate_sub_framebuffer(unsigned target, int count, unsigned const* attachments, int x, int y, int width, int height) { VOX_GLES_CALL; glInvalidateSubFramebuffer(target, count, attachments, x, y, width, height); }
VOX_EGL_LINKAGE int vox_gl_tex_parameter(unsigned target, unsigned pname) { VOX_GLES_CALL; GLint value = 0; glGetTexParameterivRobustANGLE(target, pname, 1, NULL, &value); return value; }
VOX_EGL_LINKAGE float vox_gl_tex_float_parameter(unsigned target, unsigned pname) { VOX_GLES_CALL; GLfloat value = 0; glGetTexParameterfvRobustANGLE(target, pname, 1, NULL, &value); return value; }
VOX_EGL_LINKAGE int vox_gl_renderbuffer_parameter(unsigned target, unsigned pname) { VOX_GLES_CALL; GLint value = 0; glGetRenderbufferParameterivRobustANGLE(target, pname, 1, NULL, &value); return value; }
// WebGL2RenderingContextOverloads::read_pixels numeric offset variant.
VOX_EGL_LINKAGE void vox_gl_read_pixels_to_buffer(int x, int y, int width, int height, unsigned format, unsigned type, int64_t offset)
{ VOX_GLES_CALL;
    GLint buffer=0;glGetIntegerv(GL_PIXEL_PACK_BUFFER_BINDING,&buffer);
    if (!buffer) { vox_gles_error(GL_INVALID_OPERATION);return; }
    glReadPixels(x,y,width,height,format,type,(void*)(intptr_t)offset);
}
VOX_EGL_LINKAGE int vox_gl_read_pixels(int x, int y, int width, int height, unsigned format, unsigned type, int capacity, void* data)
{ VOX_GLES_CALL;
    GLsizei written = 0;
    glReadPixelsRobustANGLE(x, y, width, height, format, type, capacity, &written, NULL, NULL, data);
    return written;
}
VOX_EGL_LINKAGE void vox_gl_clear_color(float r, float g, float b, float a) { VOX_GLES_CALL; glClearColor(r, g, b, a); }
VOX_EGL_LINKAGE void vox_gl_clear_depth(float value) { VOX_GLES_CALL; glClearDepthf(value); }
VOX_EGL_LINKAGE void vox_gl_clear_stencil(int value) { VOX_GLES_CALL; glClearStencil(value); }
VOX_EGL_LINKAGE void vox_gl_color_mask(int r, int g, int b, int a) { VOX_GLES_CALL; glColorMask(r, g, b, a); }
VOX_EGL_LINKAGE void vox_gl_depth_mask(int value) { VOX_GLES_CALL; glDepthMask(value); }
VOX_EGL_LINKAGE void vox_gl_clear(unsigned mask) { VOX_GLES_CALL; glClear(mask); }
VOX_EGL_LINKAGE void vox_gl_viewport(int x, int y, int w, int h) { VOX_GLES_CALL; glViewport(x, y, w, h); }
VOX_EGL_LINKAGE void vox_gl_scissor(int x, int y, int w, int h) { VOX_GLES_CALL; glScissor(x, y, w, h); }
VOX_EGL_LINKAGE void vox_gl_enable(unsigned cap) { VOX_GLES_CALL; glEnable(cap); }
VOX_EGL_LINKAGE int vox_gl_is_enabled(unsigned cap) { VOX_GLES_CALL; return glIsEnabled(cap); }
VOX_EGL_LINKAGE void vox_gl_disable(unsigned cap) { VOX_GLES_CALL; glDisable(cap); }
VOX_EGL_LINKAGE void vox_gl_pixel_storei(unsigned pname, int value) { VOX_GLES_CALL; glPixelStorei(pname, value); }
VOX_EGL_LINKAGE void vox_gl_active_texture(unsigned texture) { VOX_GLES_CALL; glActiveTexture(texture); }
VOX_EGL_LINKAGE void vox_gl_blend_color(float r, float g, float b, float a) { VOX_GLES_CALL; glBlendColor(r,g,b,a); }
VOX_EGL_LINKAGE void vox_gl_blend_equation(unsigned mode) { VOX_GLES_CALL; glBlendEquation(mode); }
VOX_EGL_LINKAGE void vox_gl_blend_equation_separate(unsigned rgb, unsigned alpha) { VOX_GLES_CALL; glBlendEquationSeparate(rgb,alpha); }
VOX_EGL_LINKAGE void vox_gl_blend_func(unsigned src, unsigned dst) { VOX_GLES_CALL; glBlendFunc(src,dst); }
VOX_EGL_LINKAGE void vox_gl_blend_func_separate(unsigned srgb, unsigned drgb, unsigned sa, unsigned da) { VOX_GLES_CALL; glBlendFuncSeparate(srgb,drgb,sa,da); }
VOX_EGL_LINKAGE void vox_gl_cull_face(unsigned mode) { VOX_GLES_CALL; glCullFace(mode); }
VOX_EGL_LINKAGE void vox_gl_depth_func(unsigned function) { VOX_GLES_CALL; glDepthFunc(function); }
VOX_EGL_LINKAGE void vox_gl_depth_range(float near_value, float far_value) { VOX_GLES_CALL; glDepthRangef(near_value,far_value); }
VOX_EGL_LINKAGE void vox_gl_finish(void) { VOX_GLES_CALL; glFinish(); }
VOX_EGL_LINKAGE void vox_gl_flush(void) { VOX_GLES_CALL; glFlush(); }
VOX_EGL_LINKAGE void vox_gl_front_face(unsigned mode) { VOX_GLES_CALL; glFrontFace(mode); }
VOX_EGL_LINKAGE void vox_gl_generate_mipmap(unsigned target) { VOX_GLES_CALL; glGenerateMipmap(target); }
VOX_EGL_LINKAGE void vox_gl_hint(unsigned target, unsigned mode) { VOX_GLES_CALL; glHint(target,mode); }
VOX_EGL_LINKAGE void vox_gl_line_width(float value) { VOX_GLES_CALL; glLineWidth(value); }
VOX_EGL_LINKAGE void vox_gl_polygon_offset(float factor, float units) { VOX_GLES_CALL; glPolygonOffset(factor,units); }
VOX_EGL_LINKAGE void vox_gl_sample_coverage(float value, int invert) { VOX_GLES_CALL; glSampleCoverage(value,invert); }
VOX_EGL_LINKAGE void vox_gl_stencil_func(unsigned function, int reference, unsigned mask) { VOX_GLES_CALL; glStencilFunc(function,reference,mask); }
VOX_EGL_LINKAGE void vox_gl_stencil_func_separate(unsigned face, unsigned function, int reference, unsigned mask) { VOX_GLES_CALL; glStencilFuncSeparate(face,function,reference,mask); }
VOX_EGL_LINKAGE void vox_gl_stencil_mask(unsigned mask) { VOX_GLES_CALL; glStencilMask(mask); }
VOX_EGL_LINKAGE void vox_gl_stencil_mask_separate(unsigned face, unsigned mask) { VOX_GLES_CALL; glStencilMaskSeparate(face,mask); }
VOX_EGL_LINKAGE void vox_gl_stencil_op(unsigned fail, unsigned depth_fail, unsigned pass) { VOX_GLES_CALL; glStencilOp(fail,depth_fail,pass); }
VOX_EGL_LINKAGE void vox_gl_stencil_op_separate(unsigned face, unsigned fail, unsigned depth_fail, unsigned pass) { VOX_GLES_CALL; glStencilOpSeparate(face,fail,depth_fail,pass); }
VOX_EGL_LINKAGE void vox_gl_clear_buffer_floats(unsigned buffer, int draw_buffer, float const* values) { VOX_GLES_CALL; glClearBufferfv(buffer,draw_buffer,values); }
VOX_EGL_LINKAGE void vox_gl_clear_buffer_ints(unsigned buffer, int draw_buffer, int const* values) { VOX_GLES_CALL; glClearBufferiv(buffer,draw_buffer,values); }
VOX_EGL_LINKAGE void vox_gl_clear_buffer_uints(unsigned buffer, int draw_buffer, unsigned const* values) { VOX_GLES_CALL; glClearBufferuiv(buffer,draw_buffer,values); }
VOX_EGL_LINKAGE void vox_gl_clear_buffer_depth_stencil(unsigned buffer, int draw_buffer, float depth, int stencil) { VOX_GLES_CALL; glClearBufferfi(buffer,draw_buffer,depth,stencil); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_i4i(unsigned index, int x, int y, int z, int w) { VOX_GLES_CALL; glVertexAttribI4i(index, x, y, z, w); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_i4ui(unsigned index, unsigned x, unsigned y, unsigned z, unsigned w) { VOX_GLES_CALL; glVertexAttribI4ui(index, x, y, z, w); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_ints(unsigned index, int const* values) { VOX_GLES_CALL; glVertexAttribI4iv(index,values); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_uints(unsigned index, unsigned const* values) { VOX_GLES_CALL; glVertexAttribI4uiv(index,values); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_int_parameter(unsigned index, int* values) { VOX_GLES_CALL; glGetVertexAttribIiv(index,GL_CURRENT_VERTEX_ATTRIB,values); }
VOX_EGL_LINKAGE void vox_gl_vertex_attrib_uint_parameter(unsigned index, unsigned* values) { VOX_GLES_CALL; glGetVertexAttribIuiv(index,GL_CURRENT_VERTEX_ATTRIB,values); }
VOX_EGL_LINKAGE void vox_gl_float_parameter(unsigned pname, float* values) { VOX_GLES_CALL; glGetFloatv(pname,values); }
VOX_EGL_LINKAGE void vox_gl_int_parameter(unsigned pname, int* values) { VOX_GLES_CALL; glGetIntegerv(pname,values); }
VOX_EGL_LINKAGE unsigned vox_gl_create_shader(unsigned type) { VOX_GLES_CALL; return glCreateShader(type); }
VOX_EGL_LINKAGE unsigned vox_gl_create_program(void) { VOX_GLES_CALL; return glCreateProgram(); }
VOX_EGL_LINKAGE void vox_gl_shader_source(unsigned shader, char const* source, int length) { VOX_GLES_CALL; glShaderSource(shader, 1, &source, &length); }
VOX_EGL_LINKAGE void vox_gl_compile_shader(unsigned shader) { VOX_GLES_CALL; glCompileShader(shader); }
VOX_EGL_LINKAGE void vox_gl_attach_shader(unsigned program, unsigned shader) { VOX_GLES_CALL; glAttachShader(program, shader); }
VOX_EGL_LINKAGE void vox_gl_detach_shader(unsigned program, unsigned shader) { VOX_GLES_CALL; glDetachShader(program, shader); }
VOX_EGL_LINKAGE void vox_gl_link_program(unsigned program) { VOX_GLES_CALL; glLinkProgram(program); }
VOX_EGL_LINKAGE void vox_gl_use_program(unsigned program) { VOX_GLES_CALL; glUseProgram(program); }
VOX_EGL_LINKAGE void vox_gl_validate_program(unsigned program) { VOX_GLES_CALL; glValidateProgram(program); }
VOX_EGL_LINKAGE void vox_gl_delete_shader(unsigned shader) { VOX_GLES_CALL; glDeleteShader(shader); }
VOX_EGL_LINKAGE void vox_gl_delete_program(unsigned program) { VOX_GLES_CALL; glDeleteProgram(program); }
VOX_EGL_LINKAGE int vox_gl_shader_parameter(unsigned shader, unsigned pname) { VOX_GLES_CALL; GLint value = 0; glGetShaderiv(shader, pname, &value); return value; }
VOX_EGL_LINKAGE int vox_gl_shader_parameter_robust(unsigned shader, unsigned pname) { VOX_GLES_CALL; GLint value = 0; glGetShaderivRobustANGLE(shader, pname, 1, NULL, &value); return value; }
VOX_EGL_LINKAGE int vox_gl_program_parameter(unsigned program, unsigned pname) { VOX_GLES_CALL; GLint value = 0; glGetProgramiv(program, pname, &value); return value; }
VOX_EGL_LINKAGE int vox_gl_program_parameter_robust(unsigned program, unsigned pname) { VOX_GLES_CALL; GLint value = 0; glGetProgramivRobustANGLE(program, pname, 1, NULL, &value); return value; }
VOX_EGL_LINKAGE void vox_gl_shader_log(unsigned shader, int size, char* output) { VOX_GLES_CALL; glGetShaderInfoLog(shader, size, NULL, output); }
VOX_EGL_LINKAGE void vox_gl_get_shader_source(unsigned shader, int size, char* output) { VOX_GLES_CALL; glGetShaderSource(shader, size, NULL, output); }
VOX_EGL_LINKAGE void vox_gl_program_log(unsigned program, int size, char* output) { VOX_GLES_CALL; glGetProgramInfoLog(program, size, NULL, output); }
VOX_EGL_LINKAGE int vox_gl_uniform_location(unsigned program, char const* name) { VOX_GLES_CALL; return glGetUniformLocation(program, name); }
VOX_EGL_LINKAGE int vox_gl_attrib_location(unsigned program, char const* name) { VOX_GLES_CALL; return glGetAttribLocation(program, name); }
VOX_EGL_LINKAGE void vox_gl_bind_attrib_location(unsigned program, unsigned index, char const* name) { VOX_GLES_CALL; glBindAttribLocation(program, index, name); }
VOX_EGL_LINKAGE int vox_gl_active_info(unsigned program, unsigned index, int uniform, int capacity, char* name, int* size, unsigned* type)
{ VOX_GLES_CALL;
    GLsizei length = 0;
    if (uniform)
        glGetActiveUniform(program, index, capacity, &length, size, type, name);
    else
        glGetActiveAttrib(program, index, capacity, &length, size, type, name);
    return length;
}
VOX_EGL_LINKAGE void vox_gl_uniform_indices(unsigned program, int count, void const* names, unsigned* result) { VOX_GLES_CALL; glGetUniformIndices(program,count,(char const* const*)names,result); }
VOX_EGL_LINKAGE void vox_gl_active_uniforms(unsigned program, int count, unsigned const* indices, unsigned pname, int* result) { VOX_GLES_CALL; glGetActiveUniformsiv(program,count,indices,pname,result); }
VOX_EGL_LINKAGE unsigned vox_gl_uniform_block_index(unsigned program, char const* name) { VOX_GLES_CALL; return glGetUniformBlockIndex(program,name); }
VOX_EGL_LINKAGE void vox_gl_uniform_block_parameter(unsigned program, unsigned index, unsigned pname, int capacity, int* result) { VOX_GLES_CALL; glGetActiveUniformBlockivRobustANGLE(program,index,pname,capacity,NULL,result); }
VOX_EGL_LINKAGE void vox_gl_uniform_block_name(unsigned program, unsigned index, int capacity, char* name) { VOX_GLES_CALL; glGetActiveUniformBlockName(program,index,capacity,NULL,name); }
VOX_EGL_LINKAGE void vox_gl_uniform_block_binding(unsigned program, unsigned index, unsigned binding) { VOX_GLES_CALL; glUniformBlockBinding(program,index,binding); }
VOX_EGL_LINKAGE void vox_gl_internalformat_parameter(unsigned target, unsigned format, unsigned pname, int capacity, int* result) { VOX_GLES_CALL; glGetInternalformativRobustANGLE(target,format,pname,capacity,NULL,result); }
VOX_EGL_LINKAGE void vox_gl_shader_precision(unsigned shader, unsigned precision, int* range, int* bits) { VOX_GLES_CALL; glGetShaderPrecisionFormat(shader, precision, range, bits); }
VOX_EGL_LINKAGE void vox_gl_uniform1f(int location, float x) { VOX_GLES_CALL; glUniform1f(location, x); }
VOX_EGL_LINKAGE void vox_gl_uniform2f(int location, float x, float y) { VOX_GLES_CALL; glUniform2f(location, x, y); }
VOX_EGL_LINKAGE void vox_gl_uniform3f(int location, float x, float y, float z) { VOX_GLES_CALL; glUniform3f(location, x, y, z); }
VOX_EGL_LINKAGE void vox_gl_uniform4f(int location, float x, float y, float z, float w) { VOX_GLES_CALL; glUniform4f(location, x, y, z, w); }
VOX_EGL_LINKAGE void vox_gl_uniform1i(int location, int x) { VOX_GLES_CALL; glUniform1i(location, x); }
VOX_EGL_LINKAGE void vox_gl_uniform2i(int location, int x, int y) { VOX_GLES_CALL; glUniform2i(location, x, y); }
VOX_EGL_LINKAGE void vox_gl_uniform3i(int location, int x, int y, int z) { VOX_GLES_CALL; glUniform3i(location, x, y, z); }
VOX_EGL_LINKAGE void vox_gl_uniform4i(int location, int x, int y, int z, int w) { VOX_GLES_CALL; glUniform4i(location, x, y, z, w); }
VOX_EGL_LINKAGE void vox_gl_uniform1ui(int location, unsigned x) { VOX_GLES_CALL; glUniform1ui(location, x); }
VOX_EGL_LINKAGE void vox_gl_uniform2ui(int location, unsigned x, unsigned y) { VOX_GLES_CALL; glUniform2ui(location, x, y); }
VOX_EGL_LINKAGE void vox_gl_uniform3ui(int location, unsigned x, unsigned y, unsigned z) { VOX_GLES_CALL; glUniform3ui(location, x, y, z); }
VOX_EGL_LINKAGE void vox_gl_uniform4ui(int location, unsigned x, unsigned y, unsigned z, unsigned w) { VOX_GLES_CALL; glUniform4ui(location, x, y, z, w); }
VOX_EGL_LINKAGE void vox_gl_uniform_floats(int location, int width, int count, float const* data)
{ VOX_GLES_CALL;
    switch (width) {
    case 1: glUniform1fv(location, count, data); break;
    case 2: glUniform2fv(location, count, data); break;
    case 3: glUniform3fv(location, count, data); break;
    case 4: glUniform4fv(location, count, data); break;
    }
}
VOX_EGL_LINKAGE void vox_gl_uniform_ints(int location, int width, int count, int const* data)
{ VOX_GLES_CALL;
    switch (width) {
    case 1: glUniform1iv(location, count, data); break;
    case 2: glUniform2iv(location, count, data); break;
    case 3: glUniform3iv(location, count, data); break;
    case 4: glUniform4iv(location, count, data); break;
    }
}
VOX_EGL_LINKAGE void vox_gl_uniform_uints(int location, int width, int count, unsigned const* data)
{ VOX_GLES_CALL;
    switch (width) {
    case 1: glUniform1uiv(location, count, data); break;
    case 2: glUniform2uiv(location, count, data); break;
    case 3: glUniform3uiv(location, count, data); break;
    case 4: glUniform4uiv(location, count, data); break;
    }
}
VOX_EGL_LINKAGE void vox_gl_uniform_matrix(int location, int columns, int rows, int count, int transpose, float const* data)
{ VOX_GLES_CALL;
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
VOX_EGL_LINKAGE void vox_gl_get_uniform_floats(unsigned program, int location, float* data) { VOX_GLES_CALL; glGetUniformfv(program, location, data); }
VOX_EGL_LINKAGE void vox_gl_get_uniform_ints(unsigned program, int location, int* data) { VOX_GLES_CALL; glGetUniformiv(program, location, data); }
VOX_EGL_LINKAGE void vox_gl_get_uniform_uints(unsigned program, int location, unsigned* data) { VOX_GLES_CALL; glGetUniformuiv(program, location, data); }

// Source WebGLRenderingContextImpl::get_parameter native result types/counts.
VOX_EGL_LINKAGE int vox_gl_parameter_shape(unsigned pname, int version) { VOX_GLES_CALL;
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
    // Apple's core headers name these TRANSFORM_FEEDBACK_BUFFER_ACTIVE/PAUSED.
    // Use the shared enum values for both desktop GL and GLES headers.
    case 0x8E24: // TRANSFORM_FEEDBACK_ACTIVE
    case 0x8E23: // TRANSFORM_FEEDBACK_PAUSED
    case GL_RASTERIZER_DISCARD:
        return version == 3 ? 31 : 0;
    default: return 0;
    }
}
VOX_EGL_LINKAGE void vox_gl_parameter(unsigned pname, int shape, double* output)
{ VOX_GLES_CALL;
    int count = shape % 10;
    GLsizei written = 0;
    switch (shape / 10) {
    case 1: { GLint values[4] = {0}; glGetIntegervRobustANGLE(pname, count, &written, values); for (int i = 0; i < count; ++i) output[i] = values[i]; break; }
    case 2: { GLfloat values[4] = {0}; glGetFloatvRobustANGLE(pname, count, &written, values); for (int i = 0; i < count; ++i) output[i] = values[i]; break; }
    case 3: { GLboolean values[4] = {0}; glGetBooleanvRobustANGLE(pname, count, &written, values); for (int i = 0; i < count; ++i) output[i] = values[i] == GL_TRUE; break; }
    case 4: { GLint64 value = 0; glGetInteger64vRobustANGLE(pname, 1, &written, &value); output[0] = (double)value; break; }
    }
}
#include "gles_cleanup.h"
#endif // implementation
#endif // VOX_WEBGL_NATIVE_EGL_H
