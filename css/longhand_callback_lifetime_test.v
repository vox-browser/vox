module css

import dom

#include "rule_callback_lifetime_test.h"

$if gcboehm ? {
	fn C.vox_css_rule_lifetime_watch_owner(index u32, owner voidptr)
	fn C.vox_css_rule_lifetime_owners_alive() u32
	fn C.vox_css_rule_lifetime_collect(depth u32)
	fn C.vox_css_rule_lifetime_run_worker(work fn ())
}

__global longhand_lifetime_live_values []ExpandedLonghand

@[noinline]
fn longhand_lifetime_build_image_owner(retain bool, shorthand bool) {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/sheet-owner' })
	mut sheet := parse_css_stylesheet_with_parser('', none)
	sheet.add_owning_document_or_shadow_root(document.as_node())
	property := if shorthand { PropertyID.background } else { PropertyID.background_image }
	typed := if shorthand {
		parse_css_value_logic(.background, 'url(retained.svg) red') or { panic('background did not parse') }
	} else {
		StyleValue(ImageStyleValue.create_from_url_string('retained.svg'))
	}
	mut value := dom_style_value_from_value_logic(typed)
	value.base_url = 'https://example.test/styles/main.css'
	set_style_sheet_on_dom_style_value(value, sheet)
	expanded := expand_property_longhands(property, value)
	assert expanded.len > 0
	mut images := 0
	for item in expanded {
		assert option_string_equal(item.value.base_url, value.base_url)
		if item.id == .background_image {
			assert item.value.css_text.contains('retained.svg')
			images++
		}
	}
	assert images == 1
	if retain { longhand_lifetime_live_values = expanded.clone() }
	$if gcboehm ? {
		C.vox_css_rule_lifetime_watch_owner(0, voidptr(document))
		C.vox_css_rule_lifetime_watch_owner(1, voidptr(sheet))
	}
	document.finalize()
}

fn longhand_lifetime_build_unretained_image() {
	longhand_lifetime_build_image_owner(false, false)
}

fn longhand_lifetime_build_unretained_shorthand() {
	longhand_lifetime_build_image_owner(false, true)
}

fn longhand_lifetime_build_retained_shorthand() {
	longhand_lifetime_build_image_owner(true, true)
}

fn longhand_lifetime_check_and_release_values() {
	assert longhand_lifetime_live_values.len > 1
	mut images := 0
	for item in longhand_lifetime_live_values {
		assert (item.value.base_url or { '' }) == 'https://example.test/styles/main.css'
		if item.id == .background_image {
			assert item.value.css_text.contains('retained.svg')
			images++
		}
	}
	assert images == 1
	// Replacing the container removes obsolete scanned pointer slots as well.
	longhand_lifetime_live_values = []ExpandedLonghand{}
}

fn test_longhand_collector_releases_its_only_image_stylesheet_owner() {
	$if gcboehm ? {
		C.vox_css_rule_lifetime_run_worker(longhand_lifetime_build_unretained_image)
		C.vox_css_rule_lifetime_collect(8)
		C.vox_css_rule_lifetime_collect(8)
		assert C.vox_css_rule_lifetime_owners_alive() == 0
	} $else {
		longhand_lifetime_build_unretained_image()
	}
}

fn test_recursive_shorthand_bridge_releases_its_only_image_stylesheet_owner() {
	$if gcboehm ? {
		C.vox_css_rule_lifetime_run_worker(longhand_lifetime_build_unretained_shorthand)
		C.vox_css_rule_lifetime_collect(8)
		C.vox_css_rule_lifetime_collect(8)
		assert C.vox_css_rule_lifetime_owners_alive() == 0
	} $else {
		longhand_lifetime_build_unretained_shorthand()
	}
}

