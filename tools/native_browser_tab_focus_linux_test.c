#include <assert.h>
#include "native/include/native_browser_tab_process_linux.h"

static void show_tab(Display *display, Window window, int visible) {
    vox_tab_x11_show(display, window, visible, 0, 0, 0, 0);
    // Deliver asynchronous protocol errors before the window manager maps it.
    XSync(display, False);
}

static Window focused_window(Display *display) {
    Window window;
    int revert_to;
    XGetInputFocus(display, &window, &revert_to);
    return window;
}

static int map_state(Display *display, Window window) {
    XWindowAttributes attributes;
    assert(XGetWindowAttributes(display, window, &attributes));
    return attributes.map_state;
}

int main(void) {
    Display *display = XOpenDisplay(NULL);
    assert(display);
    Window root = DefaultRootWindow(display);
    Window first = XCreateSimpleWindow(display, root, 0, 0, 200, 100, 0, 0, 0);
    Window second = XCreateSimpleWindow(display, root, 0, 0, 200, 100, 0, 0, 0);

    show_tab(display, first, 1);
    assert(focused_window(display) == first);
    show_tab(display, first, 0);
    assert(map_state(display, first) == IsUnmapped);
    show_tab(display, second, 1);
    assert(focused_window(display) == second);

    // A separate X11 client redirects mapping like a window manager. Leave
    // the first window unmapped until both the map and activation requests arrive.
    Display *manager = XOpenDisplay(NULL);
    assert(manager);
    XSelectInput(manager, root, SubstructureRedirectMask);
    Atom active_window = XInternAtom(manager, "_NET_ACTIVE_WINDOW", False);
    XSync(manager, False);

    show_tab(display, first, 1);
    assert(map_state(display, first) == IsUnmapped);
    assert(focused_window(display) == second);
    XEvent event;
    assert(XCheckTypedEvent(manager, MapRequest, &event));
    assert(event.xmaprequest.window == first);
    assert(XCheckTypedEvent(manager, ClientMessage, &event));
    assert(event.xclient.window == first);
    assert(event.xclient.message_type == active_window);
    assert(event.xclient.format == 32 && event.xclient.data.l[0] == 1);

    XMapWindow(manager, first);
    XSetInputFocus(manager, first, RevertToParent, CurrentTime);
    XSync(manager, False);
    show_tab(display, second, 0);
    assert(map_state(display, first) == IsViewable);
    assert(map_state(display, second) == IsUnmapped);
    assert(focused_window(display) == first);

    XCloseDisplay(manager);
    XCloseDisplay(display);
    return 0;
}
