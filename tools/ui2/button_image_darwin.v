module ui2

$if !ui2_custom_rendering ? {
	import macos

	fn apply_embedded_button_image(native NativeView, el Element) {
		if el.kind != .button || el.button_image_size <= 0 || el.image_path == '' { return }
		// UI2 has already installed a private copy of the source image.
		icon := macos.msg_id(native, 'image')
		if native_is_nil(icon) { return }
		frame := embedded_button_image_frame(el)
		macos.msg_void_point(icon, 'setSize:', macos.point(frame.width, frame.height))
		macos.msg_void_i64(native, 'setImagePosition:', if el.text == '' { i64(1) } else { i64(2) })
		// Proportionally down: AppKit must not enlarge a small icon to fill the cell.
		macos.msg_void_i64(native, 'setImageScaling:', 0)
	}
}
