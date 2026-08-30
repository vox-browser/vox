module bindings

import dom
import html

fn constructor_test_document() &dom.Document {
	return dom.Document.create(dom.URL{ value: 'https://example.test/' })
}

fn test_audio_constructor_creates_preloaded_audio_and_converts_source() {
	document := constructor_test_document()
	constructor := AudioConstructor.create(document)
	assert constructor.metadata().name == 'Audio'
	if _ := constructor.call() {
		assert false
	}
	audio := constructor.construct(dom.js_number(42)) or { panic(err) }
	element := unsafe { &dom.Element(audio) }
	assert element.local_name() == 'audio'
	assert element.get_attribute_value('preload') == 'auto'
	assert element.get_attribute_value('src') == '42.0'

	without_source := constructor.construct(none) or { panic(err) }
	assert unsafe { &dom.Element(without_source) }.get_attribute('src') == none
}

fn test_custom_constructor_objects_report_constructor_capability() {
	document := constructor_test_document()
	assert AudioConstructor.create(document).has_constructor()
	assert ImageConstructor.create(document).has_constructor()
	assert OptionConstructor.create(document).has_constructor()
}

fn test_image_constructor_applies_touint32_dimensions() {
	document := constructor_test_document()
	constructor := ImageConstructor.create(document)
	image := constructor.construct(dom.js_number(-1), dom.js_string('240')) or { panic(err) }
	element := unsafe { &dom.Element(image) }
	assert element.local_name() == 'img'
	assert element.get_attribute_value('width') == '4294967295'
	assert element.get_attribute_value('height') == '240'
}

fn test_option_constructor_builds_text_attributes_and_selectedness() {
	document := constructor_test_document()
	constructor := OptionConstructor.create(document)
	option := constructor.construct(dom.js_string('Visible label'), dom.js_string('value-1'),
		dom.js_bool(true), dom.js_bool(false)) or { panic(err) }
	element := unsafe { &dom.Element(option) }
	assert element.local_name() == 'option'
	assert element.as_node().text_content() or { '' } == 'Visible label'
	assert element.get_attribute_value('value') == 'value-1'
	assert element.has_attribute('selected')
	assert !html.html_option_element_selected(option)

	selected := constructor.construct(none, none, none, dom.js_string('yes')) or { panic(err) }
	assert html.html_option_element_selected(selected)
}
