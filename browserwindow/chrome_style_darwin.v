module browserwindow

import macos
import os

// UI2 owns the whole content area. Its Sokol host does not need a native title
// bar, but still needs the capabilities normally supplied by a titled window.
// Only Sokol's window subclass is adapted; other AppKit and UI2 windows keep
// their own behavior.

type WindowInitializerFn = fn (window macos.Id, selector macos.Sel, rect macos.Rect, style u64, backing u64, deferred bool) macos.Id

type PerformCloseFn = fn (window macos.Id, selector macos.Sel, sender macos.Id)

struct ChromeWindowState {
mut:
	original_initializer voidptr
	original_close       voidptr
	// A zeroing weak reference to the styled window.
	styled_window                 voidptr
	original_mask                 u64
	original_title_visibility     i64
	original_transparent_titlebar bool
	original_separator            i64
	original_buttons_hidden       [3]bool
}

const chrome_window_state = &ChromeWindowState{}

fn chrome_host_accepts_focus(_window voidptr, _selector voidptr) bool {
	return true
}

fn chrome_host_perform_close(window macos.Id, selector macos.Sel, sender macos.Id) {
	style := macos.msg_u64(window, 'styleMask')
	if style & ns_window_style_titled != 0 {
		original := unsafe { PerformCloseFn(chrome_window_state.original_close) }
		original(window, selector, sender)
		return
	}
	// AppKit's performClose: checks its standard button. This host has no title
	// bar or button, so deliver the same close request to the existing delegate.
	if style & ns_window_style_closable == 0 {
		return
	}
	delegate := macos.msg_id(window, 'delegate')
	if !macos.responds_to(delegate, 'windowShouldClose:')
		|| macos.msg_bool_id(delegate, 'windowShouldClose:', window) {
		macos.msg_void(window, 'close')
	}
}

fn chrome_initialize_window_host(window macos.Id, selector macos.Sel, rect macos.Rect, style u64, backing u64, deferred bool) macos.Id {
	mut mask := style
	if mask & ns_window_style_titled == 0 {
		mask |= ns_window_style_closable | ns_window_style_miniaturizable | ns_window_style_resizable | ns_window_style_full_size_content_view
	}
	original := unsafe { WindowInitializerFn(chrome_window_state.original_initializer) }
	initialized := original(window, selector, rect, mask, backing, deferred)
	if !is_nil(initialized) && mask & ns_window_style_titled == 0 {
		behavior := macos.msg_u64(initialized, 'collectionBehavior')
		macos.msg_void_u64(initialized, 'setCollectionBehavior:', behavior | ns_window_collection_fullscreen_primary)
	}
	return initialized
}

// configure_window_host makes Sokol's borderless window a full browser host:
// closable, miniaturizable, resizable, full-size content, focusable and
// fullscreen-capable. It returns false when the titled host is requested
// (VOX_TITLED_BROWSER_HOST), the backend's window class is absent, or that
// class already customizes its focus policy.
pub fn configure_window_host() bool {
	if os.getenv_opt('VOX_TITLED_BROWSER_HOST') != none {
		return false
	}
	mut state := unsafe { chrome_window_state }
	if !is_nil(state.original_initializer) {
		return true
	}
	host := lookup_class('_sapp_macos_window')
	if is_nil(host) {
		return false
	}
	initialize := macos.sel('initWithContentRect:styleMask:backing:defer:')
	method := class_instance_method(host, initialize)
	// Preserve an unfamiliar backend's focus policy rather than replacing it.
	parent := class_superclass(host)
	for name in ['canBecomeKeyWindow', 'canBecomeMainWindow'] {
		focus := macos.sel(name)
		if class_method_implementation(host, focus) != class_method_implementation(parent, focus) {
			return false
		}
	}
	if is_nil(method) {
		return false
	}
	state.original_initializer = method_implementation(method)
	close_selector := macos.sel('performClose:')
	close := class_instance_method(host, close_selector)
	state.original_close = method_implementation(close)
	class_add_method(host, close_selector, voidptr(chrome_host_perform_close), method_type_encoding(close))
	for name in ['canBecomeKeyWindow', 'canBecomeMainWindow'] {
		focus := macos.sel(name)
		class_add_method(host, focus, voidptr(chrome_host_accepts_focus), method_type_encoding(class_instance_method(parent, focus)))
	}
	class_replace_method(host, initialize, voidptr(chrome_initialize_window_host), method_type_encoding(method))
	return true
}

fn standard_window_button(window macos.Id, button int) macos.Id {
	return macos.msg_id_u64(window, 'standardWindowButton:', u64(button))
}

// restore_chrome_window returns the window last styled by
// prepare_chrome_window to its original title bar and buttons.
pub fn restore_chrome_window() {
	mut state := unsafe { chrome_window_state }
	window := load_weak(&state.styled_window)
	if !is_nil(window) {
		macos.msg_void_u64(window, 'setStyleMask:', state.original_mask)
		macos.msg_void_i64(window, 'setTitleVisibility:', state.original_title_visibility)
		macos.msg_void_bool(window, 'setTitlebarAppearsTransparent:', state.original_transparent_titlebar)
		macos.msg_void_i64(window, 'setTitlebarSeparatorStyle:', state.original_separator)
		for i in 0 .. 3 {
			macos.msg_void_bool(standard_window_button(window, i), 'setHidden:', state.original_buttons_hidden[i])
		}
	}
	store_weak(&state.styled_window, unsafe { nil })
}

// prepare_chrome_window lets UI2 draw the top row of the window containing
// `parent`: the title is hidden, the title bar transparent and its buttons
// hidden, while the window keeps its normal close delegate and capabilities.
// Full-size content preserves the content size Sokol and screenshot clients
// requested.
pub fn prepare_chrome_window(parent voidptr) {
	window := macos.msg_id(macos.Id(parent), 'window')
	mut state := unsafe { chrome_window_state }
	if is_nil(window) || window == load_weak(&state.styled_window) {
		return
	}
	restore_chrome_window()
	store_weak(&state.styled_window, window)
	state.original_mask = macos.msg_u64(window, 'styleMask')
	state.original_title_visibility = macos.msg_i64(window, 'titleVisibility')
	state.original_transparent_titlebar = macos.msg_bool(window, 'titlebarAppearsTransparent')
	state.original_separator = macos.msg_i64(window, 'titlebarSeparatorStyle')
	for i in 0 .. 3 {
		state.original_buttons_hidden[i] = macos.msg_bool(standard_window_button(window, i), 'isHidden')
	}
	macos.msg_void_i64(window, 'setTitleVisibility:', ns_window_title_hidden)
	macos.msg_void_bool(window, 'setTitlebarAppearsTransparent:', true)
	macos.msg_void_u64(window, 'setStyleMask:', state.original_mask | ns_window_style_full_size_content_view)
	macos.msg_void_i64(window, 'setTitlebarSeparatorStyle:', ns_titlebar_separator_none)
	for i in 0 .. 3 {
		macos.msg_void_bool(standard_window_button(window, i), 'setHidden:', true)
	}
}
