#include "../../../native/include/native_window_identity_linux.h"
#include <assert.h>

int main(void) {
    vox_x11_set_window_process(NULL, 0);
    Display *display = XOpenDisplay(NULL);
    assert(display);
    Window window = XCreateSimpleWindow(display, DefaultRootWindow(display), 0, 0, 1, 1, 0, 0, 0);
    vox_x11_set_window_process(display, window);
    Atom actual_type;
    int format;
    unsigned long count, remaining;
    unsigned char *data = NULL;
    assert(XGetWindowProperty(display, window, XInternAtom(display, "_NET_WM_PID", False),
        0, 1, False, XA_CARDINAL, &actual_type, &format, &count, &remaining, &data) == Success);
    assert(actual_type == XA_CARDINAL && format == 32 && count == 1 && remaining == 0);
    assert(*(unsigned long *)data == (unsigned long)getpid());
    XFree(data);
    XDestroyWindow(display, window);
    XCloseDisplay(display);
    return 0;
}
