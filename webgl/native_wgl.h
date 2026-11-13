/* Copyright (c) 2026, Vox contributors
 * SPDX-License-Identifier: BSD-2-Clause
 * Mesa's EGL/WGL frontend does not expose robust ES context creation. Its
 * native WGL frontend does, while sharing the same GLES dispatch library.
 */
#ifndef VOX_WEBGL_NATIVE_WGL_H
#define VOX_WEBGL_NATIVE_WGL_H
#include <windows.h>
#include <wchar.h>
#include <GL/wglext.h>
#include "../platform/native_state.h"

typedef struct { HWND window; HDC dc; HGLRC context; } VoxWGLContext;
typedef struct {
    HMODULE library;
    int (WINAPI *choose)(HDC,const PIXELFORMATDESCRIPTOR*);
    int (WINAPI *describe)(HDC,int,UINT,LPPIXELFORMATDESCRIPTOR);
    BOOL (WINAPI *set)(HDC,int,const PIXELFORMATDESCRIPTOR*);
    HGLRC (WINAPI *create)(HDC);
    BOOL (WINAPI *destroy)(HGLRC);
    BOOL (WINAPI *bind)(HDC,HGLRC);
    HGLRC (WINAPI *current)(void);
    HDC (WINAPI *current_dc)(void);
    PROC (WINAPI *procedure)(LPCSTR);
} VoxWGLDispatch;
VOX_NATIVE_STATE VoxWGLDispatch vox_wgl;
VOX_NATIVE_STATE INIT_ONCE vox_wgl_once VOX_NATIVE_STATE_INIT(INIT_ONCE_STATIC_INIT);

static BOOL CALLBACK vox_wgl_initialize(PINIT_ONCE once, PVOID parameter, PVOID *result) {
    (void)once; (void)parameter; (void)result;
    /* Use the loader beside the already loaded Mesa GLES implementation,
     * including when its directory came from PATH rather than the app folder.
     * Never silently select the system OpenGL loader or another package.
     */
    wchar_t path[32768];
    HMODULE gallium=GetModuleHandleW(L"libgallium_wgl.dll");
    DWORD length=gallium?GetModuleFileNameW(gallium,path,32768):0;
    if(!length || length>=32768)return FALSE;
    wchar_t *slash=wcsrchr(path,L'\\');
    const wchar_t loader[]=L"opengl32.dll";
    if(!slash || 32768-(size_t)(slash+1-path)<sizeof(loader)/sizeof(*loader))return FALSE;
    memcpy(slash+1,loader,sizeof(loader));
    HMODULE library=LoadLibraryExW(path,NULL,LOAD_WITH_ALTERED_SEARCH_PATH);
    if(!library)return FALSE;
    VoxWGLDispatch dispatch={0}; dispatch.library=library;
    dispatch.choose=(void*)GetProcAddress(library,"wglChoosePixelFormat");
    dispatch.describe=(void*)GetProcAddress(library,"wglDescribePixelFormat");
    dispatch.set=(void*)GetProcAddress(library,"wglSetPixelFormat");
    dispatch.create=(void*)GetProcAddress(library,"wglCreateContext");
    dispatch.destroy=(void*)GetProcAddress(library,"wglDeleteContext");
    dispatch.bind=(void*)GetProcAddress(library,"wglMakeCurrent");
    dispatch.current=(void*)GetProcAddress(library,"wglGetCurrentContext");
    dispatch.current_dc=(void*)GetProcAddress(library,"wglGetCurrentDC");
    dispatch.procedure=(void*)GetProcAddress(library,"wglGetProcAddress");
    if(!dispatch.choose || !dispatch.describe || !dispatch.set || !dispatch.create ||
       !dispatch.destroy || !dispatch.bind || !dispatch.current || !dispatch.current_dc || !dispatch.procedure) {
        FreeLibrary(library); return FALSE;
    }
    WNDCLASSW window_class={0};
    window_class.style=CS_OWNDC; window_class.lpfnWndProc=DefWindowProcW;
    window_class.hInstance=GetModuleHandleW(NULL);
    window_class.lpszClassName=L"VoxMesaWebGLContext";
    if(!RegisterClassW(&window_class) && GetLastError()!=ERROR_CLASS_ALREADY_EXISTS) {
        FreeLibrary(library); return FALSE;
    }
    vox_wgl=dispatch;
    return TRUE;
}

