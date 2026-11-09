@[has_globals]
module browserjs

import css
import dom
import html
import webidl

__global window_screen_bindings_ = map[voidptr]bool{}

pub fn (mut runtime Runtime) install_window_screen_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if window_screen_bindings_[owner] { return }
	settings := runtime.scripting_settings_ or { return error('Screen requires its actual owning Window settings') }
	target := settings.global_object()
	if target.data.kind != .window { return error('Screen requires an actual Window global') }
	mut window := unsafe { &html.WindowModel(target) }
	screen := window.screen()
	mut mutable_screen := unsafe { &css.Screen(screen) }
	orientation := mutable_screen.orientation()
	runtime.install_dom_exception_binding()!
	runtime.install_event_target_binding()!
	operation := runtime.make_value_host_function(fn [owner, screen, orientation] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.screen_operation(screen, orientation, args) or {
			runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(window_screen_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	wrappers := runtime.call_javascript_function(factory, global, [operation, global,
		C.vox_jsc_JSValueMakeBoolean(runtime.context, settings.is_secure_context())])!
	runtime.retain_javascript_value(wrappers)!
	defer { runtime.release_javascript_value(wrappers) }
	for index, native in [voidptr(screen), voidptr(orientation)] {
		mut exception := unsafe { nil }
		wrapper := C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, wrappers, u32(index), &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		runtime.bind_event_target(wrapper, unsafe { &dom.EventTarget(native) })!
	}
	register_runtime_binding(mut window_screen_bindings_, owner, true)
	runtime.add_close_handler(fn [owner] () { unregister_runtime_binding(mut window_screen_bindings_, owner) })
}

fn (mut runtime Runtime) screen_operation(screen &css.Screen, orientation &css.ScreenOrientation, args []voidptr) !voidptr {
	if args.len == 0 { return error('Missing Screen operation') }
	name := runtime.binding_dom_string(args[0])!
	if name == 'getHandler' || name == 'setHandler' {
		if args.len < 2 { return error('Missing Screen handler receiver') }
		target := runtime.native_event_target(args[1])!
		if voidptr(target) != voidptr(screen) && voidptr(target) != voidptr(orientation) {
			return runtime.event_binding_type_error('Illegal Screen handler receiver')
		}
		if name == 'getHandler' { return runtime.javascript_event_handler(target, 'change') }
		if args.len < 3 { return error('Missing Screen handler value') }
		runtime.set_javascript_event_handler(target, 'change', args[2])!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	if name == 'isExtended' { return C.vox_jsc_JSValueMakeBoolean(runtime.context, screen.is_extended()) }
	if name == 'type' { return runtime.binding_string(orientation.type_().str().replace('_', '-')) }
	if name == 'lock' {
		if args.len < 2 { return error('Missing Screen orientation') }
		value := runtime.binding_dom_string(args[1])!
		lock_type := match value {
			'any' { css.OrientationLockType.any_ }
			'natural' { css.OrientationLockType.natural }
			'landscape' { css.OrientationLockType.landscape }
			'portrait' { css.OrientationLockType.portrait }
			'portrait-primary' { css.OrientationLockType.portrait_primary }
			'portrait-secondary' { css.OrientationLockType.portrait_secondary }
			'landscape-primary' { css.OrientationLockType.landscape_primary }
			'landscape-secondary' { css.OrientationLockType.landscape_secondary }
			else { return runtime.event_binding_type_error('Invalid Screen orientation') }
		}
		orientation.lock(lock_type) or {
			message := err.msg()
			if !message.starts_with('NotSupportedError:') { return err }
			exception := webidl.dom_exception_value(webidl.DOMException.create('NotSupportedError',
				message['NotSupportedError:'.len..].trim_left(' ')))
			return runtime.actual_javascript_exception(runtime.javascript_dom_exception(exception)!)
		}
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	if name == 'unlock' {
		orientation.unlock()
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	value := match name {
		'availWidth' { f64(screen.avail_width()) }
		'availHeight' { f64(screen.avail_height()) }
		'width' { f64(screen.width()) }
		'height' { f64(screen.height()) }
		'colorDepth' { f64(screen.color_depth()) }
		'pixelDepth' { f64(screen.pixel_depth()) }
		'angle' { f64(orientation.angle()) }
		else { return error('Unknown Screen operation') }
	}
	return C.vox_jsc_JSValueMakeNumber(runtime.context, value)
}
