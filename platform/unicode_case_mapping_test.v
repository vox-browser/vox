module platform

fn test_case_mapping_preserves_context_and_length_changing_edits() {
	mapped := transform_text_case_with_edits([u16(0xdf), 0x03a3, 0x0391], 'de', .uppercase)
	assert mapped.units == [u16(`S`), u16(`S`), 0x03a3, 0x0391]
	assert mapped.edits == [TextMappingEdit{0, 1, 0, 2}]
	assert rendered_text_offset_for_source_offset(mapped.edits, 0, 1, .end) == 2
	assert source_offset_for_rendered_text_offset(mapped.edits, 0, 1, .start) == 0
	assert source_offset_for_rendered_text_offset(mapped.edits, 0, 1, .end) == 1
	lower := transform_text_case_with_edits([u16(0x039f), 0x03a3], 'el', .lowercase)
	assert lower.units == [u16(0x03bf), 0x03c2]
	assert lower.edits.len == 0
	empty := transform_text_case_with_edits([]u16{}, '', .uppercase)
	assert empty.units.len == 0
	assert empty.edits.len == 0
}

fn test_text_mapping_zero_width_edit_and_absolute_source_base() {
	// rendered_text.rs tests preserve the boundary distinction at deletions.
	edits := [TextMappingEdit{3, 1, 0, 0}]
	assert source_offset_for_rendered_text_offset(edits, 3, 0, .start) == 4
	assert source_offset_for_rendered_text_offset(edits, 3, 0, .end) == 3
	assert rendered_text_offset_for_source_offset(edits, 3, 4, .end) == 0
}
