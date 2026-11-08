module dom

fn test_token_list_add_validates_every_token_before_mutating_the_ordered_set() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element('div')!
	element.set_attribute_value('class', 'seed')
	mut list := element.class_list()
	for invalid in ['', 'bad token', '\ttab'] {
		if _ := list.add(['added', invalid]) { assert false }
		assert list.length() == 1
		assert list.item(0)? == 'seed'
		assert !list.contains('added')
		assert element.get_attribute_value('class') == 'seed'
	}
	list.add(['added', 'seed', 'last'])!
	assert list.token_set == ['seed', 'added', 'last']
	assert element.get_attribute_value('class') == 'seed added last'
}

fn test_token_list_remove_validates_every_token_before_mutating_the_ordered_set() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element('div')!
	element.set_attribute_value('class', 'first second third')
	mut list := element.class_list()
	for invalid in ['', 'bad\ntoken', 'bad\rtoken'] {
		if _ := list.remove(['second', invalid]) { assert false }
		assert list.token_set == ['first', 'second', 'third']
		assert element.get_attribute_value('class') == 'first second third'
	}
	list.remove(['second', 'missing', 'first'])!
	assert list.token_set == ['third']
	assert element.get_attribute_value('class') == 'third'
}
