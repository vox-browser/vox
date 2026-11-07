module browserwindow

import macos
import os

fn C.objc_msgSendSuper()

struct ObjcSuper {
	receiver    macos.Id
	super_class voidptr
}

type MsgSuperWindowInit = fn (&ObjcSuper, macos.Sel, macos.Rect, u64, u64, bool) macos.Id

struct HostCounts {
mut:
	initializations int
	close_requests  int
}

const host_counts = &HostCounts{}

// The real backend's subclass boundary, without starting its event loop.
fn counting_host_init(window macos.Id, selector macos.Sel, rect macos.Rect, style u64, backing u64, deferred bool) macos.Id {
	mut counts := unsafe { host_counts }
	counts.initializations++
	parent := ObjcSuper{
		receiver:    window
		super_class: macos.get_class('NSWindow')
	}
	send := unsafe { MsgSuperWindowInit(voidptr(C.objc_msgSendSuper)) }
	return send(&parent, selector, rect, style, backing, deferred)
}

fn host_window_should_close(_self voidptr, _cmd voidptr, _window voidptr) bool {
	mut counts := unsafe { host_counts }
	counts.close_requests++
	return true
}

fn new_window(class_name string, style u64) macos.Id {
	window := macos.msg_id_rect_u64_u64_bool(macos.alloc(class_name),
		'initWithContentRect:styleMask:backing:defer:', macos.rect(0, 0, 800, 600), style, 2,
		false)
	macos.msg_void_bool(window, 'setReleasedWhenClosed:', false)
	return window
}

fn content_size(window macos.Id) macos.Rect {
	return macos.msg_rect(macos.msg_id(window, 'contentView'), 'bounds')
}

fn test_window_host_dimensions_capabilities_focus_close_and_isolation() {
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
	host := macos.allocate_class_pair(macos.get_class('NSWindow'), '_sapp_macos_window')
	macos.add_method(host, 'initWithContentRect:styleMask:backing:defer:',
		voidptr(counting_host_init), '@@:{CGRect={CGPoint=dd}{CGSize=dd}}QQB')
	macos.register_class_pair(host)
	delegate_class := runtime_class('VoxHostWindowDelegate', [
		RuntimeMethod{
			selector:       'windowShouldClose:'
			implementation: voidptr(host_window_should_close)
			types:          'B@:@'
		},
	])
	os.setenv('VOX_TITLED_BROWSER_HOST', '1', true)
	assert !configure_window_host()
	os.unsetenv('VOX_TITLED_BROWSER_HOST')
	assert configure_window_host()
	assert configure_window_host()
	window := new_window('_sapp_macos_window', 0)
	delegate := macos.msg_id(delegate_class, 'new')
	macos.msg_void1(window, 'setDelegate:', delegate)
	assert host_counts.initializations == 1
	style := macos.msg_u64(window, 'styleMask')
	assert style & ns_window_style_titled == 0
	assert style & ns_window_style_closable != 0
	assert style & ns_window_style_miniaturizable != 0
	assert style & ns_window_style_resizable != 0
	assert style & ns_window_style_full_size_content_view != 0
	assert macos.msg_u64(window, 'collectionBehavior') & ns_window_collection_fullscreen_primary != 0
	assert macos.msg_bool(window, 'canBecomeKeyWindow')
	assert macos.msg_bool(window, 'canBecomeMainWindow')
	initial := content_size(window)
	assert initial.width == 800 && initial.height == 600
	prepare_chrome_window(macos.msg_id(window, 'contentView'))
	macos.msg_void_point(window, 'setMinSize:', macos.point(640, 480))
	macos.msg_void_point(window, 'setContentSize:', macos.point(900, 700))
	resized := content_size(window)
	assert resized.width == 900 && resized.height == 700
	minimum := macos.msg_point(window, 'minSize')
	assert minimum.x == 640 && minimum.y == 480
	restore_chrome_window()
	assert macos.msg_u64(window, 'styleMask') & ns_window_style_titled == 0
	macos.msg_void1(window, 'performClose:', nil_id())
	assert host_counts.close_requests == 1
	// Ordinary AppKit windows keep their normal title bar and initializer.
	ordinary := new_window('NSWindow', ns_window_style_titled)
	assert macos.msg_u64(ordinary, 'styleMask') & ns_window_style_titled != 0
	assert host_counts.initializations == 1
	macos.msg_void(ordinary, 'close')
	macos.msg_void1(window, 'setDelegate:', nil_id())
	macos.release(delegate)
}

fn test_chrome_window_styling_is_restored() {
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
	window := new_window('NSWindow', ns_window_style_titled | ns_window_style_closable | ns_window_style_miniaturizable | ns_window_style_resizable)
	defer { macos.msg_void(window, 'close') }
	original_mask := macos.msg_u64(window, 'styleMask')
	original_content := content_size(window)
	content := macos.msg_id(window, 'contentView')
	prepare_chrome_window(content)
	assert macos.msg_i64(window, 'titleVisibility') == ns_window_title_hidden
	assert macos.msg_u64(window, 'styleMask') & ns_window_style_full_size_content_view != 0
	assert content_size(window).width == original_content.width
	assert content_size(window).height == original_content.height
	for i in 0 .. 3 {
		assert macos.msg_bool(standard_window_button(window, i), 'isHidden')
	}
	prepare_chrome_window(content)
	restore_chrome_window()
	assert macos.msg_u64(window, 'styleMask') == original_mask
	for i in 0 .. 3 {
		assert !macos.msg_bool(standard_window_button(window, i), 'isHidden')
	}
	restore_chrome_window()
}
