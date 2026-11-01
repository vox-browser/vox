module ui2

import sokol.sapp

#include "@VMODROOT/vox/embedded_host_linux.h"
fn C.ui2_x11_window_action(voidptr, u64, i32)

pub fn embedded_host_action(action string) {
	if action == 'close' { sapp.request_quit(); return }
	operation := match action { 'minimize' { 0 } 'zoom' { 1 } 'drag' { 2 } else { return } }
	C.ui2_x11_window_action(sapp.x11_get_display(), u64(sapp.x11_get_window()), i32(operation))
}
