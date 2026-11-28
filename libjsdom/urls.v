module libjsdom

import domurl
import libjs
import platform

fn url_arguments(mut vm libjs.VM) !(string, ?string) {
	if vm.argument_count() < 1 { return vm.throw_error(.type_error, 'URL requires an input argument') }
	input := query_usv(mut vm, vm.argument(0))!
	base := if vm.argument(1).is_undefined() { ?string(none) } else { ?string(query_usv(mut vm, vm.argument(1))!) }
	return input, base
}

fn (mut host Host) install_urls() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.url_prototype = prototype
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('URL')), libjs.attribute_configurable)
	owner := &host
	construct := fn [owner] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		owner.require_open(mut vm)!
		// WebIDL converts arguments before NewTarget.prototype, which is read
		// before the URL parser steps (including a parser failure).
		input, base := url_arguments(mut vm)!
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		url := domurl.DOMURL.construct_impl(input, base) or { return vm.throw_error(.type_error, err.msg()) }
		mut host := unsafe { &Host(owner) }
		return host.wrap_url(url, if parent.is_object() { parent.as_object() } else { host.url_prototype })
	}
	host.closures << voidptr(construct)
	function := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value {
			return vm.throw_error(.type_error, 'URL constructor requires new')
		}, construct, 1, libjs.PropertyName.from_str('URL'))
	mut constructor := function.object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	host.install_url_members(mut prototype, mut constructor)
	host.install_object_urls(mut constructor)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('URL'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	location := domurl.DOMURL.construct_impl(host.document.url.serialize(), none)!
	host.location_url = location
	global.define_direct_property(libjs.PropertyName.from_str('location'), libjs.Value.from_object(host.wrap_location(location)), libjs.attribute_enumerable)
}

// Location is the document's live navigation projection, separate from URL's
// prototype and mutable standalone native records.
fn (mut host Host) wrap_location(url &domurl.DOMURL) &libjs.Object {
	mut object := libjs.Object.create(host.realm, host.realm.object_prototype)
	object.class_name = 'Location'
	for name in ['href', 'origin', 'protocol', 'host', 'hostname', 'port', 'pathname', 'search', 'hash'] {
		host.accessor(mut object, name, fn [host, url, name, object] (mut vm libjs.VM) !libjs.Value {
			host.require_open(mut vm)!
			if !vm.this_value().is_object() || voidptr(vm.this_value().as_object()) != voidptr(object) {
				return vm.throw_error(.type_error, 'Location property called on incompatible receiver')
			}
			host.refresh_location()!
			return libjs.Value.from_string(vm.create_string_from_str(url_component(url, name)))
		}, unsafe { nil })
	}
	host.method(mut object, 'toString', 0, fn [host, object] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		if !vm.this_value().is_object() || voidptr(vm.this_value().as_object()) != voidptr(object) {
			return vm.throw_error(.type_error, 'Location method called on incompatible receiver')
		}
		return libjs.Value.from_string(vm.create_string_from_str(host.document.url.serialize()))
	})
	params := url.search_params()
	object.define_direct_property(libjs.PropertyName.from_str('searchParams'), host.wrap_query(params, none), libjs.attribute_enumerable)
	return object
}

// Same-document history and native traversal update Document's actual URL.
fn (host &Host) refresh_location() ! {
	if host.location_url == unsafe { nil } { return }
	text := host.document.url.serialize()
	if host.location_url.href() == text { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut url := host.location_url
	url.set_href(text)!
}
