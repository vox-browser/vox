// vfmt off
module ui2

$if !ui2_custom_rendering ? {
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
	mut callbacks := embedded_callbacks()
	callbacks.handler = handler
	st.event_handler = embedded_browser_event
	st.button_handler = native_new_object('UI2ButtonHandler')
	update_embedded_browser(elements)
}

struct EmbeddedCallbacks {
mut:
	handler EventFn = unsafe { nil }
}
const embedded_callbacks_ = &EmbeddedCallbacks{}
fn embedded_callbacks() &EmbeddedCallbacks { return unsafe { embedded_callbacks_ } }
fn embedded_browser_event(event string) {
	mut normalized := event
	if event.starts_with('pointer:') && !macos.msg_bool(state().root_view, 'isFlipped') {
		mut parts := event.split(':')
		if parts.len == 5 {
			parts[4] = (native_bounds(state().root_view).height - parts[4].f64()).str()
			normalized = parts.join(':')
		}
	}
	callbacks := embedded_callbacks()
	if voidptr(callbacks.handler) != unsafe { nil } { callbacks.handler(normalized) }
}

pub fn update_embedded_browser(elements []Element) {
	st := state()
	if native_is_nil(st.root_view) { return }
	parent_height := native_bounds(st.root_view).height
	flipped := macos.msg_bool(st.root_view, 'isFlipped')
	mut active := map[string]bool{}
	// The settings window shares UI2's control registry, but owns its native
	// root. Toolbar reconciliation must retain that separate subtree.
	for key, _ in st.nodes {
		if key == 'vox-settings' || key.starts_with('vox-settings/') || key.starts_with('vox-panel/') { active[key] = true }
	}
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
	mut ids := map[string]bool{}
	collect_embedded_control_ids(elements, mut ids)
	remove_stale_embedded_registrations(active, ids)
	remove_stale_nodes(active)
}

// UI2 removes native nodes separately from its control-ID registry. Dynamic
// strips and overflow rows must disappear from both, including after a resize
// moves a surviving ID into a different subtree.
fn collect_embedded_control_ids(elements []Element, mut ids map[string]bool) {
	for element in elements {
		if element.id != '' { ids[element.id] = true }
		collect_embedded_control_ids(element.children, mut ids)
	}
}
fn remove_stale_embedded_registrations(active map[string]bool, ids map[string]bool) {
	mut st := state()
	mut stale := []string{}
	for id, key in st.view_keys {
		if key !in active || (id !in ids && key != 'vox-settings' && !key.starts_with('vox-settings/') && !key.starts_with('vox-panel/')) { stale << id }
	}
	for id in stale {
		st.views.delete(id)
		st.view_keys.delete(id)
		st.view_kinds.delete(id)
		st.text_area_direct.delete(id)
		st.label_places.delete(id)
	}
}

pub fn update_embedded_settings(parent voidptr, element Element) {
	mut active := map[string]bool{}
	render_element(parent, element, 'vox-settings', mut active)
	remove_stale_nodes_below('vox-settings', active)
}

pub fn remove_embedded_settings() {
	st := state()
	// UI2 removes native nodes separately from its public control-ID registry.
	clear_subtree_registrations('vox-settings')
	mut active := map[string]bool{}
	for key, _ in st.nodes {
		if key != 'vox-settings' && !key.starts_with('vox-settings/') { active[key] = true }
	}
	// Include the root itself; remove_stale_nodes_below retains its root.
	remove_stale_nodes(active)
}

pub fn embedded_browser_control(id string) voidptr {
	st := state()
	return st.views[id] or { unsafe { nil } }
}

pub fn embedded_control_attached(id string) bool {
	control := embedded_browser_control(id)
	return !native_is_nil(control) && !native_is_nil(macos.msg_id(control, 'window'))
}

pub fn copy_embedded_text(value string) {
	board := macos.msg_id(macos.get_class('NSPasteboard'), 'generalPasteboard')
	macos.msg_void(board, 'clearContents')
	macos.msg_void2(board, 'setString:forType:', macos.nsstring(value), macos.nsstring('public.utf8-plain-text'))
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
	remove_embedded_keys()
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

}
