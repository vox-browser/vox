#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <EGL/eglext_angle.h>
#define GL_GLEXT_PROTOTYPES 1
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#include <GLES2/gl2ext_angle.h>
#include <GLES3/gl3.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *mode;
static int opens, closes, resolutions, clear_calls;
static GLbitfield clear_mask;
static char egl_handle, gles_handle;
static void unused_entry(void) {}
static void clear_entry(GLbitfield mask) { ++clear_calls; clear_mask = mask; }
static GLenum error_entry(void) { return GL_INVALID_ENUM; }
static EGLBoolean initialize_entry(EGLDisplay display, EGLint *major, EGLint *minor) {
    assert(display == (EGLDisplay)&egl_handle); *major = 1; *minor = 5; return EGL_TRUE;
}
static void *open_library(const char *path, int flags) {
    ++opens; assert((flags & RTLD_LOCAL) == RTLD_LOCAL);
    int egl = strstr(path,"libEGL.") != NULL;
    if ((egl && !strcmp(mode,"missing-egl")) || (!egl && !strcmp(mode,"missing-gles"))) return NULL;
    return egl ? &egl_handle : &gles_handle;
}
static void *resolve_entry(void *library, const char *name) {
    ++resolutions;
    assert(library == (name[0] == 'e' ? &egl_handle : &gles_handle));
    if (!strcmp(name,"glClear")) return !strcmp(mode,"missing-symbol") ? NULL : (void*)clear_entry;
    if (!strcmp(name,"glGetError")) return (void*)error_entry;
    if (!strcmp(name,"eglInitialize")) return (void*)initialize_entry;
    return (void*)unused_entry;
}
static int close_library(void *library) { assert(library); ++closes; return 0; }
#define dlopen open_library
#define dlsym resolve_entry
#define dlclose close_library
#include "../webgl/angle_dispatch_darwin.h"
#undef dlopen
#undef dlsym
#undef dlclose

int main(int argc, const char **argv) {
    assert(argc == 2); mode = argv[1];
    assert(opens == 0 && resolutions == 0 && closes == 0);
    int ready = vox_angle_prepare();
    assert(opens == 2);
    assert(ready == !strcmp(mode,"complete"));
    if (ready) {
        assert(resolutions > 200 && closes == 0);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        assert(clear_calls == 1 && clear_mask == (GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT));
        assert(glGetError() == GL_INVALID_ENUM);
        EGLint major = 0, minor = 0;
        assert(eglInitialize((EGLDisplay)&egl_handle,&major,&minor));
        assert(major == 1 && minor == 5);
    } else {
        assert(!vox_angle_api.egl_library && !vox_angle_api.gles_library);
        assert(closes == (!strcmp(mode,"missing-symbol") ? 2 : 1));
        assert((!strcmp(mode,"missing-symbol") ? resolutions > 200 : resolutions == 0));
    }
    int first_resolutions = resolutions;
    assert(vox_angle_prepare() == ready);
    assert(opens == 2 && resolutions == first_resolutions);
    printf("PASS deferred ANGLE initialization: %s\n",mode);
}
