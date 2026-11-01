#pragma once
#include <X11/Xlib.h>
#include <stdint.h>
// Generic OS window operations for UI2's X11 host; no widget policy.
static void ui2_x11_window_action(void *handle, uintptr_t id, int32_t operation) {
    Display *display=(Display *)handle; Window window=(Window)id;
    if (!display || !window) return;
    if (operation==0) { XIconifyWindow(display,window,DefaultScreen(display)); XFlush(display); return; }
    XEvent event={0}; event.xclient.type=ClientMessage; event.xclient.window=window; event.xclient.format=32;
    if (operation==1) {
        event.xclient.message_type=XInternAtom(display,"_NET_WM_STATE",False);
        event.xclient.data.l[0]=2;
        event.xclient.data.l[1]=XInternAtom(display,"_NET_WM_STATE_MAXIMIZED_VERT",False);
        event.xclient.data.l[2]=XInternAtom(display,"_NET_WM_STATE_MAXIMIZED_HORZ",False);
        event.xclient.data.l[3]=1;
    } else {
        Window root,child; int x,y,local_x,local_y; unsigned mask;
        XQueryPointer(display,window,&root,&child,&x,&y,&local_x,&local_y,&mask);
        XUngrabPointer(display,CurrentTime);
        event.xclient.message_type=XInternAtom(display,"_NET_WM_MOVERESIZE",False);
        event.xclient.data.l[0]=x; event.xclient.data.l[1]=y; event.xclient.data.l[2]=8;
        event.xclient.data.l[3]=1; event.xclient.data.l[4]=1;
    }
    XSendEvent(display,DefaultRootWindow(display),False,SubstructureRedirectMask|SubstructureNotifyMask,&event);
    XFlush(display);
}
