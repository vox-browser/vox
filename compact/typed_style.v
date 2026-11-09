module main

import css
import dom
import html
import json2

fn compact_typed_style_query(root &dom.Node, name string) !string {
	element := root.as_element() or { return error('TypeError: Expected Element') }
	if css.property_id_from_string(name) == none && !name.starts_with('--') { return error('TypeError: Invalid CSS property') }
	mut document := unsafe { &dom.Document(element.document()) }
	document.update_style()
	// Layout selects position options before their computed values are exposed.
	if document.get_window() == none { _ = html.WindowModel.create_top_level(document,none,'')! }
	window := unsafe { &html.WindowModel(document.get_window() or { return error('Missing Window') }) }
	declaration := window.get_computed_style(element,none)
	resolved := declaration.get_property_value(name)
	mut property_map := css.StylePropertyMapReadOnly.create_computed_style(dom.AbstractElement.new(element,none))
	mut value := property_map.get(name) or { return 'null' }
	if source := value.source_value_ {
		text := source.serialize(.normal)
		if text.contains('anchor(') || text.contains('anchor-size(') {
			values := css.CSSStyleValue.parse_a_css_style_value(name,resolved,false)!
			if values.len > 0 { value = values[0] }
		}
	}
	if keyword := value.keyword_value_ { return json2.encode({'kind':json2.Any('keyword'),'value':json2.Any(keyword.value())}) }
	if numeric := value.numeric_value_ {
		if numeric is css.CSSUnitValue { return json2.encode({'kind':json2.Any('unit'),'value':json2.Any(numeric.value()),'unit':json2.Any(numeric.unit())}) }
	}
	return json2.encode({'kind':json2.Any('style'),'text':json2.Any(value.to_string()!)})
}

fn compact_typed_style_bootstrap() string {
	return $embed_file('@VMODROOT/compact/typed_style.js').to_string()
}
