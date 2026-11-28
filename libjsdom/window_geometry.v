module libjsdom

import dom
import libjs
import platform

fn (mut host Host) install_window_geometry() {
	mut vm := host.vm
	mut global := host.realm.global_object_record()
	mut prototype := libjs.Object.create(host.realm, host.event_target_prototype)
	host.screen_prototype = prototype
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		libjs.Value.from_string(vm.create_string_from_str('Screen')), libjs.attribute_configurable)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal Screen constructor') },
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal Screen constructor') },
		0, libjs.PropertyName.from_str('Screen')).object
	constructor.internal_set_prototype_of(host.event_target_constructor)
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	global.define_direct_property(libjs.PropertyName.from_str('Screen'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	for name in ['width', 'height', 'availWidth', 'availHeight', 'colorDepth', 'pixelDepth', 'isExtended'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			host.require_open(mut vm)!
			if !vm.this_value().is_object() { return vm.throw_error(.type_error, 'Expected Screen') }
			screen := host.screens[voidptr(vm.this_value().as_object())] or { return vm.throw_error(.type_error, 'Expected Screen') }
			if name == 'isExtended' { return libjs.Value.from_bool(screen.is_extended()) }
			value := match name {
				'width' { screen.width() }
				'height' { screen.height() }
				'availWidth' { screen.avail_width() }
				'availHeight' { screen.avail_height() }
				'colorDepth' { int(screen.color_depth()) }
				else { int(screen.pixel_depth()) }
			}
			return libjs.Value.from_f64(f64(value))
		}, unsafe { nil })
	}
	for name in ['screen', 'innerWidth', 'innerHeight', 'outerWidth', 'outerHeight', 'screenX', 'screenY', 'screenLeft', 'screenTop', 'devicePixelRatio'] {
		host.accessor(mut global, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			host.window_receiver(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			mut window := owner.frame_window(mut vm)!
			if name == 'screen' {
				screen := window.screen()
				if wrapper := host.event_target_wrappers[voidptr(screen)] { return libjs.Value.from_object(wrapper) }
				mut object := libjs.Object.create(host.realm, host.screen_prototype)
				object.class_name = 'Screen'
				owner.screens[voidptr(object)] = screen
				owner.event_targets[voidptr(object)] = unsafe { &dom.EventTarget(screen) }
				owner.event_target_wrappers[voidptr(screen)] = object
				return libjs.Value.from_object(object)
			}
			value := match name {
				'innerWidth' { f64(window.inner_width()) }
				'innerHeight' { f64(window.inner_height()) }
				'outerWidth' { f64(window.outer_width()) }
				'outerHeight' { f64(window.outer_height()) }
				'screenX', 'screenLeft' { f64(window.screen_x()) }
				'screenY', 'screenTop' { f64(window.screen_y()) }
				else { window.device_pixel_ratio() }
			}
			return libjs.Value.from_f64(value)
		}, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			host.window_receiver(mut vm)!
			mut global := host.realm.global_object_record()
			global.define_direct_property(libjs.PropertyName.from_str(name), vm.argument(0), libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
			return libjs.js_undefined()
		})
	}
}
