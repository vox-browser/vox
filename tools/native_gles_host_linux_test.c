/* A real GLX window remains usable across surfaceless WebGL service calls. */
#include <assert.h>
#include <stdio.h>
#include <GL/glx.h>
#include "../webgl/native_egl.h"
static Display *display;
static GLXContext host;
static void preserved(void) {
    assert(glXGetCurrentContext()==host);
    GLint viewport[4];glGetIntegerv(GL_VIEWPORT,viewport);
    assert(viewport[0]==7 && viewport[1]==8 && viewport[2]==9 && viewport[3]==10);
    GLfloat clear[4];glGetFloatv(GL_COLOR_CLEAR_VALUE,clear);
    assert(clear[0]==0.25f && clear[1]==0.5f && clear[2]==0.75f && clear[3]==1);
}
int main(int argc,char **argv) {
    int baseline=argc>1 && !strcmp(argv[1],"--host-only");
    display=XOpenDisplay(NULL);assert(display);
    int attributes[]={GLX_RGBA,None};
    XVisualInfo *visual=glXChooseVisual(display,DefaultScreen(display),attributes);assert(visual);
    host=glXCreateContext(display,visual,NULL,True);assert(host);
    Colormap map=XCreateColormap(display,RootWindow(display,visual->screen),visual->visual,AllocNone);
    XSetWindowAttributes settings={.colormap=map};
    Window window=XCreateWindow(display,RootWindow(display,visual->screen),0,0,32,32,0,
        visual->depth,InputOutput,visual->visual,CWColormap,&settings);
    assert(glXMakeCurrent(display,window,host));
    glViewport(7,8,9,10);glClearColor(.25f,.5f,.75f,1);
    if(!baseline) {
    void *one=vox_egl_create(2);assert(one);preserved();
    void *two=vox_egl_create(3);assert(two);preserved();
    for(int i=0;i<4;i++) {
        void *context=i%2?one:two;
        assert(vox_egl_make_current(context));preserved();
        assert(vox_egl_allocate_surface(context,2,2,1,1));preserved();
        vox_gl_clear_color(1,0,0,1);vox_gl_clear(GL_COLOR_BUFFER_BIT);preserved();
        unsigned char pixels[16]={0};
        assert(vox_gl_read_pixels(0,0,2,2,GL_RGBA,GL_UNSIGNED_BYTE,16,pixels)==16);
        for(int p=0;p<16;p+=4)assert(pixels[p]==255 && !pixels[p+1] && !pixels[p+2] && pixels[p+3]==255);
        preserved();assert(vox_gl_get_error()==GL_NO_ERROR);
    }
    glEnable(0xdead); /* A window error must remain outside the WebGL queue. */
    assert(vox_gl_get_error()==GL_NO_ERROR);assert(glGetError()==GL_INVALID_ENUM);
    assert(vox_egl_make_current(two));
    vox_egl_destroy(one);preserved();
    glXMakeCurrent(display,None,NULL);
    /* After the host releases its context, service calls still bind the last
     * selected WebGL context rather than silently executing without one. */
    GLint viewport[4];vox_gl_int_parameter(GL_VIEWPORT,viewport);assert(viewport[2]==2 && viewport[3]==2);
    vox_egl_destroy(two);
    assert(glGetError()==GL_NO_ERROR);
    }
    glXMakeCurrent(display,None,NULL);glXDestroyContext(display,host);
    XDestroyWindow(display,window);XFreeColormap(display,map);XFree(visual);XCloseDisplay(display);
    puts("GLX window context and state preserved across WebGL1/WebGL2 calls");
}
