module ui2

import macos

// Mount ordinary UI2 elements in the browser's existing window. Only the two
// chrome strips have views: the document continues receiving GG's input and
// native paint callbacks directly, without a transparent overlay intercepting it.
pub fn mount_embedded_browser(parent voidptr, elements []Element, handler EventFn) ! {
	mut st := state()
	if !native_is_nil(st.window) {
		return error('embedded UI2 browser controls are already mounted')
	}
	ensure_runtime_classes()
	st.window = macos.msg_id(parent, 'window')
	st.root_view = parent
	st.event_handler = handler
	st.button_handler = native_new_object('UI2ButtonHandler')
	update_embedded_browser(elements)
	field := embedded_browser_control('address')
	macos.msg_void_bool(field, 'setUsesSingleLineMode:', true)
	macos.msg_void_bool(macos.msg_id(field, 'cell'), 'setScrollable:', true)
}

pub fn update_embedded_browser(elements []Element) {
	st := state()
	if native_is_nil(st.root_view) { return }
	parent_height := native_bounds(st.root_view).height
	flipped := macos.msg_bool(st.root_view, 'isFlipped')
	mut active := map[string]bool{}
	for i, element in elements {
		frame := element.frame
		placed := Element{
			...element
			frame: Rect{
				...frame
				y: if flipped { frame.y } else { parent_height - frame.y - frame.height }
			}
		}
		key := reconciliation_child_key('', i, placed)
		render_element(st.root_view, placed, key, mut active)
	}
	remove_stale_nodes(active)
}

pub fn embedded_browser_control(id string) voidptr {
	st := state()
	return st.views[id] or { unsafe { nil } }
}

pub fn select_embedded_textbox() {
	field := embedded_browser_control('address')
	focus('address')
	macos.msg_void1(field, 'selectText:', native_nil_view())
}

pub fn blur_embedded_textbox() {
	st := state()
	// AppKit can temporarily detach its field editor during a submit action.
	macos.msg_void1(st.window, 'makeFirstResponder:', st.root_view)
}

pub fn unmount_embedded_browser() {
	mut st := state()
	if native_is_nil(st.window) { return }
	blur_embedded_textbox()
	remove_stale_nodes(map[string]bool{})
	st.views.clear()
	st.view_keys.clear()
	st.view_kinds.clear()
	st.label_places.clear()
	macos.release(st.button_handler)
	st.button_handler = native_nil_view()
	st.window = native_nil_view()
	st.root_view = native_nil_view()
	st.event_handler = EventFn(unsafe { nil })
}
