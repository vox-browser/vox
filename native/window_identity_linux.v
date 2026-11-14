module main

import sokol.sapp

#include "@VMODROOT/native/include/native_window_identity_linux.h"

fn C.vox_x11_set_window_process(voidptr, uint)

fn initialize_linux_window_identity() {
    C.vox_x11_set_window_process(sapp.x11_get_display(), uint(sapp.x11_get_window()))
}
