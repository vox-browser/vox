module ui2

$if !ui2_custom_rendering ? {
	import os

	const disable_embedded_native_visual_reuse = os.getenv('VOX_DISABLE_NATIVE_VISUAL_REUSE') != ''

	// Only the display-only native update inputs belong here. Reconciliation
	// still delivers actions, common/accessibility state, menus, decorations and
	// children every time. Editable and checked controls retain their full update.
	struct EmbeddedNativeVisualInputs {
		kind Kind
		frame Rect
		text string
		box BoxStyle
		color u32
		size f64
		bold bool
		italic bool
		underline bool
		align Align
		valign VAlign
		lines int
		image string
		native_style bool
		enabled bool
	}

	fn embedded_native_visual_changed(mut st RuntimeState, key string, el Element) bool {
		if disable_embedded_native_visual_reuse || el.kind !in [.view, .label, .button] {
			return true
		}
		next := EmbeddedNativeVisualInputs{
			kind: el.kind
			frame: el.frame
			text: el.text
			box: el.box
			color: el.text_style.color
			size: el.text_style.size
			bold: el.text_style.bold
			italic: el.text_style.italic
			underline: el.text_style.underline
			align: el.text_style.align
			valign: el.text_style.valign
			lines: el.text_style.lines
			image: el.image_path
			native_style: el.native_style
			enabled: el.enabled
		}
		if previous := st.node_visual_inputs[key] {
			if previous == next { return false }
		}
		st.node_visual_inputs[key] = EmbeddedNativeVisualInputs{
			...next
			text: next.text.clone()
			image: next.image.clone()
		}
		return true
	}
}
