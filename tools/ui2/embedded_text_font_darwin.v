module ui2

$if !ui2_custom_rendering ? {
	import macos

	// AppKit labels and buttons otherwise always use the system face. A declared
	// family lets an element name the face CoreText would pick for a symbol the
	// system font lacks; measuring that symbol in the system face first builds
	// CoreText's entire fallback cascade.
	fn apply_embedded_text_font(native NativeView, el Element) {
		family := el.text_style.font_family
		if family == '' || native_is_nil(native) { return }
		style := el.text_style
		match el.kind {
			.label {
				target := if label_needs_container(el) { label_text_field(native) } else { native }
				macos.msg_void1(target, 'setFont:', native_text_style_font(style))
			}
			.button {
				macos.msg_void1(native, 'setFont:', native_text_style_font(style))
				// UI2 also installs an attributed title whose font is the system face.
				attrs := native_text_attributes(style.color, 0, style.size, family, style.bold,
					style.italic, style.underline, false, '')
				attributed := macos.msg_id2(macos.alloc('NSAttributedString'), 'initWithString:attributes:',
					macos.nsstring(el.text), attrs)
				macos.msg_void1(native, 'setAttributedTitle:', attributed)
				macos.release(attributed)
			}
			else {}
		}
	}
}
