// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn initialize_proxy_intrinsics(mut vm VM, mut realm Realm) {
	mut constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
		fn (mut vm VM) !Value { return vm.throw_error(.type_error, 'Proxy constructor requires new') },
		fn (mut vm VM, new_target &Object) !&Object { return proxy_create(mut vm, vm.argument(0), vm.argument(1)) },
		2, PropertyName.from_str('Proxy')).object
	realm.proxy_constructor = constructor
	install_intrinsic_method(mut vm, realm, mut constructor, 'revocable', 2, proxy_revocable)
}

fn proxy_create(mut vm VM, target Value, handler Value) !&Object {
	if !target.is_object() { return vm.throw_error(.type_error, 'Proxy target must be an object') }
	if !handler.is_object() { return vm.throw_error(.type_error, 'Proxy handler must be an object') }
	return ProxyObject.create(vm.realm(), target.as_object(), handler.as_object()).object
}

@[heap]
struct ProxyRevoker {
mut:
	proxy ?&ProxyObject
}

fn proxy_revocable(mut vm VM) !Value {
	proxy := proxy_create(mut vm, vm.argument(0), vm.argument(1))!
	mut slot := &ProxyRevoker{proxy: proxy.proxy_object}
	revoker := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
		fn [mut slot] (mut vm VM) !Value {
			if mut object := slot.proxy {
				slot.proxy = none
				object.revoke()
			}
			return js_undefined()
		}, 0, PropertyName.from_str(''), none)
	mut result := Object.create(vm.realm(), vm.realm().object_prototype)
	result.create_data_property_or_throw(mut vm, PropertyName.from_str('proxy'), Value.from_object(proxy))!
	result.create_data_property_or_throw(mut vm, PropertyName.from_str('revoke'), Value.from_object(revoker.object))!
	return Value.from_object(result)
}
