module ui2

$if ui2_custom_rendering ? {
	import sokol.sapp

	#include <windows.h>
	fn C.ShowWindow(voidptr, i32) i32
	fn C.IsZoomed(voidptr) i32
	fn C.SetForegroundWindow(voidptr) i32
	fn C.ReleaseCapture() i32
	fn C.SendMessageW(voidptr, u32, uint, int) int

	// Window hosting operations; UI2's shared V elements own chrome behavior.
	pub fn embedded_host_action(action string) {
		if action == 'close' { sapp.request_quit(); return }
		window := sapp.win32_get_hwnd()
		if window == unsafe { nil } { return }
		match action {
			'show' {
				C.ShowWindow(window, 9)
				C.SetForegroundWindow(window)
			}
			'minimize' { C.ShowWindow(window, 6) }
			'zoom' { C.ShowWindow(window, if C.IsZoomed(window) != 0 { i32(9) } else { i32(3) }) }
			'drag' {
				C.ReleaseCapture()
				C.SendMessageW(window, 0x00a1, 2, 0)
			}
			else {}
		}
	}
}
