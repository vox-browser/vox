module browserui

import ui2

pub fn address_field(frame ui2.Rect, address string) ui2.Element {
	// Native rounded clipping contains AppKit's focus ring. Keep the custom
	// renderer's outline square so its trailing edge stays inside the field.
	radius := $if macos && !ui2_custom_rendering ? { 4.0 } $else { 0.0 }
	return ui2.text_input(
		id:           'address'
		action_id:    'address-change'
		submit_id:    'address-submit'
		text:         address
		hint_text:    'Enter a URL'
		multiline:    false
		autocorrect:  false
		frame:        frame
		padding_left: 4
		// Explicit edges replace AppKit's bezel. Matching the fill also covers
		// the custom renderer's two-pixel focus outline.
		box:          ui2.BoxStyle{
			bg:            0xffffff
			radius:        radius
			border_color:  0xffffff
			border_left:   2
			border_top:    2
			border_right:  2
			border_bottom: 2
		}
		text_style:   ui2.TextStyle{ size: 12 }
	) or { panic(err) }
}
