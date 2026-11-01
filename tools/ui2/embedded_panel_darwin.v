// vfmt off
module ui2

$if !ui2_custom_rendering ? {
	import macos

	struct EmbeddedPanel {
		window NativeView
		root NativeView
		delegate NativeView
	}
	struct EmbeddedPanels {
	mut:
		panels map[string]EmbeddedPanel
	}
	const embedded_panels_ = &EmbeddedPanels{}
	fn embedded_panels() &EmbeddedPanels { return unsafe { embedded_panels_ } }

	pub fn embedded_panel_visible(id string) bool {
		panel := embedded_panels().panels[id] or { return false }
		return macos.msg_bool(panel.window, 'isVisible')
	}
	pub fn show_embedded_panel(id string, title string, width f64, height f64, element Element) {
		mut registry := embedded_panels()
		mut panel := registry.panels[id] or { EmbeddedPanel{} }
		if native_is_nil(panel.window) {
			if macos.get_class('UI2EmbeddedPanelDelegate') == unsafe { nil } {
				cls := macos.allocate_class_pair(macos.get_class('NSObject'), 'UI2EmbeddedPanelDelegate')
				macos.add_method(cls, 'windowShouldClose:', ui2_embedded_panel_close, 'B@:@')
				macos.register_class_pair(cls)
			}
			window := macos.msg_id_rect_u64_u64_bool(macos.alloc('NSPanel'), 'initWithContentRect:styleMask:backing:defer:', macos.rect(0, 0, width, height), 3, 2, false)
			delegate := native_new_object('UI2EmbeddedPanelDelegate')
			root := native_new_flipped_view(native_rect(0, 0, width, height), BoxStyle{})
			macos.msg_void1(window, 'setContentView:', root)
			macos.msg_void1(window, 'setDelegate:', delegate)
			macos.msg_void1(window, 'setTitle:', macos.nsstring(title))
			macos.msg_void_bool(window, 'setReleasedWhenClosed:', false)
			// Keep auxiliary windows on the host display, including test placement.
			screen := macos.msg_id(state().window, 'screen')
			visible := macos.msg_rect(screen, 'visibleFrame')
			frame := macos.msg_rect(window, 'frame')
			macos.msg_void_point(window, 'setFrameOrigin:', macos.point(visible.x + (visible.width - frame.width) / 2,
				visible.y + (visible.height - frame.height) / 2))
			panel = EmbeddedPanel{window: window, root: root, delegate: delegate}
			registry.panels[id] = panel
		}
		mut active := map[string]bool{}
		key := 'vox-panel/${id}'
		render_element(panel.root, element, key, mut active)
		remove_stale_nodes_below(key, active)
		macos.msg_void1(panel.window, 'makeKeyAndOrderFront:', native_nil_view())
	}
	pub fn hide_embedded_panel(id string) {
		panel := embedded_panels().panels[id] or { return }
		macos.msg_void1(panel.window, 'endEditingFor:', native_nil_view())
		macos.msg_void(panel.window, 'close')
	}
	pub fn remove_embedded_panel(id string) {
		panel := embedded_panels().panels[id] or { return }
		hide_embedded_panel(id)
		clear_subtree_registrations('vox-panel/${id}')
		mut active := map[string]bool{}
		for key, _ in state().nodes {
			if key != 'vox-panel/${id}' && !key.starts_with('vox-panel/${id}/') { active[key] = true }
		}
		remove_stale_nodes(active)
		macos.msg_void1(panel.window, 'setDelegate:', native_nil_view())
		macos.release(panel.delegate)
		macos.release(panel.root)
		macos.release(panel.window)
		mut registry := embedded_panels()
		registry.panels.delete(id)
	}
	pub fn embedded_event_panel(event voidptr) string {
		window := macos.msg_id(macos.Id(event), 'window')
		for id, panel in embedded_panels().panels { if voidptr(panel.window) == voidptr(window) { return id } }
		return ''
	}
	pub fn embedded_owns_event(event voidptr) bool {
		window := macos.msg_id(macos.Id(event), 'window')
		return voidptr(window) == voidptr(state().window) || embedded_event_panel(event) != ''
	}
	@[export: 'ui2_embedded_panel_close']
	fn ui2_embedded_panel_close(_self voidptr, _cmd voidptr, window voidptr) bool {
		for id, panel in embedded_panels().panels {
			if voidptr(panel.window) == window {
				state().event_handler('panel-close:${id}')
				break
			}
		}
		return true
	}
}
