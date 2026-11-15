// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import encoding
import fetch
import fileapi
import libjs
import platform
import webidl

fn (mut host Host) wrap_request(native &fetch.RequestObject, parent ?&libjs.Object) libjs.Value {
	if wrapper := host.fetch_wrappers[voidptr(native)] { return libjs.Value.from_object(wrapper) }
	mut object := libjs.Object.create(host.realm, parent or { host.request_prototype })
	object.class_name = 'Request'
	host.fetch_requests[voidptr(object)] = native
	host.fetch_wrappers[voidptr(native)] = object
	return libjs.Value.from_object(object)
}

fn (mut host Host) wrap_response(native &fetch.ResponseObject, parent ?&libjs.Object) libjs.Value {
	if wrapper := host.fetch_wrappers[voidptr(native)] { return libjs.Value.from_object(wrapper) }
	mut object := libjs.Object.create(host.realm, parent or { host.response_prototype })
	object.class_name = 'Response'
	host.fetch_responses[voidptr(object)] = native
	host.fetch_wrappers[voidptr(native)] = object
	return libjs.Value.from_object(object)
}

fn (host &Host) request_receiver(mut vm libjs.VM) !&fetch.RequestObject {
	host.require_open(mut vm)!
	if vm.this_value().is_object() { if native := host.fetch_requests[voidptr(vm.this_value().as_object())] { return native } }
	return vm.throw_error(.type_error, 'Request method called on incompatible receiver')
}

fn (host &Host) response_receiver(mut vm libjs.VM) !&fetch.ResponseObject {
	host.require_open(mut vm)!
	if vm.this_value().is_object() { if native := host.fetch_responses[voidptr(vm.this_value().as_object())] { return native } }
	return vm.throw_error(.type_error, 'Response method called on incompatible receiver')
}

fn (mut host Host) install_fetch_objects() ! {
	mut vm := host.vm
	mut request := libjs.Object.create(host.realm, host.realm.object_prototype)
	mut response := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.request_prototype, host.response_prototype = request, response
	host.fetch_json_parse = (host.realm.json_object or { return error('Missing JSON intrinsic') }).get(mut vm, libjs.PropertyName.from_str('parse'))!
	for is_request in [true, false] {
		name := if is_request { 'Request' } else { 'Response' }
		mut prototype := if is_request { request } else { response }
		construct := fn [host, is_request] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
			host.require_open(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			if is_request {
				if vm.argument_count() < 1 { return vm.throw_error(.type_error, 'Request requires an input') }
				native, parent := host.fetch_request(mut vm, vm.argument(0), vm.argument(1), new_target) or { return libjs.throw_completion(host.fetch_error_value(mut vm, err)) }
				return owner.wrap_request(native, parent).as_object()
			}
			converted_body := host.fetch_body_init(mut vm, vm.argument(0))!
			init := fetch_response_init(mut vm, vm.argument(1))!
			parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
			body := converted_body.materialize(mut vm)!.value
			native := fetch.ResponseObject.construct(body, init) or { return libjs.throw_completion(host.fetch_error_value(mut vm, err)) }
			return owner.wrap_response(native, if parent.is_object() { ?&libjs.Object(parent.as_object()) } else { none }).as_object()
		}
		host.closures << voidptr(construct)
		constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
			fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Fetch interface constructor requires new') }, construct, if is_request { 1 } else { 0 }, libjs.PropertyName.from_str(name)).object
		mut function := constructor
		function.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
		prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
		prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str(name)), libjs.attribute_configurable)
		mut global := host.realm.global_object_record()
		global.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
		host.method_attributes(mut prototype, 'clone', 0, fn [host, is_request] (mut vm libjs.VM) !libjs.Value {
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			if is_request { return owner.wrap_request(host.request_receiver(mut vm)!.clone() or { return libjs.throw_completion(host.fetch_error_value(mut vm, err)) }, none) }
			return owner.wrap_response(host.response_receiver(mut vm)!.clone() or { return libjs.throw_completion(host.fetch_error_value(mut vm, err)) }, none)
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
		for method in ['text', 'json', 'arrayBuffer', 'bytes', 'blob'] {
			host.method_attributes(mut prototype, method, 0, fn [host, is_request, method] (mut vm libjs.VM) !libjs.Value {
				host.require_open(mut vm)!
				capability := libjs.new_promise_capability(mut vm, libjs.Value.from_object(host.realm.promise_constructor_record()))!
				mut owner := unsafe { &Host(host) }
				body := if is_request {
					native := host.request_receiver(mut vm) or { owner.settle_fetch_error(capability, err); return capability.promise }
					native.body_mixin()
				} else {
					native := host.response_receiver(mut vm) or { owner.settle_fetch_error(capability, err); return capability.promise }
					native.body_mixin()
				}
				owner.consume_fetch_body(body, method, capability)
				return capability.promise
			}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
		}
	}
	for name in ['url','method','headers','destination','referrer','referrerPolicy','mode','credentials','cache','redirect','integrity','keepalive','isReloadNavigation','isHistoryNavigation','duplex','bodyUsed'] {
		host.accessor(mut request, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.request_receiver(mut vm)!
			mut owner := unsafe { &Host(host) }
			if name == 'headers' { return owner.wrap_headers(native.headers(), none) }
			if name == 'bodyUsed' { return libjs.Value.from_bool(native.body_mixin().body_used()) }
			if name == 'keepalive' { return libjs.Value.from_bool(native.keepalive()) }
			if name == 'isReloadNavigation' { return libjs.Value.from_bool(native.is_reload_navigation()) }
			if name == 'isHistoryNavigation' { return libjs.Value.from_bool(native.is_history_navigation()) }
			text := match name {
				'url' { native.url() } 'method' { native.method() } 'referrer' { native.referrer() }
				'referrerPolicy' { native.referrer_policy() } 'integrity' { native.integrity() }
				'destination' { if destination := native.destination() { destination.str().replace('_','-') } else { '' } }
				'mode' { native.mode().str().replace('_','-') } 'credentials' { native.credentials().str().replace('_','-') }
				'cache' { native.cache().str().replace('_','-') } 'redirect' { native.redirect_mode().str() } else { 'half' }
			}
			return libjs.Value.from_string(vm.create_string_from_str(text))
		}, unsafe { nil })
	}
	for name in ['url','type','headers','redirected','status','statusText','ok','bodyUsed'] {
		host.accessor(mut response, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.response_receiver(mut vm)!
			mut owner := unsafe { &Host(host) }
			return match name {
				'headers' { owner.wrap_headers(native.headers(), none) }
				'bodyUsed' { libjs.Value.from_bool(native.body_mixin().body_used()) }
				'ok' { libjs.Value.from_bool(native.ok()) }
				'redirected' { libjs.Value.from_bool(native.redirected()) }
				'status' { libjs.Value.from_i32(i32(native.status())) }
				'statusText' { headers_byte_value(mut vm, native.status_text()) }
				'url' { libjs.Value.from_string(vm.create_string_from_str(native.url())) }
				else { libjs.Value.from_string(vm.create_string_from_str(native.type_().str().replace('opaque_redirect','opaqueredirect'))) }
			}
		}, unsafe { nil })
	}
}

