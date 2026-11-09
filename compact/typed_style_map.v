module main

import browserjs
import css
import dom
import html
import json2

struct CompactTypedValue {
	kind string
	text string
	keyword string
	value f64
	unit string
	associated_property ?string
}

struct CompactTypedMapRequest {
	op string
	name string
	text string
	rule string
	computed bool
	values []json2.Any
}

fn compact_numeric_style_record(value css.CSSNumericValue) json2.Any {
	mut result := {'text': json2.Any(value.to_string())}
	if value is css.CSSUnitValue {
		result['kind'] = 'unit'
		result['value'] = value.value()
		result['unit'] = value.unit()
		return result
	}
	mut children := []css.CSSNumericValue{}
	kind := match value {
		css.CSSMathSum { children = value.values().values(); 'sum' }
		css.CSSMathProduct { children = value.values().values(); 'product' }
		css.CSSMathMin { children = value.values().values(); 'min' }
		css.CSSMathMax { children = value.values().values(); 'max' }
		css.CSSMathNegate { children = [value.value()]; 'negate' }
		css.CSSMathInvert { children = [value.value()]; 'invert' }
		css.CSSMathClamp { children = [value.lower_[0], value.value_[0], value.upper_[0]]; 'clamp' }
		else { 'style' }
	}
	result['kind'] = kind
	mut values := []json2.Any{}
	for child in children { values << compact_numeric_style_record(child) }
	result['values'] = values
	return result
}

fn compact_unparsed_style_segments(value &css.CSSUnparsedValue) []json2.Any {
	mut result := []json2.Any{}
	for token in value.tokens {
		if token is string { result << json2.Any(token) } else if token is css.CSSVariableReferenceValue {
			mut entry := {'variable': json2.Any(token.variable())}
			if fallback := token.fallback_ { entry['fallback'] = compact_unparsed_style_segments(fallback) }
			result << json2.Any(entry)
		}
	}
	return result
}

fn compact_typed_style_record(value css.CSSStyleValue) !json2.Any {
	if numeric := value.numeric_value_ { return compact_numeric_style_record(numeric) }
	if keyword := value.keyword_value_ {
		return json2.Any({'kind':json2.Any('keyword'), 'value':json2.Any(keyword.value())})
	}
	if unparsed := value.unparsed_value_ {
		return json2.Any({'kind':json2.Any('unparsed'), 'segments':json2.Any(compact_unparsed_style_segments(unparsed))})
	}
	mut kind := if value.transform_value_ != none { 'transform' } else { 'style' }
	if source := value.source_value_ {
		if source is css.ImageStyleValue || source is css.ImageSetStyleValue
			|| source is css.LinearGradientStyleValue || source is css.RadialGradientStyleValue
			|| source is css.ConicGradientStyleValue { kind = 'image' }
	}
	mut result := {'kind':json2.Any(kind), 'text':json2.Any(value.to_string()!)}
	if property := value.associated_property { result['associated_property'] = property }
	return result
}

fn compact_decode_typed_style_value(value CompactTypedValue) !css.MutableStylePropertyMapValue {
	if value.kind == 'string' { return css.MutableStylePropertyMapValue(value.text.clone()) }
	mut result := match value.kind {
		'unparsed' { css.CSSStyleValue.parse('--value', value.text.clone())! }
		'keyword' { css.CSSStyleValue.from_keyword(css.CSSKeywordValue.construct_impl(value.keyword.clone())!) }
		'unit' { css.CSSStyleValue.from_numeric(css.CSSUnitValue.construct_impl(value.value, value.unit.clone())!) }
		'transform' { css.CSSStyleValue.parse('transform', value.text.clone())! }
		'sum', 'product', 'min', 'max', 'negate', 'invert', 'clamp' {
			css.CSSStyleValue.from_numeric(css.CSSNumericValue.parse(value.text.clone())!)
		}
		else {
			property := value.associated_property or { return error('TypeError: Unassociated CSSStyleValue') }
			css.CSSStyleValue.parse(property.clone(), value.text.clone())!
		}
	}
	result.associated_property = if property := value.associated_property { property.clone() } else { none }
	return css.MutableStylePropertyMapValue(result)
}

