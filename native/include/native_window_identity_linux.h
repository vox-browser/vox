#pragma once
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <unistd.h>

// EWMH ownership hint used by window managers and native automation.
static void vox_x11_set_window_process(void *display, unsigned long window) {
    if (!display || !window) return;
    unsigned long pid = (unsigned long)getpid();
    Atom property = XInternAtom(display, "_NET_WM_PID", False);
    XChangeProperty(display, window, property, XA_CARDINAL, 32, PropModeReplace,
                    (const unsigned char *)&pid, 1);
    XFlush(display);
}
