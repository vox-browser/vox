module libjs

// OrdinarySet for a key the receiver itself lacks walks the prototype chain,
// then re-reads the receiver's own descriptor, and CreateDataProperty and
// define_direct_property look the key up twice more. Each of those misses
// scanned every own property, so a constructor adding k fields cost O(k^2)
// several times over. When the receiver is the ordinary object that just
// missed and every object on its chain is plain ordinary storage, one walk
// decides the result: a writable data property or no property allows a new
// own data property, a read-only one rejects the write, and an accessor or an
// exotic holder keeps the generic recursion (which calls setters and proxy
// traps in order).

const absent_own_set_unhandled = -1
const absent_own_set_rejected = 0
const absent_own_set_added = 1

$if test {
	__global absent_property_set_disabled bool
	pub fn set_absent_property_set_for_testing(enabled bool) {
		absent_property_set_disabled = !enabled
	}
}

@[inline]
fn (object &Object) is_plain_ordinary_storage() bool {
	return object.proxy_object == none && object.legacy_platform_object == none
		&& object.typed_array == none && object.string_object == none
		&& object.array_object == none && object.arguments_object == none
		&& object.host_properties == none
}

// The caller has checked that `object` is plain ordinary storage, is the
// receiver, and has no own `key`.
fn (mut object Object) set_absent_own_data_property(key PropertyName, value Value) int {
	$if test {
		if absent_property_set_disabled { return absent_own_set_unhandled }
	}
	mut holder := object.prototype
	for {
		current := holder or { break }
		if !current.is_plain_ordinary_storage() { return absent_own_set_unhandled }
		index := current.find_own_property(key)
		if index >= 0 {
			property := current.properties[index]
			if property.value.is_accessor() { return absent_own_set_unhandled }
			if !property.writable { return absent_own_set_rejected }
			break
		}
		holder = current.prototype
	}
	if !object.extensible { return absent_own_set_rejected }
	object.properties << OwnProperty{key: key, value: value, writable: true, enumerable: true,
		configurable: true}
	return absent_own_set_added
}
