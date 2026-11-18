#pragma once
#include <X11/Xlib.h>
static void vox_tab_x11_frame(void *display, unsigned long window, double *values) {
    XWindowAttributes a; Window child; int x, y;
    XGetWindowAttributes(display, window, &a);
    XTranslateCoordinates(display, window, a.root, 0, 0, &x, &y, &child);
    values[0]=x; values[1]=y; values[2]=a.width; values[3]=a.height;
}
static void vox_tab_x11_show(Display *display, Window window, int visible,
                            double x, double y, double w, double h) {
    if (visible) {
        if (w > 0 && h > 0) {
            XMoveResizeWindow(display, window, (int)x, (int)y, (unsigned)w, (unsigned)h);
        }
        XMapRaised(display, window);
    } else {
        // Notify the window manager even when the map request is still pending.
        XWithdrawWindow(display, window, DefaultScreen(display));
    }
    XFlush(display);
}

static int vox_tab_x11_focus(Display *display, Window window) {
    // A window manager can defer MapRequest or reparent the window. Keep
    // viewability stable between the attribute check and the focus request.
    XWindowAttributes attributes;
    XGrabServer(display);
    int viewable = XGetWindowAttributes(display, window, &attributes)
        && attributes.map_state == IsViewable;
    if (viewable) {
        XSetInputFocus(display, window, RevertToParent, CurrentTime);
    }
    XUngrabServer(display);
    XFlush(display);
    return viewable;
}
