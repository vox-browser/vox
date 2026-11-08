#pragma once
#include <X11/Xlib.h>
static void vox_tab_x11_frame(void *display, unsigned long window, double *values) {
    XWindowAttributes a; Window child; int x, y;
    XGetWindowAttributes(display, window, &a);
    XTranslateCoordinates(display, window, a.root, 0, 0, &x, &y, &child);
    values[0]=x; values[1]=y; values[2]=a.width; values[3]=a.height;
}
static void vox_tab_x11_show(void *display, unsigned long window, int visible,
                            double x, double y, double w, double h) {
    if (!visible) XUnmapWindow(display, window);
    else {
        if (w>0 && h>0) XMoveResizeWindow(display, window, (int)x, (int)y, (unsigned)w, (unsigned)h);
        XMapRaised(display, window);
        XSetInputFocus(display, window, RevertToParent, CurrentTime);
    }
    XFlush(display);
}
