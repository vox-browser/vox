module libjs

// AbstractOperations.cpp::get_options_object (GetOptionsObject).
pub fn get_options_object(mut vm VM, options Value) !&Object {
	if options.is_undefined() {
		return Object.create(vm.realm(), none)
	}
	if options.is_object() {
		return options.as_object()
	}
	return vm.throw_error_type(.type_error, .not_an_object, 'Options')
}
