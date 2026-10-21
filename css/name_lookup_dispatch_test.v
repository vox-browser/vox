module css

fn test_keyword_lookup_preserves_every_keyword_and_ascii_case() {
	for index in int(Keyword.invalid) + 1 .. int(Keyword.zoom_out) + 1 {
		keyword := unsafe { Keyword(index) }
		name := string_from_keyword(keyword)
		assert keyword_from_string(name)? == keyword
		assert keyword_from_string(name.to_upper())? == keyword
		// An otherwise matching bucket must still check the complete spelling.
		assert keyword_from_string(name + '!') == none
		assert keyword_from_string(name[..name.len - 1] + '!') == none
	}
}

fn test_property_lookup_preserves_all_longhands_shorthands_and_aliases() {
	for index in int(PropertyID.accent_color) .. int(PropertyID.container) + 1 {
		property := unsafe { PropertyID(index) }
		name := string_from_property_id(property)
		assert property_id_from_canonical_name(name)? == property
		assert property_id_from_string(name.to_upper())? == property
		assert property_id_from_canonical_name(name + '!') == none
		assert property_id_from_canonical_name(name[..name.len - 1] + '!') == none
	}
	assert property_id_from_string('-WEBKIT-BOX-ALIGN')? == .align_items
	assert property_id_from_string('-MOZ-APPEARANCE')? == .appearance
	assert property_id_from_string('word-wrap')? == .overflow_wrap
	assert property_id_from_string('-webkit-text-fill-color')? == .webkit_text_fill_color
}

fn test_name_lookup_rejects_empty_non_ascii_and_embedded_null_spelling() {
	for name in ['', ' ', '\t', 'nörmal', 'NÖRMAL', 'width\x00', 'normal\x00',
		'正常', '😀', 'normal ', ' width', 'INVALID-NAME', 'font_siz!'] {
		assert keyword_from_string(name) == none
		assert property_id_from_canonical_name(name) == none
	}
	assert property_id_from_canonical_name('WIDTH') == none
	assert keyword_from_string('NoRmAl')? == .normal
	assert property_id_from_string('--custom-name') == none
}

fn test_name_lookup_keeps_the_first_enum_value_distinct_from_an_absent_name() {
	assert int(PropertyID.accent_color) == 0
	assert property_id_from_canonical_name('accent-color')? == .accent_color
	assert property_id_from_canonical_name('accent-coloz') == none
	assert keyword_from_string('-infinity')? == .negative_infinity
	assert keyword_from_string('-infinitz') == none
	assert keyword_from_string('invalid') == none
	assert keyword_from_string('') == none
	assert property_id_from_canonical_name('') == none
}

fn test_name_lookup_checks_every_byte_inside_an_otherwise_matching_bucket() {
	for index in int(Keyword.invalid) + 1 .. int(Keyword.zoom_out) + 1 {
		name := string_from_keyword(unsafe { Keyword(index) })
		for offset in 1 .. name.len {
			for replacement in [u8(0), u8(0x7f)] {
				mut bytes := name.bytes()
				bytes[offset] = replacement
				assert keyword_from_string(bytes.bytestr()) == none
			}
		}
	}
	for index in int(PropertyID.accent_color) .. int(PropertyID.container) + 1 {
		name := string_from_property_id(unsafe { PropertyID(index) })
		for offset in 1 .. name.len {
			for replacement in [u8(0), u8(0x7f)] {
				mut bytes := name.bytes()
				bytes[offset] = replacement
				assert property_id_from_canonical_name(bytes.bytestr()) == none
				assert property_id_from_string(bytes.bytestr()) == none
			}
		}
	}
}
