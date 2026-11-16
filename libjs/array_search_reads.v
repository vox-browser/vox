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
	index := object.find_own_property(key)
	if index < 0 { return none }
	value := object.properties[index].value
	if value.is_accessor() { return none }
	return value
}
