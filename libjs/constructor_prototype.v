module libjs

// Runtime/AbstractOperations.cpp::GetFunctionRealm. Transparent Proxy forwarding
// validates revocation without invoking any handler trap.
pub fn get_function_realm(mut vm VM, function &Object) !&Realm {
	assert function.callable != none
	if realm := Value.from_object(function).as_function().realm() { return realm }
	if proxy := function.proxy_object {
		vm.enter_proxy_operation()!
		defer { vm.proxy_operation_depth-- }
		return get_function_realm(mut vm, proxy.operands(mut vm)!.target)
	}
	if bound := function.bound_function { return get_function_realm(mut vm, bound.bound_target_function) }
	return vm.realm()
}

// The upstream pointer to an Intrinsics member becomes a realm callback. This
// keeps fallback selection in the constructor's realm, after the observable Get.
pub type IntrinsicPrototypeGetter = fn (realm &Realm) &Object

// Runtime/AbstractOperations.cpp::GetPrototypeFromConstructor.
pub fn get_prototype_from_constructor(mut vm VM, constructor &Object, intrinsic_default_prototype IntrinsicPrototypeGetter) !&Object {
	assert constructor.callable != none && intrinsic_default_prototype != unsafe { nil }
	prototype := constructor.get(mut vm, PropertyName.from_str('prototype'))!
	if prototype.is_object() { return prototype.as_object() }
	realm := get_function_realm(mut vm, constructor)!
	return intrinsic_default_prototype(realm)
}
