module libjsdom

import domurl
import libjs

fn (mut host Host) install_urls() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.url_prototype = prototype
	owner := &host
	construct := fn [owner] (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object {
		owner.require_open(mut vm)!
		input := vm.argument(0).to_primitive_string(mut vm)!.str()
		base := if vm.argument_count() < 2 || vm.argument(1).is_undefined() {
			?string(none)
		} else {
			vm.argument(1).to_primitive_string(mut vm)!.str()
		}
		url := domurl.DOMURL.construct_impl(input, base) or { return vm.throw_error(.type_error, err.msg()) }
		mut host := unsafe { &Host(owner) }
		return host.wrap_url(url, false)
	}
	host.closures << voidptr(construct)
	function := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value {
			return vm.throw_error(.type_error, 'URL constructor requires new')
		}, construct, 1, libjs.PropertyName.from_str('URL'))
	mut constructor := function.object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('URL'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	location := domurl.DOMURL.construct_impl(host.document.url.serialize(), none)!
	global.define_direct_property(libjs.PropertyName.from_str('location'), libjs.Value.from_object(host.wrap_url(location, true)), libjs.attribute_enumerable)
}

fn (mut host Host) wrap_url(url &domurl.DOMURL, location bool) &libjs.Object {
	mut object := libjs.Object.create(host.realm, if location {
		host.realm.object_prototype_record()
	} else {
		host.url_prototype
	})
	object.class_name = if location { 'Location' } else { 'URL' }
	for name in ['href', 'pathname', 'hash', 'search', 'origin'] {
		host.accessor(mut object, name, fn [host, url, name, object] (mut vm libjs.VM) !libjs.Value {
			host.require_open(mut vm)!
			if !vm.this_value().is_object() || voidptr(vm.this_value().as_object()) != voidptr(object) {
				return vm.throw_error(.type_error, 'URL property called on incompatible receiver')
			}
			text := match name {
				'href' { url.href() }
				'pathname' { url.pathname() }
				'hash' { url.hash() }
				'search' { url.search() }
				else { url.origin() }
			}
			return libjs.Value.from_string(vm.create_string_from_str(text))
		}, unsafe { nil })
	}
	host.method(mut object, 'toString', 0, fn [host, url, object] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		if !vm.this_value().is_object() || voidptr(vm.this_value().as_object()) != voidptr(object) {
			return vm.throw_error(.type_error, 'URL method called on incompatible receiver')
		}
		return libjs.Value.from_string(vm.create_string_from_str(url.href()))
	})
	params := url.search_params()
	mut search_params := libjs.Object.create(host.realm, host.realm.object_prototype)
	search_params.class_name = 'URLSearchParams'
	host.method(mut search_params, 'get', 1, fn [host, params, search_params] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		if !vm.this_value().is_object() || voidptr(vm.this_value().as_object()) != voidptr(search_params) {
			return vm.throw_error(.type_error, 'URLSearchParams method called on incompatible receiver')
		}
		key := vm.argument(0).to_primitive_string(mut vm)!.str()
		return if value := params.get(key) {
			libjs.Value.from_string(vm.create_string_from_str(value))
		} else {
			libjs.js_null()
		}
	})
	object.define_direct_property(libjs.PropertyName.from_str('searchParams'), libjs.Value.from_object(search_params), libjs.attribute_enumerable)
	return object
}