fn test_returned_longhands_retain_live_stylesheet_values_until_their_owner_releases_them() {
	$if gcboehm ? {
		C.vox_css_rule_lifetime_run_worker(longhand_lifetime_build_retained_shorthand)
		C.vox_css_rule_lifetime_collect(8)
		assert C.vox_css_rule_lifetime_owners_alive() == 3
		C.vox_css_rule_lifetime_run_worker(longhand_lifetime_check_and_release_values)
		C.vox_css_rule_lifetime_collect(8)
		C.vox_css_rule_lifetime_collect(8)
		assert C.vox_css_rule_lifetime_owners_alive() == 0
	} $else {
		longhand_lifetime_build_retained_shorthand()
		longhand_lifetime_check_and_release_values()
	}
}

struct LonghandCallbackLog {
mut:
	ids    []PropertyID
	values []&dom.StyleValue
}

fn longhand_lifetime_record(context voidptr, property PropertyID, value &dom.StyleValue) {
	mut log := unsafe { &LonghandCallbackLog(context) }
	log.ids << property
	unsafe { log.values << value }
}

__global longhand_lifetime_legacy_log &LonghandCallbackLog

fn longhand_lifetime_legacy_record(property PropertyID, value &dom.StyleValue) {
	longhand_lifetime_record(voidptr(longhand_lifetime_legacy_log), property, value)
}

fn longhand_lifetime_typed_record(context voidptr, property PropertyID, value StyleValue) {
	longhand_lifetime_record(context, property, dom_style_value_from_value_logic(value))
}

fn longhand_lifetime_typed_legacy_record(property PropertyID, value StyleValue) {
	longhand_lifetime_typed_record(voidptr(longhand_lifetime_legacy_log), property, value)
}

fn longhand_lifetime_check_ids_and_text(log &LonghandCallbackLog, expected []PropertyID, text string) {
	assert log.ids == expected
	assert log.values.len == expected.len
	for value in log.values {
		assert value.css_text == text
	}
}

fn test_all_shorthand_css_wide_keywords_keep_generated_leaf_order_and_serialization() {
	mut checked := 0
	for index in int(PropertyID.accent_color) .. int(PropertyID.container) + 1 {
		property := unsafe { PropertyID(index) }
		if !property_is_shorthand(property) { continue }
		expected := generated_expanded_longhands_for_shorthand(property)
		assert expected.len > 0
		for text in ['initial', 'inherit', 'unset', 'revert', 'revert-layer'] {
			typed := parse_css_value_logic(property, text) or { panic('${property}: ${text} did not parse') }
			value := dom_style_value_from_value_logic(typed)
			log := &LonghandCallbackLog{}
			StyleComputer.for_each_property_expanding_shorthands_with_context(property, value, voidptr(log), longhand_lifetime_record)
			longhand_lifetime_check_ids_and_text(log, expected, text)
			longhand_lifetime_legacy_log = &LonghandCallbackLog{}
			StyleComputer.for_each_property_expanding_shorthands(property, value, longhand_lifetime_legacy_record)
			longhand_lifetime_check_ids_and_text(longhand_lifetime_legacy_log, expected, text)
			typed_log := &LonghandCallbackLog{}
			for_each_typed_property_expanding_shorthands_with_context(property, typed, voidptr(typed_log), longhand_lifetime_typed_record)
			longhand_lifetime_check_ids_and_text(typed_log, expected, text)
		}
		checked++
	}
	assert checked > 50
	longhand_lifetime_legacy_log = unsafe { nil }
}

// The generated direct dependency lists independently describe intermediate
// shorthand callbacks as well as the final leaves for pending substitution.
fn longhand_lifetime_unresolved_expected(property PropertyID) []PropertyID {
	mut ids := [property]
	if property_is_shorthand(property) {
		for child in generated_longhands_for_shorthand(property) {
			ids << longhand_lifetime_unresolved_expected(child)
		}
	}
	return ids
}

