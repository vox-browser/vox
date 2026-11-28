// SPDX-License-Identifier: BSD-2-Clause
module libjs

// ClassStaticBlockDefinitionEvaluation retains an unobservable strict function
// with class this/HomeObject. Static fields and blocks share the ordered native
// initialization list; a block creates no property on the constructor.
fn record_class_static_block(mut vm VM, target Value, initializer Value) ! {
	mut function := target.as_function()
	if mut function is BaseClassFunction {
		if !initializer.is_function() { return vm.throw_error(.internal_error, 'Static block requires an initializer function') }
		mut body := initializer.as_object()
		body.home_object = function.object
		function.static_fields << ClassFieldDefinition{key: PropertyName.from_str(''), initializer: initializer, is_static_block: true}
		return
	}
	return vm.throw_error(.internal_error, 'Static block requires a class constructor')
}
