module css

import dom
import math

fn semantic_page_fixture() &ComputedPropertyPage {
	mut page := &ComputedPropertyPage{}
	page.values[0] = dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(9.5))))
	page.values[1] = parse_css_value(ParsingParams{}, 'rgb(17 34 51)', .color) or { panic('Expected typed computed style value') }
	page.values[2] = dom_style_value_from_value_logic(StyleValue(SuperellipseStyleValue.create(StyleValue(NumberStyleValue.create(1)))))
	page.values[3] = parse_css_value(ParsingParams{}, 'oblique 12deg', .font_style) or { panic('Expected typed computed style value') }
	return page
}

fn test_semantic_pages_share_independent_equal_typed_computed_defaults() {
	first := semantic_page_fixture()
	second := semantic_page_fixture()
	assert voidptr(first.values[0]) != voidptr(second.values[0])
	assert computed_page_semantic_hash(first) == computed_page_semantic_hash(second)
	mut pool := ComputedPropertyPageInterner{}
	a := pool.intern(first, computed_property_page_hash(first))
	b := pool.intern(second, computed_property_page_hash(second))
	assert voidptr(a) == voidptr(b)
}

fn test_semantic_page_buckets_compare_typed_payloads_beyond_rounded_text() {
	mut first := semantic_page_fixture()
	mut second := semantic_page_fixture()
	value := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(9.500000001))))
	second.values[0] = &dom.StyleValue{css_text:first.values[0].css_text, css_value_handle:value.css_value_handle}
	assert computed_page_semantic_hash(first) == computed_page_semantic_hash(second)
	assert !computed_page_semantic_values_equal(first, second)
	mut pool := ComputedPropertyPageInterner{}
	assert voidptr(pool.intern(first, computed_property_page_hash(first)))
		!= voidptr(pool.intern(second, computed_property_page_hash(second)))
	first.values[0] = dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(math.nan())))
	second.values[0] = dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(math.nan())))
	assert !computed_page_semantic_values_equal(first, second)
}

fn test_semantic_pages_keep_resource_clients_distinct() {
	mut first := semantic_page_fixture()
	mut second := semantic_page_fixture()
	first.values[4] = parse_css_value(ParsingParams{}, 'url("https://example.test/picture.png")', .background_image) or { panic('Expected typed computed style value') }
	second.values[4] = parse_css_value(ParsingParams{}, 'url("https://example.test/picture.png")', .background_image) or { panic('Expected typed computed style value') }
	assert computed_page_scalar_box(first.values[4]) == none
	assert !computed_page_semantic_values_equal(first, second)
}

fn test_semantic_page_hash_invalidates_after_a_property_replacement() {
	mut source := ComputedProperties.new()
	source.set_property(.width, parse_css_value(ParsingParams{}, '7px', .width) or { panic('Expected typed computed style value') }, .no, .no)
	index := (int(PropertyID.width) - int(first_longhand_property_id())) / computed_property_page_size
	old := source.property_store_.pages[index]
	previous := computed_page_semantic_hash(old)
	snapshot := &ComputedProperties{...source, property_store_:source.clone_raw_property_store()}
	source.set_property(.width, parse_css_value(ParsingParams{}, '19px', .width) or { panic('Expected typed computed style value') }, .no, .no)
	assert computed_page_semantic_hash(old) == previous
	assert computed_page_semantic_hash(source.property_store_.pages[index]) != previous
	assert snapshot.property(.width, .no)?.css_text == '7px'
	assert source.property(.width, .no)?.css_text == '19px'
}