fn longhand_lifetime_pending_depths(property PropertyID, depth int) []int {
	mut depths := [depth]
	if property_is_shorthand(property) {
		for child in generated_longhands_for_shorthand(property) {
			depths << longhand_lifetime_pending_depths(child, depth + 1)
		}
	}
	return depths
}

fn test_all_unresolved_shorthands_keep_original_and_pending_values_in_metadata_order() {
	mut checked := 0
	for index in int(PropertyID.accent_color) .. int(PropertyID.container) + 1 {
		property := unsafe { PropertyID(index) }
		if !property_is_shorthand(property) { continue }
		typed := StyleValue(UnresolvedStyleValue.create(parse_component_values_for_value_logic('var(--retained)')))
		value := dom_style_value_from_value_logic(typed)
		expected := longhand_lifetime_unresolved_expected(property)
		depths := longhand_lifetime_pending_depths(property, 0)
		log := &LonghandCallbackLog{}
		StyleComputer.for_each_property_expanding_shorthands_with_context(property, value, voidptr(log), longhand_lifetime_record)
		assert log.ids == expected
		assert log.values.len == depths.len
		for i, expanded in log.values {
			// Nested shorthands wrap the pending value again. Preserve that
			// existing non-serializable boundary and the complete typed source.
			assert expanded.css_text == if depths[i] < 2 { 'var(--retained)' } else { '' }
			mut recovered := style_value_logic_from_dom(log.ids[i], expanded) or { panic('missing typed expansion') }
			for _ in 0 .. depths[i] {
				assert recovered is PendingSubstitutionStyleValue
				recovered = (recovered as PendingSubstitutionStyleValue).original_shorthand_value_ref()
			}
			assert recovered is UnresolvedStyleValue
			assert recovered.serialize(.normal) == 'var(--retained)'
		}
		checked++
	}
	assert checked > 50
}

fn test_structured_shorthand_values_keep_recursive_leaf_values_and_base_urls() {
	for property, text in {
		PropertyID.margin:     '1px 2px 3px 4px'
		PropertyID.border:     '2px solid red'
		PropertyID.background: 'url(test.svg) center / 10px 20px no-repeat red'
		PropertyID.font:       'italic bold 16px / 1.5 serif'
		PropertyID.grid:       'auto-flow / 10px 20px'
	} {
		typed := parse_css_value_logic(property, text) or { panic('${property} did not parse') }
		mut value := dom_style_value_from_value_logic(typed)
		value.base_url = 'https://example.test/style.css'
		expanded := expand_property_longhands(property, value)
		assert expanded.len > 1
		log := &LonghandCallbackLog{}
		StyleComputer.for_each_property_expanding_shorthands_with_context(property, value, voidptr(log), longhand_lifetime_record)
		assert log.ids.len == expanded.len
		for i, item in expanded {
			assert item.id == log.ids[i]
			assert item.value.css_text == log.values[i].css_text
			assert option_string_equal(item.value.base_url, value.base_url)
			assert !property_is_shorthand(item.id)
		}
	}
}

fn test_public_expansion_apis_leave_borrowed_callback_aliases_callable() {
	log := &LonghandCallbackLog{}
	callback := fn [log] (property PropertyID, value &dom.StyleValue) {
		longhand_lifetime_record(voidptr(log), property, value)
	}
	alias := callback
	value := dom_style_value_from_value_logic(parse_css_value_logic(.margin, '1px 2px') or { panic('margin') })
	StyleComputer.for_each_property_expanding_shorthands(.margin, value, callback)
	assert log.ids.len == 4
	alias(.width, value)
	assert log.ids.last() == .width
	typed_callback := fn [log] (property PropertyID, value StyleValue) {
		longhand_lifetime_typed_record(voidptr(log), property, value)
	}
	typed_alias := typed_callback
	typed := StyleValue(KeywordStyleValue.create(.initial))
	for_each_typed_property_expanding_shorthands(.padding, typed, typed_callback)
	typed_alias(.height, typed)
	assert log.ids.last() == .height
}
