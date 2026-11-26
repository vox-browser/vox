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
    assert(vox_tab_x11_focus(display, first));
    assert(focused_window(display) == first);
    show_tab(display, first, 0);
    assert(map_state(display, first) == IsUnmapped);
    show_tab(display, second, 1);
    assert(vox_tab_x11_focus(display, second));
    assert(focused_window(display) == second);

    // Model an ICCCM window manager that defers maps and leaves focus alone.
    Display *manager = XOpenDisplay(NULL);
    assert(manager);
    Window frame = XCreateSimpleWindow(manager, root, 0, 0, 200, 100, 0, 0, 0);
    XSelectInput(manager, root, SubstructureRedirectMask | SubstructureNotifyMask);
    XSync(manager, False);

    show_tab(display, first, 1);
    assert(map_state(display, first) == IsUnmapped);
    assert(!vox_tab_x11_focus(display, first));
    assert(focused_window(display) == second);
    XEvent event;
    assert(XCheckTypedEvent(manager, MapRequest, &event));
    assert(event.xmaprequest.window == first);
    assert(!XCheckTypedEvent(manager, ClientMessage, &event));

    // Deselecting during a delayed map must notify the manager of the withdrawal.
    show_tab(display, first, 0);
    assert(XCheckTypedEvent(manager, UnmapNotify, &event));
    assert(event.xunmap.send_event && event.xunmap.window == first);
    show_tab(display, first, 1);
    assert(XCheckTypedEvent(manager, MapRequest, &event));
    assert(event.xmaprequest.window == first);

    XReparentWindow(manager, first, frame, 0, 0);
    XMapWindow(manager, first);
    XSync(manager, False);
    assert(map_state(display, first) == IsUnviewable);
    assert(!vox_tab_x11_focus(display, first));
    assert(focused_window(display) == second);

    XMapWindow(manager, frame);
    XSync(manager, False);
    assert(map_state(display, first) == IsViewable);
    assert(vox_tab_x11_focus(display, first));
    assert(focused_window(display) == first);
    show_tab(display, second, 0);
    assert(map_state(display, second) == IsUnmapped);

    XCloseDisplay(manager);
    XCloseDisplay(display);
    return 0;
}