fn (mut host Host) consume_fetch_body(body fetch.BodyMixin, method string, capability &libjs.JSPromiseCapability) {
	if body.is_unusable() { host.settle_fetch_error(capability, error('TypeError: Body is unusable')); return }
	mut stream := if native := body.body { native.stream() } else { fetch.Body.from_bytes([], .bytes).stream() }
	mut reader := stream.get_default_reader() or { host.settle_fetch_error(capability, err); return }
	owner := &host
	content_type := if mime := body.mime_type { mime.serialized() } else { '' }
	reader.read_all_bytes_with_steps(fn [owner, method, capability, content_type] (bytes []u8) {
		mut host := unsafe { &Host(owner) }
		if host.closed { return }
		host.invoke_fetch_callback(fn [owner, method, capability, content_type, bytes] (mut vm libjs.VM) !libjs.Value {
			mut host := unsafe { &Host(owner) }
			value := host.fetch_body_result(mut vm, method, bytes, content_type) or {
				return libjs.call(mut vm, capability.reject, libjs.js_undefined(), [host.fetch_error_value(mut vm, err)])
			}
			return libjs.call(mut vm, capability.resolve, libjs.js_undefined(), [value])
		})
	}, fn [owner, capability] (reason webidl.Value) {
		mut host := unsafe { &Host(owner) }
		if !host.closed { host.settle_fetch_error(capability, webidl.ValueException{value: reason}) }
	})
}

fn (mut host Host) fetch_body_result(mut vm libjs.VM, method string, bytes []u8, content_type string) !libjs.Value {
	charge_buffer_source_work(mut vm, u64(bytes.len))!
	if method == 'bytes' { return host.uint8_array_from_bytes(bytes) }
	if method == 'blob' { return host.wrap_blob(fileapi.Blob.create(bytes, content_type), none) }
	if method == 'arrayBuffer' {
		prototype := host.realm.array_buffer_prototype or { return error('Missing ArrayBuffer prototype') }
		return libjs.Value.from_object(libjs.ArrayBufferObject.create_from_bytes(host.realm, bytes, false, prototype).object)
	}
	text := encoding.TextDecoder.create().decode(bytes, encoding.TextDecodeOptions{})!
	value := libjs.Value.from_string(vm.create_string_from_str(text))
	return if method == 'json' { libjs.call(mut vm, host.fetch_json_parse, libjs.js_undefined(), [value])! } else { value }
}
