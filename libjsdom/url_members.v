// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import domurl
import libjs
import platform

fn (mut host Host) install_url_members(mut prototype libjs.Object, mut constructor libjs.Object) {
	owner := &host
	for name in ['canParse', 'parse'] {
		host.method_attributes(mut constructor, name, 1, fn [owner, name] (mut vm libjs.VM) !libjs.Value {
			owner.require_open(mut vm)!
			input, base := url_arguments(mut vm)!
			if name == 'canParse' { return libjs.Value.from_bool(domurl.DOMURL.can_parse(input, base)) }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			url := domurl.DOMURL.parse_for_bindings(input, base) or { return libjs.js_null() }
			mut host := unsafe { &Host(owner) }
			return libjs.Value.from_object(host.wrap_url(url, host.url_prototype))
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	for name in ['href', 'origin', 'protocol', 'username', 'password', 'host', 'hostname', 'port', 'pathname', 'search', 'hash'] {
		host.accessor(mut prototype, name, fn [owner, name] (mut vm libjs.VM) !libjs.Value {
			url := owner.url_receiver(mut vm)!
			return libjs.Value.from_string(vm.create_string_from_str(url_component(url, name)))
		}, if name == 'origin' { unsafe { nil } } else { fn [owner, name] (mut vm libjs.VM) !libjs.Value {
			url := owner.url_receiver(mut vm)!
			value := query_usv(mut vm, vm.argument(0))!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut native := unsafe { &domurl.DOMURL(url) }
			match name {
				'href' { native.set_href(value) or { return vm.throw_error(.type_error, err.msg()) } }
				'protocol' { native.set_protocol(value) }
				'username' { native.set_username(value) }
				'password' { native.set_password(value) }
				'host' { native.set_host(value) }
				'hostname' { native.set_hostname(value) }
				'port' { native.set_port(value) }
				'pathname' { native.set_pathname(value) }
				'search' { native.set_search(value) }
				'hash' { native.set_hash(value) }
				else {}
			}
			return libjs.js_undefined()
		} })
	}
	host.accessor(mut prototype, 'searchParams', fn [owner] (mut vm libjs.VM) !libjs.Value {
		url := owner.url_receiver(mut vm)!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut host := unsafe { &Host(owner) }
		return host.wrap_query(url.search_params(), none)
	}, unsafe { nil })
	for name in ['toString', 'toJSON'] {
		host.method_attributes(mut prototype, name, 0, fn [owner] (mut vm libjs.VM) !libjs.Value {
			url := owner.url_receiver(mut vm)!
			return libjs.Value.from_string(vm.create_string_from_str(url.href()))
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
}

fn (host &Host) url_receiver(mut vm libjs.VM) !&domurl.DOMURL {
	host.require_open(mut vm)!
	if vm.this_value().is_object() { if url := host.urls[voidptr(vm.this_value().as_object())] { return url } }
	return vm.throw_error(.type_error, 'URL member called on incompatible receiver')
}

fn (mut host Host) wrap_url(url &domurl.DOMURL, prototype &libjs.Object) &libjs.Object {
	if object := host.url_wrappers[voidptr(url)] { return object }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := libjs.Object.create(host.realm, prototype)
	object.class_name = 'URL'
	host.urls[voidptr(object)] = url
	host.url_wrappers[voidptr(url)] = object
	return object
}

fn url_component(url &domurl.DOMURL, name string) string {
	return match name {
		'href' { url.href() }
		'origin' { url.origin() }
		'protocol' { url.protocol() }
		'username' { url.username() }
		'password' { url.password() }
		'host' { url.host() }
		'hostname' { url.hostname() }
		'port' { url.port() }
		'pathname' { url.pathname() }
		'search' { url.search() }
		else { url.hash() }
	}
}
