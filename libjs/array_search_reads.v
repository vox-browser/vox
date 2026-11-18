module libjs

$if test {
	__global array_search_reads_disabled bool
	pub fn set_array_search_reads_for_testing(enabled bool) {
		array_search_reads_disabled = !enabled
	}
}

// HasProperty followed by Get needs one live lookup for an ordinary own data
// cell. Absence, accessors and exotic providers retain the observable protocol.
fn (object &Object) own_array_search_value(key PropertyName) ?Value {
	$if test { if array_search_reads_disabled { return none } }
	if object.proxy_object != none || object.host_properties != none
		|| object.legacy_platform_object != none || object.typed_array != none
		|| object.string_object != none || object.arguments_object != none { return none }
	// Dense elements are commonly stored at their numeric position. Verify
	// the live key so holes, extra properties and writes in a callback
	// cannot change which slot is read.
	if key.is_number() && u64(key.number) < u64(object.properties.len) {
		property := &object.properties[int(key.number)]
		if property.key.is_number() && property.key.number == key.number {
			if property.value.is_accessor() { return none }
			return property.value
		}
	}
	index := object.find_own_property(key)
	if index < 0 { return none }
	value := object.properties[index].value
	if value.is_accessor() { return none }
	return value
}

fn (object &Object) read_present_array_index(mut vm VM, key PropertyName) !(Value, bool) {
	if value := object.own_array_search_value(key) {
		// HasProperty charges the first holder even for a direct data hit.
		vm.consume_execution_budget()!
		if mut tier := vm.native_tier { if tier.diagnostics { tier.activity.direct_array_search_reads++ } }
		return value, true
	}
	if !object.has_property_checked(mut vm, key)! { return js_undefined(), false }
	return object.get(mut vm, key)!, true
}
