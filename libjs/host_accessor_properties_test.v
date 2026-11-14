module libjs

@[heap]
struct HostAccessorCounter {
mut:
	calls int
}

struct HostAccessorProperties {
	getter &Object
}

fn (properties &HostAccessorProperties) own_property_keys() []PropertyName {
	return [PropertyName.from_str('live')]
}

fn (properties &HostAccessorProperties) get_own_property(key PropertyName) ?PropertyDescriptor {
	if !key.equals(PropertyName.from_str('live')) { return none }
	return PropertyDescriptor{getter:Value.from_object(properties.getter),setter:js_undefined(),enumerable:true,configurable:false}
}

fn test_host_accessor_descriptors_call_live_getters_without_an_owned_accessor_cell() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for storage in 0 .. 3 {
		mut object := Object.create(vm.realm(),none)
		key := PropertyName.from_str('live')
		if storage==1 { object.define_direct_property(key,Value.from_i32(1000),attribute_configurable) }
		if storage==2 {
			old := NativeFunction.create(mut vm,vm.realm(),vm.realm().function_prototype,
				fn (mut vm VM) !Value { return Value.from_i32(1000) },0,key,none)
			object.define_direct_cached_accessor(key,old.object,none,attribute_configurable)
			assert object.get(mut vm,key)!.number==1000
		}
		state := &HostAccessorCounter{}
		getter := NativeFunction.create(mut vm,vm.realm(),vm.realm().function_prototype,
			fn [state] (mut vm VM) !Value {
				mut counter := unsafe { &HostAccessorCounter(state) };counter.calls++
				return Value.from_f64(f64(counter.calls))
			},0,key,none)
		object.host_properties=&HostAccessorProperties{getter:getter.object}
		assert object.get(mut vm,key)!.number==1
		assert object.get(mut vm,key)!.number==2
		assert state.calls==2
		assert !object.internal_set(mut vm,key,Value.from_i32(9),Value.from_object(object))!
	}
}
