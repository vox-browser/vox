module css

import dom
import platform

fn scalar_keyframe_fixture() (&dom.Document, &dom.Element, &StyleComputer) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	mut element := document.create_element('div') or { panic(err) }
	mut root := document.as_node()
	root.append_child(element.as_node()) or { panic(err) }
	element.set_attribute_value('style', 'font-size:20px;color:rgb(12,34,56);width:90px;--key-width:17px')
	_ = up_to_date_computed_properties_for_element(element)
	return document, element, css_style_computer_for(document)
}

fn assert_scalar_keyframe_maps_equal(actual map[PropertyID]&dom.StyleValue, expected map[PropertyID]&dom.StyleValue) {
	assert actual.keys() == expected.keys()
	for id, value in expected {
		assert actual[id].css_text == value.css_text, '${id}'
		a := typed_style_value_logic_from_dom(actual[id]) or { panic('missing actual type') }
		b := typed_style_value_logic_from_dom(value) or { panic('missing expected type') }
		assert a.equals(b), '${id}'
	}
}

fn test_keyframe_scalar_shortcut_matches_full_computation_for_constant_values() {
	mut document, element, computer := scalar_keyframe_fixture()
	defer { document.finalize() }
	style := up_to_date_computed_properties_for_element(element)
	subject := dom.AbstractElement.new(element, none)
	for id, texts in {
		PropertyID.width: ['auto','13.5px','24%']
		.margin_left: ['-4px','auto','13%']
		.color: ['currentcolor']
		.z_index: ['auto','12']
		.opacity: ['-2','0','.37','2','-20%','37%','120%']
		.fill_opacity: ['-.5','25%','2']
		.transform: ['none','rotate(1turn)','translate(13px, 20%) scale(2)',
			'matrix(1,0,0,1,13,7)','matrix3d(1,0,0,0,0,1,0,0,0,0,1,0,13,7,2,1)']
	} {
		for text in texts {
			value := parse_css_value(ParsingParams{}, text, id) or { panic('${id} ${text}') }
			computer.clear_computation_context_caches()
			expected := compute_value_of_property_from_source(id,value,
				ComputedPropertyValueSource{properties:style},
				computer.get_computation_context_for_property(id,style,subject),1)
			if !retain_keyframe_scalar_context {
				actual := keyframe_value_without_context(id,value) or { panic('missed ${id} ${text}') }
				assert actual.css_text == expected.css_text, '${id} ${text}'
				a := typed_style_value_logic_from_dom(actual) or { panic('actual') }
				b := typed_style_value_logic_from_dom(expected) or { panic('expected') }
				assert a.equals(b), '${id} ${text}'
			}
		}
	}
}

fn test_keyframe_scalar_shortcut_rejects_contextual_and_untyped_values() {
	for id, texts in {
		PropertyID.width: ['2em','3rem','2pt','10vw','10cqw','calc(2px + 4%)']
		.transform: ['translateX(2em)','translateY(3vh)','translateX(calc(2px + 4%))']
		.color: ['CanvasText','light-dark(red,blue)']
		.opacity: ['calc(.2 + .3)','var(--alpha)']
		.font_size: ['13px','2em']
		.line_height: ['normal','13px']
	} {
		for text in texts {
			value := parse_css_value(ParsingParams{},text,id) or { panic('${id} ${text}') }
			assert keyframe_value_without_context(id,value) == none, '${id} ${text}'
		}
	}
	assert keyframe_value_without_context(.width,&dom.StyleValue{css_text:'13px'}) == none
}

fn test_keyframe_scalar_values_keep_substitution_keywords_logical_aliases_and_mutations() {
	mut document, mut element, computer := scalar_keyframe_fixture()
	defer { document.finalize() }
	for mode in ['horizontal-tb','vertical-rl'] {
		for width in ['17px','41px'] {
			element.set_attribute_value('style','writing-mode:${mode};direction:rtl;font-size:20px;width:90px;--key-width:${width}')
			style := up_to_date_computed_properties_for_element(element)
			mut frame := ResolvedKeyFrame{}
			for id,text in {
				PropertyID.width: 'var(--key-width)'
				.inline_size: '31px'
				.block_size: '25%'
				.margin_inline_start: 'inherit'
				.opacity: 'initial'
				.transform: 'rotate(30deg) translateX(7px)'
				.font_size: '2em'
			} { frame.properties[id] = parse_css_value(ParsingParams{},text,id) or { panic(text) } }
			frame.use_initial_properties[.height] = false
			frame.use_initial_properties[.width] = true
			subject := dom.AbstractElement.new(element,none)
			computer.clear_computation_context_caches()
			expected := computer.compute_keyframe_values_with_id_map(subject,frame,style)
			computer.clear_computation_context_caches()
			actual := computer.compute_keyframe_values(subject,frame,style)
			assert_scalar_keyframe_maps_equal(actual,expected)
		}
	}
}

fn test_keyframe_scalar_values_preserve_contextual_dependency_tracking() {
	mut document, element, computer := scalar_keyframe_fixture()
	defer { document.finalize() }
	for value in ['13px','10vw','2em','calc(2px + 10vw)'] {
		mut style := computed_properties_with_initial_values()
		computer.clear_computation_context_caches()
		frame := ResolvedKeyFrame{properties:{
			PropertyID.width: parse_css_value(ParsingParams{},value,.width) or { panic(value) }
		}}
		actual := computer.compute_keyframe_values(dom.AbstractElement.new(element,none),frame,style)
		assert actual.len == 1
		assert style.depends_on_viewport_metrics() == value.contains('vw'), value
	}
}

fn test_keyframe_scalar_values_keep_native_ownership_after_temporary_lookup_retirement() {
	$if prealloc {
		mut document, element, computer := scalar_keyframe_fixture()
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		style := up_to_date_computed_properties_for_element(element)
		mut frame := ResolvedKeyFrame{}
		for id,text in {PropertyID.opacity:'120%', .transform:'rotate(17deg) translateX(4px)', .width:'17px'} {
			frame.properties[id] = parse_css_value(ParsingParams{},text,id) or { panic(text) }
		}
		values := computer.compute_keyframe_values(dom.AbstractElement.new(element,none),frame,style)
		for _,value in values {
			assert document.native_storage().arena.contains(value)
			assert document.native_storage().arena.contains(value.css_value_handle)
		}
		owner.finish()
		for _ in 0 .. 8 {
			scratch := platform.begin_thread_scratch('keyframe lookup overwrite')
			_ = 'overwrite retired lookup'.repeat(1024)
			scratch.finish()
		}
		assert values[.opacity].css_text == '1'
		assert values[.width].css_text == '17px'
		typed := typed_style_value_logic_from_dom(values[.transform]) or { panic('retained transform') }
		assert keyframe_transform_is_resolved(&typed)
		document.finalize()
		document.release_native_storage()
	}
}
