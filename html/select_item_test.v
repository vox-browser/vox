module html

fn test_select_item_option_ipc_round_trip() {
	item := SelectItemOption{
		id:       42
		selected: true
		disabled: false
		label:    'A label'
		value:    'a-value'
	}
	decoded := decode_select_item_option(encode_select_item_option(item))!
	assert decoded.id == item.id
	assert decoded.label == item.label
	assert decoded.value == item.value
	assert decoded.selected
	assert !decoded.disabled
	assert decoded.option_element == none
}

fn test_select_item_option_group_ipc_round_trip() {
	group := SelectItemOptionGroup{
		label: 'Group'
		items: [
			SelectItemOption{
				id:    1
				label: 'One'
				value: '1'
			},
			SelectItemOption{
				id:       2
				selected: true
				disabled: true
				label:    'Two'
				value:    '2'
			},
		]
	}
	decoded := decode_select_item_option_group(encode_select_item_option_group(group))!
	assert decoded.label == 'Group'
	assert decoded.items.len == 2
	assert decoded.items[1].id == 2
	assert decoded.items[1].selected
	assert decoded.items[1].disabled
}

fn test_select_item_separator_encodes_no_fields() {
	encoded := encode_select_item_separator(SelectItemSeparator{})
	assert encoded.len == 0
	_ = decode_select_item_separator(encoded)!
}

fn test_select_item_decoder_rejects_truncation() {
	if _ := decode_select_item_option([u8(1), 2]) {
		assert false
	}
}
