// vfmt off
module ui2

$if !ui2_custom_rendering ? {
	import macos
	#include "@VMODROOT/vox/embedded_input_darwin.h"
	fn C.ui2_install_embedded_key_monitor(window voidptr, callback fn (voidptr) i32)
	fn C.ui2_remove_embedded_key_monitor()
	fn C.ui2_embedded_edit(event voidptr, action &u8) i32

	struct EmbeddedKeyCurrent {
	mut:
		event voidptr
	}
	const embedded_key_current_ = &EmbeddedKeyCurrent{}
	fn embedded_current_key_event() voidptr {
		current := embedded_key_current_
		return if current.event != unsafe { nil } { current.event } else { voidptr(macos.msg_id(native_current_app(), 'currentEvent')) }
	}
	pub fn embedded_key_panel() string { return embedded_event_panel(embedded_current_key_event()) }
	pub fn install_embedded_keys(handler KeyEventFn) {
		on_key_event(handler)
		C.ui2_install_embedded_key_monitor(state().window, ui2_embedded_key_event)
	}
	pub fn remove_embedded_keys() { C.ui2_remove_embedded_key_monitor(); C.ui2_remove_embedded_wheel_monitor() }

	@[export: 'ui2_embedded_key_event']
	fn ui2_embedded_key_event(event voidptr) i32 {
		mut current := unsafe { embedded_key_current_ }
		current.event = event
		defer { current.event = unsafe { nil } }
		if !embedded_owns_event(event) { return 0 }
		if dispatch_typed_key_event(macos.Id(event)) { return 1 }
		key := key_event_string(macos.Id(event))
		action := match key {
			'cmd+a' { 'selectAll:' }
			'cmd+x' { 'cut:' }
			'cmd+c' { 'copy:' }
			'cmd+v' { 'paste:' }
			'cmd+z' { 'undo:' }
			'cmd+y', 'cmd+shift+z' { 'redo:' }
			else { return 0 }
		}
		return C.ui2_embedded_edit(event, action.str)
	}
	pub fn embedded_key_repeat() bool {
		return macos.msg_bool(macos.Id(embedded_current_key_event()), 'isARepeat')
	}
	pub fn embedded_host_action(action string) {
		window := state().window
		match action {
			'show' {
				if macos.msg_bool(window, 'isMiniaturized') {
					macos.msg_void1(window, 'deminiaturize:', native_nil_view())
				}
				macos.msg_void1(window, 'makeKeyAndOrderFront:', native_nil_view())
				macos.msg_void_bool(native_current_app(), 'activateIgnoringOtherApps:', true)
			}
			'close' { macos.msg_void1(window, 'performClose:', native_nil_view()) }
			'minimize' { macos.msg_void1(window, 'performMiniaturize:', native_nil_view()) }
			'zoom' { macos.msg_void1(window, 'zoom:', native_nil_view()) }
			'drag' { macos.msg_void1(window, 'performWindowDragWithEvent:', macos.msg_id(native_current_app(), 'currentEvent')) }
			else {}
		}
	}
	pub fn install_embedded_menus(menus []Menu) {
		publish_menu_context(state().event_handler, 'Vox', state().window)
		set_menu_bar(menus)
	}
	fn C.ui2_install_embedded_wheel_monitor(callback fn (voidptr) i32)
	fn C.ui2_remove_embedded_wheel_monitor()
	struct EmbeddedWheel {
	mut:
		handler fn (f64, f64, f64, f64) bool = unsafe { nil }
	}
	const embedded_wheel_ = &EmbeddedWheel{}
	pub fn install_embedded_wheel(handler fn (f64, f64, f64, f64) bool) {
		mut wheel := unsafe { embedded_wheel_ }
		wheel.handler = handler
		C.ui2_install_embedded_wheel_monitor(ui2_embedded_wheel_event)
	}
	@[export: 'ui2_embedded_wheel_event']
	fn ui2_embedded_wheel_event(event voidptr) i32 {
		if !embedded_owns_event(event) || embedded_event_panel(event) != '' { return 0 }
		wheel := embedded_wheel_
		if voidptr(wheel.handler) == unsafe { nil } { return 0 }
		point := native_event_point(state().root_view, event)
		y := if macos.msg_bool(state().root_view, 'isFlipped') { point.y } else { native_bounds(state().root_view).height - point.y }
		return i32(wheel.handler(point.x, y, macos.msg_f64(macos.Id(event), 'scrollingDeltaX'), macos.msg_f64(macos.Id(event), 'scrollingDeltaY')))
	}
	@[export: 'ui2_embedded_pointer_other']
	fn ui2_embedded_pointer_other(view voidptr, _cmd voidptr, event voidptr) {
		if macos.msg_i64(macos.Id(event), 'buttonNumber') == 2 { fire_pointer_event(NativeView(view), 'middle', event) }
	}

}
