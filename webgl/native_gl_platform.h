/* Native offscreen contexts for the WebGL command adapter. */
#ifndef VOX_WEBGL_NATIVE_GL_PLATFORM_H
#define VOX_WEBGL_NATIVE_GL_PLATFORM_H

#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "../platform/native_state.h"

#if defined(__APPLE__)
#define VOX_NATIVE_GL_DESKTOP 1
#ifndef GL_SILENCE_DEPRECATION
#define GL_SILENCE_DEPRECATION
#endif
#include <OpenGL/OpenGL.h>
#include <OpenGL/gl3.h>
#elif defined(_WIN32)
#define VOX_NATIVE_GL_DESKTOP 1
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include "native_gl_dispatch_windows.h"
#else
#define VOX_NATIVE_GL_DESKTOP 1
#include <pthread.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#define GL_GLEXT_PROTOTYPES 1
#include <GL/glcorearb.h>
// Keep GLX's current-context API available without including legacy GL/gl.h
// alongside the core-profile declarations above.
typedef struct _XDisplay VoxNativeXDisplay;
typedef struct __GLXcontextRec* VoxNativeGLXContext;
extern VoxNativeGLXContext glXGetCurrentContext(void);
extern VoxNativeXDisplay* glXGetCurrentDisplay(void);
extern unsigned long glXGetCurrentDrawable(void);
extern unsigned long glXGetCurrentReadDrawable(void);
extern int glXMakeContextCurrent(VoxNativeXDisplay*, unsigned long, unsigned long, VoxNativeGLXContext);
#endif

typedef struct VoxEGLContext {
    int version;
    GLuint framebuffer;
    GLuint color_buffer;
    GLuint depth_buffer;
    GLuint default_vertex_array;
    int failed;
    unsigned pending_error;
    struct VoxGLShaderSource* shader_sources;
    void* texture_storage;
    void* readback_objects;
#if defined(__APPLE__)
    CGLContextObj context;
#elif defined(_WIN32)
    HWND window;
    HDC device;
    HGLRC context;
    VoxNativeGLAPI gl;
#else
    EGLDisplay display;
    EGLContext context;
    EGLSurface surface;
#endif
} VoxEGLContext;

// V's split C backend shares the native state declarations across its units.
VOX_NATIVE_STATE __thread VoxEGLContext* vox_native_gl_active_context;

static VoxEGLContext* vox_native_gl_current(void)
{
    return vox_native_gl_active_context;
}

#if !defined(__APPLE__) && !defined(_WIN32)
VOX_NATIVE_STATE __thread VoxNativeXDisplay* vox_native_gl_host_display;
VOX_NATIVE_STATE __thread VoxNativeGLXContext vox_native_gl_host_context;
VOX_NATIVE_STATE __thread unsigned long vox_native_gl_host_drawable;
VOX_NATIVE_STATE __thread unsigned long vox_native_gl_host_read_drawable;

static void vox_native_gl_capture_host(void)
{
    if (vox_native_gl_host_context) return;
    VoxNativeGLXContext context = glXGetCurrentContext();
    if (!context) return;
    vox_native_gl_host_display = glXGetCurrentDisplay();
    vox_native_gl_host_drawable = glXGetCurrentDrawable();
    vox_native_gl_host_read_drawable = glXGetCurrentReadDrawable();
    vox_native_gl_host_context = context;
}
#endif

// The Linux window renderer uses GLX while canvases use offscreen EGL. Return
// the borrowed thread to the window host at script/snapshot/frame boundaries.
// Windowless callers have no host snapshot and retain their selected canvas.
static void vox_native_gl_release_current(void)
{
#if !defined(__APPLE__) && !defined(_WIN32)
    if (!vox_native_gl_host_context || !vox_native_gl_host_display) return;
    eglBindAPI(EGL_OPENGL_API);
    EGLDisplay display = eglGetCurrentDisplay();
    if (display != EGL_NO_DISPLAY)
        eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    glXMakeContextCurrent(vox_native_gl_host_display, vox_native_gl_host_drawable,
        vox_native_gl_host_read_drawable, vox_native_gl_host_context);
    // This is one borrowed window-context scope. A failed restore may mean its
    // window was destroyed; never retain that borrowed handle for a retry.
    vox_native_gl_host_context = NULL;
    vox_native_gl_host_display = NULL;
    vox_native_gl_host_drawable = vox_native_gl_host_read_drawable = 0;
    vox_native_gl_active_context = NULL;
#endif
}

