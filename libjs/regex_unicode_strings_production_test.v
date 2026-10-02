module libjs

fn test_production_regex_string_properties_retain_icu_units_and_scalar_boundaries() {
	keycaps := regex_get_string_property_data('Emoji_Keycap_Sequence')
	if keycaps.len != 49 || keycaps[0] != 12 || keycaps[1..5] != [u32(3), 0x23, 0xfe0f, 0x20e3]
		|| keycaps[45..49] != [u32(3), 0x39, 0xfe0f, 0x20e3] {
		panic('production ICU extraction lost the actual keycap string units')
	}
	mut output := []u32{len: 48, init: 0xffffffff}
	needed := regex_get_string_property_data_into('Emoji_Keycap_Sequence', mut output)
	if needed != 49 || !output.all(it == 0xffffffff) {
		panic('Unicode string-property short-buffer query changed its output')
	}
	flags := regex_get_string_property_data('RGI_Emoji_Flag_Sequence')
	if flags.len <= 1 || flags[0] == 0 { panic('ICU flag string list was lost') }
	for offset := 1; offset < flags.len; offset += 3 {
		if flags[offset] != 2 || flags[offset + 1] < 0x1f1e6 || flags[offset + 1] > 0x1f1ff
			|| flags[offset + 2] < 0x1f1e6 || flags[offset + 2] > 0x1f1ff {
			panic('ICU extraction did not preserve supplementary scalar pairs')
		}
	}
}
