module dom

const dsm_html_ns = 'http://www.w3.org/1999/xhtml'

fn dsm_element(tag string) &Element {
	doc := Document.create(url_about_blank())
	return doc.create_element_ns(dsm_html_ns, tag) or { panic('${err}') }
}

// The camelCase <-> data-* name conversions.
fn test_dataset_name_conversion() {
	assert dataset_key_to_attribute_name('fooBar') == 'data-foo-bar'
	assert dataset_key_to_attribute_name('a') == 'data-a'
	assert dataset_key_to_attribute_name('userId') == 'data-user-id'
	assert attribute_name_to_dataset_key('data-foo-bar') == 'fooBar'
	assert attribute_name_to_dataset_key('data-a') == 'a'
	assert attribute_name_to_dataset_key('data-user-id') == 'userId'
	assert attribute_name_to_dataset_key('data-') == ''
}

// dataset reads data-* attributes through the camelCase key.
fn test_dataset_read() {
	mut el := dsm_element('div')
	el.set_attribute_value('data-user-id', '42')
	el.set_attribute_value('data-foo-bar', 'baz')

	ds := el.dataset()
	assert (ds.get('userId') or { 'none' }) == '42'
	assert (ds.get('fooBar') or { 'none' }) == 'baz'
	assert ds.get('missing') == none
	assert ds.contains('userId')
	assert !ds.contains('nope')
}

// dataset writes and removes the corresponding data-* attribute.
fn test_dataset_write() {
	mut el := dsm_element('div')
	ds := el.dataset()

	ds.set('camelCase', 'v')
	assert (el.get_attribute('data-camel-case') or { 'none' }) == 'v'
	assert (ds.get('camelCase') or { 'none' }) == 'v'

	ds.remove('camelCase')
	assert !el.has_attribute('data-camel-case')
	assert ds.get('camelCase') == none
}

// keys lists only the data-* attributes, in camelCase form.
fn test_dataset_keys() {
	mut el := dsm_element('div')
	el.set_attribute_value('data-a', '1')
	el.set_attribute_value('data-foo-bar', '2')
	el.set_attribute_value('class', 'x') // not a data-* attribute

	keys := el.dataset().keys()
	assert keys.len == 2
	assert 'a' in keys
	assert 'fooBar' in keys
}
