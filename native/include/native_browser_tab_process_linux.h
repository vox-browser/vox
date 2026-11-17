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

        // Keep the window viewable between the attribute check and direct focus.
        XWindowAttributes attributes;
        XGrabServer(display);
        Status found = XGetWindowAttributes(display, window, &attributes);
        if (found && attributes.map_state == IsViewable) {
            XSetInputFocus(display, window, RevertToParent, CurrentTime);
        }
        XUngrabServer(display);

        if (found && attributes.map_state != IsViewable) {
            // A window manager can handle MapRequest asynchronously. Let it
            // activate the window once mapped, since direct focus would fail.
            XEvent event = {0};
            event.xclient.type = ClientMessage;
            event.xclient.display = display;
            event.xclient.window = window;
            event.xclient.message_type = XInternAtom(display, "_NET_ACTIVE_WINDOW", False);
            event.xclient.format = 32;
            event.xclient.data.l[0] = 1; // Application source indication.
            XSendEvent(display, attributes.root, False,
                       SubstructureRedirectMask | SubstructureNotifyMask, &event);
        }
    }
    XFlush(display);
}
