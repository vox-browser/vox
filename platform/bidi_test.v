module platform

fn test_bidi_fragment_levels_preserve_numeric_and_split_ltr_order() {
	// Two Persian numbers, a plus, a space, then an Arabic letter. W6/N1
	// resolve the trailing plus to the paragraph's RTL level.
	levels := bidi_paragraph_levels([u16(0x06f1), 0x06f2, `+`, ` `, 0x0645], true)
	assert levels == [u8(2), 2, 1, 1, 1]
	assert bidi_visual_order([u8(2), 1, 1]) == [2, 1, 0]
	// Adjacent LTR spans stay together inside the RTL paragraph.
	assert bidi_visual_order([u8(2), 2, 1]) == [2, 0, 1]
	assert bidi_paragraph_levels([]u16{}, false).len == 0
	assert bidi_visual_order([]u8{}).len == 0
}
