module ui2

$if !ui2_custom_rendering ? {
	import sokol.sapp

	pub fn blur_embedded_textbox() { dismiss_keyboard() }

	pub fn copy_embedded_text(value string) { sapp.set_clipboard_string(value.str) }
}
