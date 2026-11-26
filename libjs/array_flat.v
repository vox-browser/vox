// SPDX-License-Identifier: BSD-2-Clause
module libjs

// ArrayPrototype.cpp::flat shares FlattenIntoArray with flatMap, without a
// mapper. Depth conversion precedes species creation and retains Infinity.
fn array_prototype_flat(mut vm VM) !Value {
	object, length := array_receiver(mut vm)!
	mut depth := f64(1)
	if !vm.argument(0).is_undefined() {
		converted := vm.argument(0).to_integer_or_infinity(mut vm)!
		depth = if converted < 0 { f64(0) } else { converted }
	}
	mut result := array_species_create(mut vm, object, 0)!
	flatten_into_array(mut vm, mut result, object, length, 0, depth, js_undefined(), js_undefined())!
	return Value.from_object(result)
}