static void vox_wgl_destroy(VoxWGLContext *context) {
    if(context->context) {
        if(vox_wgl.current()==context->context)vox_wgl.bind(NULL,NULL);
        vox_wgl.destroy(context->context);
    }
    if(context->dc)ReleaseDC(context->window,context->dc);
    if(context->window)DestroyWindow(context->window);
    memset(context,0,sizeof(*context));
}

static int vox_wgl_create(VoxWGLContext *context) {
    if(!InitOnceExecuteOnce(&vox_wgl_once,vox_wgl_initialize,NULL,NULL))return 0;
    HGLRC previous=vox_wgl.current(); HDC previous_dc=vox_wgl.current_dc();
    HGLRC bootstrap=NULL;
    context->window=CreateWindowExW(0,L"VoxMesaWebGLContext",L"",WS_POPUP,
        0,0,1,1,NULL,NULL,GetModuleHandleW(NULL),NULL);
    if(!context->window)goto failed;
    context->dc=GetDC(context->window);
    if(!context->dc)goto failed;
    PIXELFORMATDESCRIPTOR format={0};
    format.nSize=sizeof(format); format.nVersion=1;
    format.dwFlags=PFD_DRAW_TO_WINDOW|PFD_SUPPORT_OPENGL|PFD_DOUBLEBUFFER;
    format.iPixelType=PFD_TYPE_RGBA; format.cColorBits=32; format.cAlphaBits=8;
    format.cDepthBits=24; format.cStencilBits=8;
    int index=vox_wgl.choose(context->dc,&format);
    if(!index || !vox_wgl.describe(context->dc,index,sizeof(format),&format) ||
       !vox_wgl.set(context->dc,index,&format))goto failed;
    bootstrap=vox_wgl.create(context->dc);
    if(!bootstrap || !vox_wgl.bind(context->dc,bootstrap))goto failed;
    PFNWGLCREATECONTEXTATTRIBSARBPROC create=(void*)vox_wgl.procedure("wglCreateContextAttribsARB");
    if(!create)goto failed;
    const int attributes[]={
        WGL_CONTEXT_MAJOR_VERSION_ARB,3, WGL_CONTEXT_MINOR_VERSION_ARB,0,
        WGL_CONTEXT_PROFILE_MASK_ARB,WGL_CONTEXT_ES_PROFILE_BIT_EXT,
        WGL_CONTEXT_FLAGS_ARB,WGL_CONTEXT_ROBUST_ACCESS_BIT_ARB,0
    };
    context->context=create(context->dc,NULL,attributes);
    if(!context->context || !vox_wgl.bind(context->dc,context->context))goto failed;
    vox_wgl.destroy(bootstrap); bootstrap=NULL;
    /* The robust flag must take effect, including on GLES 3.1 where querying
     * GL_CONTEXT_FLAGS itself is invalid. Do not accept an ordinary context.
     */
    GLint major=0; GLboolean robust=GL_FALSE;
    glGetIntegerv(GL_MAJOR_VERSION,&major);
    glGetBooleanv(GL_CONTEXT_ROBUST_ACCESS_KHR,&robust);
    const char *version=(const char*)glGetString(GL_VERSION);
    if(major<3 || !version || !strstr(version,"OpenGL ES") || !strstr(version,"Mesa") ||
       robust!=GL_TRUE || glGetError()!=GL_NO_ERROR)goto failed;
    return 1;
failed:
    vox_wgl.bind(previous_dc,previous);
    if(bootstrap)vox_wgl.destroy(bootstrap);
    vox_wgl_destroy(context);
    return 0;
}
#endif
