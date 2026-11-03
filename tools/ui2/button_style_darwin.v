module ui2

$if !ui2_custom_rendering ? {
	import macos
	import os

	const disable_embedded_button_bezel_coalescing = os.getenv('VOX_DISABLE_BUTTON_STYLE_COALESCING') != ''

	fn apply_embedded_button_bezel(button NativeView, flat bool) {
		if disable_embedded_button_bezel_coalescing {
			macos.msg_void_u64(button, 'setBezelStyle:', 1)
			macos.msg_void_bool(button, 'setShowsBorderOnlyWhileMouseInside:', false)
			return
		}
		desired := if flat { u64(13) } else { u64(1) }
		if macos.msg_u64(button, 'bezelStyle') != desired {
			macos.msg_void_u64(button, 'setBezelStyle:', desired)
		}
		if macos.msg_bool(button, 'showsBorderOnlyWhileMouseInside') != flat {
			macos.msg_void_bool(button, 'setShowsBorderOnlyWhileMouseInside:', flat)
		}
	}
}
