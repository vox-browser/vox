module vunicode

fn test_unicode_categories_scripts_and_supplementary_properties() {
	assert version == '17.0.0'
	assert category(0xe000) == 17 // Private use is not punctuation.
	assert property_named(0x11db0, 'ID_Start') // Unicode 17 Tolong Siki.
	assert property_named(0x200d, 'Default_Ignorable_Code_Point')
	assert !property_named(0x1f600, 'ID_Start')
	assert has_script(0x30fc, script_id('Hira')?)
	assert decode_utf16(encode_utf16([u32(0xd800), 0x10000, 0, 0xdfff])) == [
		u32(0xd800),
		0x10000,
		0,
		0xdfff,
	]
}

fn test_contextual_case_and_length_changing_utf16_edits() {
	for row in [['ΟΣ', '', 'ος'], ['I\u0307', 'tr', 'i'], ['I\u0301', 'lt', 'i\u0307\u0301'],
		['İ', '', 'i\u0307']] {
		mapped := map_case(encode_utf16(row[0].runes().map(u32(it))), row[1], .lowercase)
		assert decode_utf16(mapped.units).map(rune(it)).string() == row[2]
	}
	mapped := map_case([u16(0xd801), 0xdc28, 0xdf], '', .uppercase)
	assert mapped.units == [u16(0xd801), 0xdc00, 0x53, 0x53]
	assert mapped.edits == [CaseEdit{2, 1, 2, 2}]
}

fn test_greek_uppercase_language_tailoring_and_dutch_titlecase() {
	for row in [['Ελληνικά', 'ΕΛΛΗΝΙΚΑ'], ['Μαΐου', 'ΜΑΪΟΥ'],
		['άι', 'ΑΪ'], ['ή', 'Ή'], ['ήταν', 'ΗΤΑΝ'], ['α\u0301ι', 'ΑΙ\u0308']] {
		actual := map_case(encode_utf16(row[0].runes().map(u32(it))), 'el', .uppercase)
		assert decode_utf16(actual.units).map(rune(it)).string() == row[1]
	}
	assert decode_utf16(map_case(encode_utf16('ijsselmeer'.runes().map(u32(it))), 'nl', .titlecase).units).map(rune(it)).string() == 'IJsselmeer'
	assert bidi_levels([u32(0x5d0), 0xa, 0x31], false) == [u8(1), 0, 0]
}
