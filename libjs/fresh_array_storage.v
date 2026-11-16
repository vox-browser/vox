module libjs

$if test {
	__global fresh_array_storage_disabled bool
	__global fresh_array_storage_diagnostic bool
	__global fresh_arrays_initialized_for_test u64
	pub fn set_fresh_array_storage_for_testing(enabled bool) { fresh_array_storage_disabled = !enabled }
	pub fn diagnose_fresh_array_storage_for_testing(enabled bool) u64 {
		previous := fresh_arrays_initialized_for_test
		fresh_arrays_initialized_for_test = 0
		fresh_array_storage_diagnostic = enabled
		return previous
	}
}
fn use_fresh_array_storage() bool {
	$if test { if fresh_array_storage_disabled { return false } }
	return true
}
fn record_fresh_array_storage() {
	$if test { if fresh_array_storage_diagnostic { fresh_arrays_initialized_for_test++ } }
}

// String.split has not published this fresh array and runs no author code while
// appending pieces. Ordinary data creation never consults inherited setters.
fn (mut array ArrayObject) append_split_value(mut vm VM, value Value) ! {
	if use_fresh_array_storage() && array.length < 0xffffffff {
		mut object := array.object
		object.properties << OwnProperty{key: PropertyName.from_number(array.length), value: value,
			writable: true, enumerable: true, configurable: true}
		array.length++
		record_fresh_array_storage()
		return
	}
	mut object := array.object
	defined := object.create_data_property_or_throw(mut vm, PropertyName.from_number(array.length), value)!
	assert defined
}
