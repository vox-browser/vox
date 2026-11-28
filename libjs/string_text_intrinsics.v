// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Expose translated UTF-16 algorithms in the actual String prototype graph.
// Intl-dependent locale operations keep their explicit untranslated boundary.
fn initialize_string_text_methods(mut vm VM, realm &Realm, mut prototype Object) {
	for name, callback in {
		'at': NativeFunctionPointer(string_prototype_at)
		'codePointAt': string_prototype_code_point_at
		'concat': string_prototype_concat
		'trim': string_prototype_trim
		'trimStart': string_prototype_trim_start
		'trimEnd': string_prototype_trim_end
		'repeat': string_prototype_repeat
		'padStart': string_prototype_pad_start
		'padEnd': string_prototype_pad_end
		'normalize': string_prototype_normalize
		'isWellFormed': string_prototype_is_well_formed
		'toWellFormed': string_prototype_to_well_formed
	} {
		length := if name in ['trim','trimStart','trimEnd','normalize','isWellFormed','toWellFormed'] { 0 } else { 1 }
		install_intrinsic_method(mut vm, realm, mut prototype, name, length, callback)
	}
	// Legacy aliases share the same native function, including its name.
	for alias, original in {'trimLeft':'trimStart','trimRight':'trimEnd'} {
		value := prototype.get(mut vm, PropertyName.from_str(original)) or { panic('Missing String trimming intrinsic') }
		prototype.define_direct_property(PropertyName.from_str(alias), value, attribute_writable | attribute_configurable)
	}
}