fn compact_typed_map_values(mut property_map css.StylePropertyMapReadOnly, declaration &css.CSSStyleProperties, name string, computed bool) []css.CSSStyleValue {
	values := property_map.get_all(name)
	if computed && values.len > 0 {
		if source := values[0].source_value_ {
			text := source.serialize(.normal)
			if text.contains('anchor(') || text.contains('anchor-size(') {
				return css.CSSStyleValue.parse_all(name, declaration.get_property_value(name)) or { values }
			}
		}
	}
	return values
}

fn (mut binding CompactElementQueryBinding) typed_style_map_query(key string, source string) !string {
	request := compact_decode_query[CompactTypedMapRequest](source)!
	if request.op in ['parse', 'parseAll', 'numeric'] {
		if request.op == 'numeric' {
			return json2.encode(compact_numeric_style_record(css.CSSNumericValue.parse(request.text)!))
		}
		values := css.CSSStyleValue.parse_a_css_style_value(request.name, request.text, request.op == 'parseAll')!
		mut result := []json2.Any{}
		for value in values { result << compact_typed_style_record(value)! }
		return json2.encode(result)
	}
	mut scope := binding.document.enter_native_storage()
	defer { scope.finish() }
	mut declaration := &css.CSSStyleProperties(unsafe { nil })
	mut element := &dom.Element(unsafe { nil })
	if request.rule != '' {
		rule := binding.css_rules[request.rule] or { return error('TypeError: Invalid CSS rule') }
		declaration = rule.style() or { return error('TypeError: CSS rule has no style') }
	} else {
		node := binding.node_for_key(key) or { return error('TypeError: Invalid Element receiver') }
		element = node.as_element() or { return error('TypeError: Expected Element') }
		if request.computed {
			mut document := unsafe { &dom.Document(element.document()) }
			document.update_style()
			if document.get_window() == none { _ = html.WindowModel.create_top_level(document, none, '')! }
			window := unsafe { &html.WindowModel(document.get_window() or { return error('Missing Window') }) }
			declaration = window.get_computed_style(element, none)
		} else { declaration = css.element_style(element) }
	}
	mut result := json2.Any(json2.Null{})
	if request.op in ['set', 'append', 'delete', 'clear'] {
		if request.computed { return error('TypeError: Computed StylePropertyMap is read-only') }
		mut property_map := css.MutableStylePropertyMap.create(declaration)
		mut values := []css.MutableStylePropertyMapValue{}
		for value in request.values {
			decoded := compact_decode_query[CompactTypedValue](json2.encode(value))!
			values << compact_decode_typed_style_value(decoded)!
		}
		match request.op {
			'set' { if values.len == 0 { return error('TypeError: Missing value') }; property_map.set(request.name.clone(), values)! }
			'append' { if values.len == 0 { return error('TypeError: Missing value') }; property_map.append(request.name.clone(), values)! }
			'delete' { property_map.delete_(request.name)! }
			else { property_map.clear()! }
		}
		mut runtime := unsafe { &browserjs.Runtime(binding.runtime) }
		runtime.mark_document_state_dirty()
		runtime.mark_document_replay_effects()
	} else {
		mut property_map := if request.computed {
			css.StylePropertyMapReadOnly.create_computed_style(dom.AbstractElement.new(element, none))
		} else { css.StylePropertyMapReadOnly.create_for_declaration(declaration) }
		if request.op in ['get', 'getAll', 'has'] {
			_ = css.PropertyNameAndID.from_name(request.name) or { return error('TypeError: Invalid CSS property') }
			mut values := []json2.Any{}
			for value in compact_typed_map_values(mut property_map, declaration, request.name, request.computed) { values << compact_typed_style_record(value)! }
			result = if request.op == 'has' { json2.Any(values.len > 0) } else { json2.Any(values) }
		} else if request.op == 'size' {
			result = declaration.property_names().len
		} else if request.op == 'entries' {
			mut entries := []json2.Any{}
			for name in declaration.property_names() {
				mut values := []json2.Any{}
				for value in compact_typed_map_values(mut property_map, declaration, name, request.computed) { values << compact_typed_style_record(value)! }
				entries << json2.Any([json2.Any(name), json2.Any(values)])
			}
			result = entries
		} else { return error('TypeError: Invalid StylePropertyMap operation') }
	}
	scope.finish()
	if element != unsafe { nil } && !request.computed {
		records, attributes := browserjs.compact_attribute_state(element)
		return json2.encode({'value':result, 'styleText':json2.Any(element.get_attribute_value('style')),
			'attributeRecords':json2.Any(records), 'attributes':json2.Any(attributes)})
	}
	return json2.encode({'value':result})
}
