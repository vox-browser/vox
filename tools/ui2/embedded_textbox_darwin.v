module ui2

import macos

// Embed UI2's actual native single-line control in the GG window. The browser
// continues to own NSApplication, its window, and its rendering/event loop.
pub fn mount_embedded_textbox(parent voidptr, frame Rect, value string, handler EventFn) !voidptr {
	mut st := state()
	if !native_is_nil(st.window) {
		return error('an embedded UI2 textbox is already mounted')
	}
	ensure_runtime_classes()
	st.window = macos.msg_id(parent, 'window')
	st.root_view = parent
	st.event_handler = handler
	st.button_handler = native_new_object('UI2ButtonHandler')
	field := text_input(
		id:          'address'
		action_id:   'address-change'
		submit_id:   'address-submit'
		text:        value
		hint_text:   'Enter a URL'
		multiline:   false
		autocorrect: false
		frame:       frame
		box:         BoxStyle{
			bg:     0xf1f5f9
			radius: 8
		}
		text_style:  TextStyle{
			color: 0x0f172a
			size:  14
		}
	)!
	native := native_new_text_field(field)
	macos.msg_void_bool(native, 'setUsesSingleLineMode:', true)
	macos.msg_void_bool(macos.msg_id(native, 'cell'), 'setScrollable:', true)
	register_control(native, field.action_id, field.submit_id, field.emit_change)
	st.views[field.id] = native
	st.view_kinds[field.id] = .text_field
	macos.msg_void1(parent, 'addSubview:', native)
	macos.release(native)
	resize_embedded_textbox(frame)
	return native
}

pub fn resize_embedded_textbox(frame Rect) {
	st := state()
	native := st.views['address'] or { return }
	parent_height := native_bounds(st.root_view).height
	y := if macos.msg_bool(st.root_view, 'isFlipped') {
		frame.y
	} else {
		parent_height - frame.y - frame.height
	}
	native_set_frame(native, native_rect(frame.x, y, frame.width, frame.height))
}

pub fn select_embedded_textbox() {
	st := state()
	native := st.views['address'] or { return }
	focus('address')
	macos.msg_void1(native, 'selectText:', native_nil_view())
}

pub fn blur_embedded_textbox() {
	st := state()
	// During the submit action AppKit may temporarily detach the field editor.
	// Transfer focus explicitly even while currentEditor is nil.
	macos.msg_void1(st.window, 'makeFirstResponder:', st.root_view)
}

pub fn unmount_embedded_textbox() {
	mut st := state()
	native := st.views['address'] or { return }
	blur_embedded_textbox()
	unregister_node('address', native, .text_field, false)
	st.views.delete('address')
	st.view_kinds.delete('address')
	native_remove_from_superview(native)
	macos.release(st.button_handler)
	st.button_handler = native_nil_view()
	st.window = native_nil_view()
	st.root_view = native_nil_view()
	st.event_handler = EventFn(unsafe { nil })
}