#if !defined(__APPLE__) && !defined(_WIN32)
// EGL displays are shared by the driver. Balance our references instead of
// terminating the display while another canvas still has a live context.
VOX_NATIVE_STATE pthread_mutex_t vox_native_egl_display_mutex
    VOX_NATIVE_STATE_INIT(PTHREAD_MUTEX_INITIALIZER);
VOX_NATIVE_STATE EGLDisplay vox_native_egl_display VOX_NATIVE_STATE_INIT(EGL_NO_DISPLAY);
VOX_NATIVE_STATE unsigned vox_native_egl_display_users;

static int vox_native_gl_has_extension(char const* extensions, char const* name)
{
    if (!extensions || !name || !*name) return 0;
    size_t length = strlen(name);
    char const* match = extensions;
    while ((match = strstr(match, name))) {
        if ((match == extensions || match[-1] == ' ') &&
            (match[length] == '\0' || match[length] == ' ')) return 1;
        match += length;
    }
    return 0;
}

static EGLDisplay vox_native_egl_acquire_display(void)
{
    pthread_mutex_lock(&vox_native_egl_display_mutex);
    if (vox_native_egl_display == EGL_NO_DISPLAY) {
        EGLDisplay display = EGL_NO_DISPLAY;
        char const* extensions = eglQueryString(EGL_NO_DISPLAY, EGL_EXTENSIONS);
        if (vox_native_gl_has_extension(extensions, "EGL_EXT_platform_base") &&
            vox_native_gl_has_extension(extensions, "EGL_MESA_platform_surfaceless")) {
            PFNEGLGETPLATFORMDISPLAYEXTPROC get_platform_display =
                (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
            if (get_platform_display)
                display = get_platform_display(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, NULL);
        }
        EGLint major, minor;
        if (display == EGL_NO_DISPLAY || !eglInitialize(display, &major, &minor)) {
            display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
            if (display == EGL_NO_DISPLAY || !eglInitialize(display, &major, &minor))
                display = EGL_NO_DISPLAY;
        }
        vox_native_egl_display = display;
    }
    EGLDisplay display = vox_native_egl_display;
    if (display != EGL_NO_DISPLAY) ++vox_native_egl_display_users;
    pthread_mutex_unlock(&vox_native_egl_display_mutex);
    return display;
}

static void vox_native_egl_release_display(EGLDisplay display)
{
    pthread_mutex_lock(&vox_native_egl_display_mutex);
    if (display == vox_native_egl_display && vox_native_egl_display_users &&
        --vox_native_egl_display_users == 0) {
        eglTerminate(display);
        vox_native_egl_display = EGL_NO_DISPLAY;
    }
    pthread_mutex_unlock(&vox_native_egl_display_mutex);
}
#endif

#ifdef _WIN32
static BOOL CALLBACK vox_native_wgl_register_class(PINIT_ONCE once, PVOID parameter, PVOID* context)
{
    (void)once;
    (void)parameter;
    (void)context;
    WNDCLASSA window_class;
    memset(&window_class, 0, sizeof(window_class));
    window_class.style = CS_OWNDC;
    window_class.lpfnWndProc = DefWindowProcA;
    window_class.hInstance = GetModuleHandleA(NULL);
    window_class.lpszClassName = "VoxNativeWebGL";
    return RegisterClassA(&window_class) != 0 || GetLastError() == ERROR_CLASS_ALREADY_EXISTS;
}
VOX_NATIVE_STATE INIT_ONCE vox_native_wgl_class_once VOX_NATIVE_STATE_INIT(INIT_ONCE_STATIC_INIT);
#endif

static int vox_native_gl_make_current(VoxEGLContext* context)
{
    vox_native_gl_active_context = NULL;
    if (!context || context->failed) return 0;
#if defined(__APPLE__)
    if (CGLSetCurrentContext(context->context) != kCGLNoError) return 0;
#elif defined(_WIN32)
    if (!wglMakeCurrent(context->device, context->context)) return 0;
#else
    vox_native_gl_capture_host();
    if (!eglBindAPI(EGL_OPENGL_API) ||
        !eglMakeCurrent(context->display, context->surface, context->surface, context->context))
        return 0;
#endif
    vox_native_gl_active_context = context;
    return 1;
}

static VoxEGLContext* vox_native_gl_create(int version)
{
    if (version != 2 && version != 3) return NULL;
    VoxEGLContext* result = calloc(1, sizeof(VoxEGLContext));
    if (!result) return NULL;
    result->version = version;
#if defined(__APPLE__)
    CGLContextObj previous = CGLGetCurrentContext();
    CGLPixelFormatAttribute attributes[] = {
        kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute)kCGLOGLPVersion_GL4_Core,
        kCGLPFAAccelerated, kCGLPFAAllowOfflineRenderers,
        kCGLPFAColorSize, (CGLPixelFormatAttribute)24,
        kCGLPFAAlphaSize, (CGLPixelFormatAttribute)8,
        (CGLPixelFormatAttribute)0,
    };
    CGLPixelFormatObj format = NULL;
    GLint count = 0;
    if (CGLChoosePixelFormat(attributes, &format, &count) != kCGLNoError || !format || !count) {
        if (format) CGLDestroyPixelFormat(format);
        free(result);
        return NULL;
    }
    CGLError error = CGLCreateContext(format, NULL, &result->context);
    CGLDestroyPixelFormat(format);
    if (error != kCGLNoError || !result->context) {
        free(result);
        return NULL;
    }
    if (CGLSetCurrentContext(result->context) != kCGLNoError) {
        CGLSetCurrentContext(previous);
        CGLDestroyContext(result->context);
        free(result);
        return NULL;
    }
    glGenVertexArrays(1, &result->default_vertex_array);
    if (!result->default_vertex_array) {
        CGLSetCurrentContext(previous);
        CGLDestroyContext(result->context);
        free(result);
        return NULL;
    }
    glBindVertexArray(result->default_vertex_array);
    glEnable(GL_PROGRAM_POINT_SIZE);
#elif defined(_WIN32)
    HDC previous_device = wglGetCurrentDC();
    HGLRC previous = wglGetCurrentContext();
    HGLRC bootstrap = NULL;
    if (!InitOnceExecuteOnce(&vox_native_wgl_class_once, vox_native_wgl_register_class, NULL, NULL))
        goto failed;
    result->window = CreateWindowExA(0, "VoxNativeWebGL", "", WS_POPUP,
        0, 0, 1, 1, NULL, NULL, GetModuleHandleA(NULL), NULL);
    if (!result->window) goto failed;
    result->device = GetDC(result->window);
    if (!result->device) goto failed;
    PIXELFORMATDESCRIPTOR descriptor;
    memset(&descriptor, 0, sizeof(descriptor));
    descriptor.nSize = sizeof(descriptor);
    descriptor.nVersion = 1;
    descriptor.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL;
    descriptor.iPixelType = PFD_TYPE_RGBA;
    descriptor.cColorBits = 24;
    descriptor.cAlphaBits = 8;
    int format = ChoosePixelFormat(result->device, &descriptor);
    if (!format || !SetPixelFormat(result->device, format, &descriptor)) goto failed;
    bootstrap = wglCreateContext(result->device);
    if (!bootstrap || !wglMakeCurrent(result->device, bootstrap)) goto failed;
    typedef HGLRC (WINAPI *CreateContextAttribs)(HDC, HGLRC, int const*);
    CreateContextAttribs create_context = (CreateContextAttribs)vox_native_wgl_proc("wglCreateContextAttribsARB");
    if (!create_context) goto failed;
    int attributes[] = {
        0x2091 /* WGL_CONTEXT_MAJOR_VERSION_ARB */, 4,
        0x2092 /* WGL_CONTEXT_MINOR_VERSION_ARB */, 3,
        0x9126 /* WGL_CONTEXT_PROFILE_MASK_ARB */, 1 /* CORE_PROFILE_BIT_ARB */,
        0,
    };
    result->context = create_context(result->device, NULL, attributes);
    if (!result->context) goto failed;
    if (!wglMakeCurrent(result->device, result->context)) goto failed;
    wglDeleteContext(bootstrap);
    bootstrap = NULL;
    if (!vox_native_wgl_load(&result->gl)) goto failed;
    result->gl.GenVertexArrays(1, &result->default_vertex_array);
    if (!result->default_vertex_array) goto failed;
    result->gl.BindVertexArray(result->default_vertex_array);
    result->gl.Enable(GL_PROGRAM_POINT_SIZE);
#else
    vox_native_gl_capture_host();
    result->display = vox_native_egl_acquire_display();
    if (result->display == EGL_NO_DISPLAY) {
        free(result);
        return NULL;
    }
    EGLDisplay previous_display = eglGetCurrentDisplay();
    EGLContext previous = eglGetCurrentContext();
    EGLSurface previous_draw = eglGetCurrentSurface(EGL_DRAW);
    EGLSurface previous_read = eglGetCurrentSurface(EGL_READ);
    EGLenum previous_api = eglQueryAPI();
    EGLConfig config;
    EGLint count = 0;
    EGLint config_attributes[] = {
        EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
        EGL_NONE,
    };
    EGLint context_attributes[] = {
        EGL_CONTEXT_MAJOR_VERSION_KHR, 4,
        EGL_CONTEXT_MINOR_VERSION_KHR, 3,
        EGL_CONTEXT_OPENGL_PROFILE_MASK_KHR, EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT_KHR,
        EGL_NONE,
    };
    EGLint surface_attributes[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
    if (!eglBindAPI(EGL_OPENGL_API) ||
        !eglChooseConfig(result->display, config_attributes, &config, 1, &count) || !count)
        goto failed;
    result->context = eglCreateContext(result->display, config, EGL_NO_CONTEXT, context_attributes);
    if (result->context == EGL_NO_CONTEXT) goto failed;
    result->surface = eglCreatePbufferSurface(result->display, config, surface_attributes);
    if (result->surface == EGL_NO_SURFACE ||
        !eglMakeCurrent(result->display, result->surface, result->surface, result->context))
        goto failed;
    glGenVertexArrays(1, &result->default_vertex_array);
    if (!result->default_vertex_array) goto failed;
    glBindVertexArray(result->default_vertex_array);
    glEnable(GL_PROGRAM_POINT_SIZE);
#endif
    vox_native_gl_active_context = result;
    return result;

#if defined(_WIN32)
failed:
    wglMakeCurrent(previous_device, previous);
    if (bootstrap) wglDeleteContext(bootstrap);
    if (result->context) wglDeleteContext(result->context);
    if (result->device) ReleaseDC(result->window, result->device);
    if (result->window) DestroyWindow(result->window);
    free(result);
    return NULL;
#elif !defined(__APPLE__)
failed:
    eglBindAPI(EGL_OPENGL_API);
    if (eglGetCurrentContext() == result->context)
        eglMakeCurrent(result->display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglBindAPI(previous_api);
    if (previous_display != EGL_NO_DISPLAY)
        eglMakeCurrent(previous_display, previous_draw, previous_read, previous);
    if (result->surface != EGL_NO_SURFACE) eglDestroySurface(result->display, result->surface);
    if (result->context != EGL_NO_CONTEXT) eglDestroyContext(result->display, result->context);
    vox_native_egl_release_display(result->display);
    free(result);
    return NULL;
#endif
}

static void vox_native_gl_destroy(VoxEGLContext* context)
{
    if (!context) return;
    // Each native context has an unshared object namespace. Destroying it frees
    // its VAO and drawing buffers without selecting it over another canvas.
#if defined(__APPLE__)
    if (CGLGetCurrentContext() == context->context) CGLSetCurrentContext(NULL);
    CGLDestroyContext(context->context);
#elif defined(_WIN32)
    if (wglGetCurrentContext() == context->context) wglMakeCurrent(NULL, NULL);
    wglDeleteContext(context->context);
    ReleaseDC(context->window, context->device);
    DestroyWindow(context->window);
#else
    if (eglGetCurrentContext() == context->context)
        eglMakeCurrent(context->display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroySurface(context->display, context->surface);
    eglDestroyContext(context->display, context->context);
    vox_native_egl_release_display(context->display);
#endif
    if (vox_native_gl_active_context == context) vox_native_gl_active_context = NULL;
    free(context);
}

static int vox_native_gl_extension_count(void)
{
    if (!vox_native_gl_current()) return 0;
    GLint count = 0;
    glGetIntegerv(GL_NUM_EXTENSIONS, &count);
    return count > 0 ? count : 0;
}

static char const* vox_native_gl_extension_at(unsigned index)
{
    if (!vox_native_gl_current()) return NULL;
    return (char const*)glGetStringi(GL_EXTENSIONS, index);
}

#endif
