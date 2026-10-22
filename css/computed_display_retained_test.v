module css

import dom

// Preserve the general conversion as an independent path through the bridge.
fn retained_display_oracle(style &ComputedProperties) Display {
	value := style.property(.display, .yes) or { return Display.from_short(.inline_) }
	typed := style_value_logic_from_dom(.display, value) or { panic('missing display') }
	if typed is DisplayStyleValue {
		return typed.display()
	}
	panic('unexpected display type')
}

fn test_computed_display_preserves_every_retained_display_record_and_owner() {
	mut displays := []Display{}
	for outside in [DisplayOutside.block, .inline_, .run_in] {
		for inside in [DisplayInside.flow, .flow_root, .table, .flex, .grid, .ruby, .math,
			.webkit_box] {
			for item in [DisplayListItem.no, .yes] {
				displays << Display.from_outside_inside_and_list_item(outside, inside, item)
			}
		}
	}
	for internal in [DisplayInternal.table_row_group, .table_header_group, .table_footer_group,
		.table_row, .table_cell, .table_column_group, .table_column, .table_caption,
		.ruby_base, .ruby_text, .ruby_base_container, .ruby_text_container] {
		displays << Display.from_internal(internal)
	}
	displays << Display.from_box(.none_)
	displays << Display.from_box(.contents)
	mut style := ComputedProperties.new()
	for expected in displays {
		owner := dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(expected)))
		// A retained typed value remains authoritative over its text projection.
		value := &dom.StyleValue{
			css_text: 'not-a-display'
			css_value_handle: owner.css_value_handle
		}
		style.set_property(.display, value, .yes, .yes)
		actual := style.display()
		assert actual == expected
		assert actual == retained_display_oracle(style)
		gc_collect()
		assert style.display() == expected
		assert voidptr(style.property(.display, .no)?) == voidptr(value)
		assert value.css_value_handle == owner.css_value_handle
		assert style.is_property_important(.display)
		assert style.is_property_inherited(.display)
		style.set_property(.display, dom_style_value_from_value_logic(StyleValue(
			DisplayStyleValue.create(Display.from_short(.block)))), .no, .no)
		gc_collect()
		assert actual == expected
		assert style.display() == Display.from_short(.block)
	}
}

fn test_computed_display_keeps_initial_and_text_only_bridge_fallbacks() {
	mut style := ComputedProperties.new()
	assert style.display() == Display.from_short(.inline_)
	for source, expected in {
		'none': 'none'
		'contents': 'contents'
		'BLOCK': 'block'
		' inline-flex ': 'inline-flex'
		'inline flow-root': 'inline-block'
		'block flow list-item': 'list-item'
		'table-row': 'table-row'
		'inline math': 'math'
	} {
		value := &dom.StyleValue{css_text: source}
		style.set_property(.display, value, .no, .no)
		assert value.css_value_handle == unsafe { nil }
		assert style.display().to_string() == expected
		assert style.display() == retained_display_oracle(style)
		gc_collect()
		assert style.display().to_string() == expected
		assert value.css_value_handle == unsafe { nil }
	}
}

fn test_computed_display_keeps_animation_importance_transition_and_replacement() {
	mut style := ComputedProperties.new()
	base := dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(
		Display.from_short(.none_))))
	animated := dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(
		Display.from_short(.inline_grid))))
	for important in [Important.no, .yes] {
		for transition in [AnimatedPropertyResultOfTransition.no, .yes] {
			style.set_property(.display, base, .no, important)
			style.set_animated_property(.display, animated, transition, .yes)
			expected := if important == .no || transition == .yes {
				Display.from_short(.inline_grid)
			} else {
				Display.from_short(.none_)
			}
			assert style.display() == expected
			assert style.display() == retained_display_oracle(style)
			assert voidptr(style.property(.display, .no)?) == voidptr(base)
			gc_collect()
			assert style.display() == expected
			style.remove_animated_property(.display)
			assert style.display().is_none()
		}
	}
	style.set_property(.display, &dom.StyleValue{css_text: 'contents'}, .no, .no)
	assert style.display().is_contents()
	style.set_animated_property(.display, &dom.StyleValue{css_text: 'inline-flex'}, .no, .no)
	assert style.display() == Display.from_short(.inline_flex)
	style.remove_animated_property(.display)
	gc_collect()
	assert style.display().is_contents()
}
