module libjs

fn test_production_from_property_descriptor_retains_present_fields_and_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	if !from_property_descriptor(mut vm, none, prototype).is_undefined() {
		panic('an absent PropertyDescriptor must produce undefined')
	}
	empty := from_property_descriptor(mut vm, PropertyDescriptor{}, prototype).as_object()
	if empty.own_property_keys().len != 0 || voidptr(empty.prototype?) != voidptr(prototype) {
		panic('an empty PropertyDescriptor must produce a fresh ordinary object')
	}
	data := from_property_descriptor(mut vm, PropertyDescriptor{
		value: js_undefined()
		writable: false
		enumerable: false
		configurable: true
	}, prototype).as_object()
	if data.own_property_keys().map(it.str()) != ['value', 'writable', 'enumerable', 'configurable'] {
		panic('FromPropertyDescriptor omitted fields or changed source property order')
	}
	getter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return Value.from_i32(42)
	}, 0, PropertyName.from_str('get'), none)
	accessor := from_property_descriptor(mut vm, PropertyDescriptor{
		getter: Value.from_object(getter.object)
		setter: js_undefined()
		enumerable: true
		configurable: false
	}, prototype).as_object()
	if accessor.own_property_keys().map(it.str()) != ['get', 'set', 'enumerable', 'configurable'] {
		panic('FromPropertyDescriptor omitted accessor fields')
	}
	for object in [data, accessor] {
		for key in object.own_property_keys() {
			descriptor := object.internal_get_own_property(key)?
			if !descriptor.writable? || !descriptor.enumerable? || !descriptor.configurable? {
				panic('FromPropertyDescriptor did not use CreateDataPropertyOrThrow')
			}
		}
	}
	data_descriptor := to_property_descriptor(mut vm, Value.from_object(data))!
	if !data_descriptor.value?.is_undefined() || data_descriptor.writable? || data_descriptor.enumerable? || !data_descriptor.configurable? {
		panic('FromPropertyDescriptor changed explicit false or undefined field values')
	}
	accessor_descriptor := to_property_descriptor(mut vm, Value.from_object(accessor))!
	if voidptr(accessor_descriptor.getter?.as_object()) != voidptr(getter.object) || !accessor_descriptor.setter?.is_undefined() || !accessor_descriptor.enumerable? || accessor_descriptor.configurable? {
		panic('FromPropertyDescriptor changed accessor identity or field values')
	}
}
