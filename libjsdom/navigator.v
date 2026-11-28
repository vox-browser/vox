// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import libjs
import loader
import platform

// Use the owning Window's actual Navigator. Do not expose the untranslated
// optional capability placeholders as functional Clipboard/Permissions APIs.
fn (mut host Host) native_navigator(mut vm libjs.VM) !&html.Navigator {
	host.require_open(mut vm)!
	if host.navigator_native != unsafe { nil } { return host.navigator_native }
	if !loader.is_initialized() { loader.initialize() }
	if window := host.document.get_window() {
		for candidate in html.all_windows() {
			if voidptr(candidate) == voidptr(window) {
				host.navigator_native = candidate.navigator()
				return host.navigator_native
			}
		}
		return vm.throw_error(.type_error, 'Navigator requires its owning HTML Window')
	}
	window := html.WindowModel.create_top_level(host.document, none, '') or { return host.dom_error(mut vm, err) }
	host.navigator_native = window.navigator()
	return host.navigator_native
}

fn (host &Host) navigator_receiver(mut vm libjs.VM) ! {
	host.require_open(mut vm)!
	if !vm.this_value().is_object() || voidptr(vm.this_value().as_object()) != voidptr(host.navigator_object) { return vm.throw_error(.type_error, 'Navigator member called on incompatible receiver') }
}

fn (mut host Host) navigator_get(mut vm libjs.VM, name string) !libjs.Value {
	host.navigator_receiver(mut vm)!
	native := host.native_navigator(mut vm)!
	match name {
		'languages' {
			languages := native.languages()
			if host.navigator_frozen_languages != unsafe { nil } && languages == host.navigator_languages { return libjs.Value.from_object(host.navigator_frozen_languages) }
			mut values := []libjs.Value{}
			for text in languages { values << libjs.Value.from_string(vm.create_string_from_str(text)) }
			mut array := libjs.ArrayObject.create_from(mut vm, host.realm, values, host.realm.array_prototype_record())!.object
			if !array.set_integrity_level(mut vm, .frozen)! { return vm.throw_error(.type_error, 'Unable to freeze Navigator languages') }
			host.navigator_languages = languages
			host.navigator_frozen_languages = array
			return libjs.Value.from_object(array)
		}
		'onLine' { return libjs.Value.from_bool(native.on_line()) }
		'cookieEnabled' { return libjs.Value.from_bool(native.cookie_enabled()) }
		'webdriver' { return libjs.Value.from_bool(native.webdriver()) }
		'pdfViewerEnabled' { return libjs.Value.from_bool(native.pdf_viewer_enabled()) }
		'hardwareConcurrency' { return libjs.Value.from_f64(f64(native.hardware_concurrency())) }
		else {}
	}
	text := match name {
		'language' { native.language() }
		'appCodeName' { native.app_code_name() }
		'appName' { native.app_name() }
		'appVersion' { native.app_version() }
		'platform' { native.platform() }
		'product' { native.product() }
		'productSub' { native.product_sub() }
		'userAgent' { native.user_agent() }
		'vendor' { native.vendor() }
		else { native.vendor_sub() }
	}
	return libjs.Value.from_string(vm.create_string_from_str(text))
}

fn (mut host Host) install_navigator() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.navigator_prototype = prototype
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('Navigator')), libjs.attribute_configurable)
	for name in ['language', 'languages', 'appCodeName', 'appName', 'appVersion', 'platform', 'product', 'productSub', 'userAgent', 'vendor', 'vendorSub', 'onLine', 'cookieEnabled', 'webdriver', 'pdfViewerEnabled', 'hardwareConcurrency'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			return owner.navigator_get(mut vm, name)
		}, unsafe { nil })
	}
	host.method_attributes(mut prototype, 'javaEnabled', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.navigator_receiver(mut vm)!
		mut owner := unsafe { &Host(host) }
		return libjs.Value.from_bool(owner.native_navigator(mut vm)!.java_enabled())
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal Navigator constructor') },
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal Navigator constructor') }, 0, libjs.PropertyName.from_str('Navigator')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('Navigator'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	for name in ['navigator', 'clientInformation'] {
		getter := fn [host] (mut vm libjs.VM) !libjs.Value {
			host.require_open(mut vm)!
			receiver := vm.this_value()
			if !receiver.is_nullish() && (!receiver.is_object() || voidptr(receiver.as_object()) != voidptr(host.realm.global_object_record())) { return vm.throw_error(.type_error, 'Illegal Window receiver') }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			owner.native_navigator(mut vm)!
			if owner.navigator_object == unsafe { nil } { owner.navigator_object = libjs.Object.create(host.realm, host.navigator_prototype) }
			return libjs.Value.from_object(owner.navigator_object)
		}
		setter := if name == 'clientInformation' { libjs.NativeFunctionPointer(fn [host] (mut vm libjs.VM) !libjs.Value {
			host.require_open(mut vm)!
			receiver := vm.this_value()
			if !receiver.is_object() || voidptr(receiver.as_object()) != voidptr(host.realm.global_object_record()) { return vm.throw_error(.type_error, 'Illegal Window receiver') }
			mut global := host.realm.global_object_record()
			global.define_direct_property(libjs.PropertyName.from_str('clientInformation'), vm.argument(0), libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
			return libjs.js_undefined()
		}) } else { unsafe { nil } }
		host.accessor(mut global, name, getter, setter)
	}
}
