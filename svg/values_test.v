module svg

fn test_number_and_length_read_only_rules() {
	mut number_value := SvgNumber{
		value: 2
	}
	number_value.set_value(4)!
	assert number_value.value == 4
	mut readonly_number := SvgNumber{
		value: 2
		read_only: true
	}
	if _ := readonly_number.set_value(4) {
		assert false
	} else {
		assert err.msg().contains('read-only')
	}
	mut length := SvgLength{
		value: 20
		unit: .px
	}
	length.set_value(5)!
	assert length.value == 5
	assert length.unit == .number
	animated := AnimatedLength.create(SvgLength{ value: 8, unit: .px })
	assert animated.base_val() != animated.anim_val()
	assert animated.anim_val().read_only
	mut animated_base := animated.base_val()
	animated_base.set_value(9)!
	assert animated.base_val().value == 9
}

fn test_number_list_webidl_algorithms() {
	mut list := NumberList{
		items: [1.0, 2.0]
	}
	assert list.insert_item_before(0, 0)! == 0
	assert list.insert_item_before(3, 99)! == 3
	assert list.replace_item(7, 1)! == 7
	assert list.remove_item(2)! == 2
	assert list.append_item(9)! == 9
	assert list.items == [0.0, 7.0, 3.0, 9.0]
	assert list.initialize(4)! == 4
	assert list.items == [4.0]
	mut readonly := NumberList{
		items: [1.0]
		read_only: true
	}
	if _ := readonly.append_item(2) {
		assert false
	} else {
		assert err.msg().contains('read-only')
	}
}

fn test_animated_number_and_integer_optional_second_value() {
	mut first := AnimatedNumber{
		attribute: '4'
		initial: 0
		supports_second: true
	}
	mut second := AnimatedNumber{
		attribute: '4'
		initial: 0
		supports_second: true
		represents_second: true
	}
	assert first.value() == 4
	assert second.value() == 4
	second.set_base_value(9)
	assert second.attribute == '4 9'
	first.attribute = second.attribute
	first.set_base_value(3)
	assert first.attribute == '3 9'
	first.attribute = 'bogus'
	assert first.value() == 0
	first.attribute = '50%'
	assert first.value() == 0.5
	mut integer := AnimatedInteger{
		attribute: '2'
		initial: 1
		supports_second: true
		represents_second: true
	}
	assert integer.value() == 2
	integer.set_base_value(6)
	assert integer.attribute == '2 6'
	integer.attribute = 'bogus'
	assert integer.value() == 1
}

fn test_animated_string_legacy_reflection() {
	mut reflected := AnimatedString{
		legacy: 'old'
		initial: 'initial'
	}
	assert reflected.value() == 'old'
	reflected.set_base_value('changed')
	assert reflected.primary == none
	assert reflected.legacy or { '' } == 'changed'
	reflected.primary = 'primary'
	assert reflected.value() == 'primary'
}

fn test_typed_lists_and_animated_rect() {
	mut lengths := LengthList{}
	lengths.append_item(SvgLength{ value: 3, unit: .px })!
	assert lengths.get_item(0)!.value == 3
	assert lengths.length() == lengths.number_of_items()
	lengths.insert_item_before(SvgLength{ value: 1 }, 0)!
	lengths.replace_item(SvgLength{ value: 2 }, 1)!
	assert lengths.remove_item(0)!.value == 1
	assert lengths.initialize(SvgLength{ value: 8 })!.value == 8
	mut transforms := TransformList{}
	transforms.append_item(Transform{ kind: .translate, values: [f64(2), 4, 0, 0, 0, 0]! })!
	assert transforms.get_item(0)!.values[1] == 4
	assert transforms.length() == 1
	transforms.insert_item_before(Transform{ kind: .scale }, 0)!
	assert transforms.remove_item(1)!.kind == .translate
	transforms.replace_item(Transform{ kind: .rotate }, 0)!
	assert transforms.initialize(Transform{ kind: .skew_x })!.kind == .skew_x
	transforms.clear()!
	assert transforms.items.len == 0
	animated_numbers := AnimatedNumberList.create(NumberList{ items: [1.0] })
	assert animated_numbers.base_val() == animated_numbers.anim_val()
	mut animated_number_base := animated_numbers.base_val()
	animated_number_base.append_item(2)!
	assert animated_numbers.anim_val().items == [1.0, 2.0]
	mut rect := AnimatedRect{
		nulled: true
	}
	assert rect.base() == none
	rect.nulled = false
	rect.base_value = Rect{
		width: 10
		height: 20
	}
	assert rect.base() or { Rect{} }.width == 10
}

fn test_animated_enumeration_rejects_unknown_zero() {
	mut enumeration := AnimatedEnumeration{
		value: 1
	}
	if _ := enumeration.set_base_value(0) {
		assert false
	} else {
		assert err.msg().contains('invalid')
	}
	enumeration.set_base_value(4)!
	assert enumeration.value == 4
}
