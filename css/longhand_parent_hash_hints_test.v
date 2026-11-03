module css

import dom

fn parent_hint_fixture() (&StyleComputer, &dom.Element, &ComputedProperties) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	mut parent := document.create_element('div') or { panic(err) }
	child := document.create_element('span') or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic(err) }
	parent.set_attribute_value('style','font-size:20px;color:red')
	computer := StyleComputer.new(document)
	mut abstract_parent := dom.AbstractElement.new(parent,none)
	style := computer.compute_style(abstract_parent)
	abstract_parent.set_computed_properties(computed_properties_to_dom(style))
	return computer,child,style
}

fn parent_hint_cascade() &CascadedProperties {
	mut cascaded := CascadedProperties.new()
	cascaded.set_property(.width,parse_css_value(ParsingParams{},'70px',.width) or { panic('width') },
		.yes,.author,none,unsafe { nil },none)
	return cascaded
}

fn parent_hint_assert_oracle(actual &ComputedProperties, computer &StyleComputer,
	child &dom.Element, mut cascade CascadedProperties) {
	mut uncached := StyleComputer.new(computer.document_)
	uncached.viewport_rect_=computer.viewport_rect_
	uncached.root_element_font_metrics=computer.root_element_font_metrics
	uncached.root_element_font_metrics_depend_on_viewport_metrics=computer.root_element_font_metrics_depend_on_viewport_metrics
	oracle := uncached.compute_properties(dom.AbstractElement.new(child,none),mut cascade)
	for index in 0 .. number_of_longhand_properties {
		id := unsafe { PropertyID(index+int(first_longhand_property_id())) }
		left := actual.raw_property_at_index(index)
		right := oracle.raw_property_at_index(index)
		assert (left==unsafe { nil })==(right==unsafe { nil }),string_from_property_id(id)
		if left==unsafe { nil } { continue }
		left_value := style_value_logic_from_dom(id,left) or { panic('actual value') }
		right_value := style_value_logic_from_dom(id,right) or { panic('oracle value') }
		assert left_value.equals(right_value),string_from_property_id(id)
		assert actual.is_property_inherited(id)==oracle.is_property_inherited(id),string_from_property_id(id)
		assert actual.is_property_important(id)==oracle.is_property_important(id),string_from_property_id(id)
	}
	assert actual.depends_on_viewport_metrics_==oracle.depends_on_viewport_metrics_
	assert actual.font_metrics_depend_on_viewport_metrics_==oracle.font_metrics_depend_on_viewport_metrics_
}

fn test_parent_hash_hints_preserve_exact_restoration_and_tracked_mutations() {
	computer,child,parent := parent_hint_fixture()
	subject := dom.AbstractElement.new(child,none)
	mut cascade := parent_hint_cascade()
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	first := computer.compute_properties(subject,mut cascade)
	key := computer.computed_longhand_reuse_key(subject,cascade,parent,false) or { panic('eligible') }
	mut probe := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key,cascade,mut probe)
	parent_hint_assert_oracle(first,computer,child,mut cascade)
	mut mutable_parent := unsafe { parent }
	mutable_parent.set_property(.color,parse_css_value(ParsingParams{},'blue',.color) or { panic('blue') },.no,.no)
	fresh := inherited_longhand_hash(parent) or { panic('fresh hash') }
	hint := computer.inherited_longhand_hash_hint(parent,subject) or { panic('hash hint') }
	assert hint==fresh
	assert !computer.restore_computed_longhands(key,cascade,mut probe)
	actual := computer.compute_properties(subject,mut cascade)
	parent_hint_assert_oracle(actual,computer,child,mut cascade)
}

fn test_stale_parent_hash_hints_cannot_restore_directly_mutated_typed_payloads() {
	computer,child,parent := parent_hint_fixture()
	subject := dom.AbstractElement.new(child,none)
	mut cascade := parent_hint_cascade()
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	_ = computer.compute_properties(subject,mut cascade)
	color := parent.property(.color,.no) or { panic('color') }
	mut box := unsafe { &TypedStyleValueBox(color.css_value_handle) }
	box.value=StyleValue(ColorStyleValue.create(Color.rgba(0,0,255,255)))
	key := computer.computed_longhand_reuse_key(subject,cascade,parent,false) or { panic('eligible') }
	mut probe := computed_properties_with_initial_values()
	assert !computer.restore_computed_longhands(key,cascade,mut probe)
	actual := computer.compute_properties(subject,mut cascade)
	parent_hint_assert_oracle(actual,computer,child,mut cascade)
	next := computer.computed_longhand_reuse_key(subject,cascade,parent,false) or { panic('new key') }
	assert computer.restore_computed_longhands(next,cascade,mut probe)
}

fn test_stale_parent_hash_hints_do_not_publish_untyped_parent_bridges() {
	computer,child,parent := parent_hint_fixture()
	subject := dom.AbstractElement.new(child,none)
	mut cascade := parent_hint_cascade()
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	_ = computer.compute_properties(subject,mut cascade)
	key := computer.computed_longhand_reuse_key(subject,cascade,parent,false) or { panic('eligible key') }
	mut color := parent.property(.color,.no) or { panic('color') }
	color.css_value_handle=unsafe { nil }
	color.css_text='blue'
	mut probe := computed_properties_with_initial_values()
	assert !computer.restore_computed_longhands(key,cascade,mut probe)
	actual := computer.compute_properties(subject,mut cascade)
	parent_hint_assert_oracle(actual,computer,child,mut cascade)
	before := computer.longhand_reuse_cache_.entries.len
	computer.remember_computed_longhands(key,cascade,actual)
	assert computer.longhand_reuse_cache_.entries.len==before
	assert !computer.restore_computed_longhands(key,cascade,mut probe)
}

fn test_parent_hash_hints_track_token_replacement_and_unknown_revisions() {
	computer,child,parent := parent_hint_fixture()
	subject := dom.AbstractElement.new(child,none)
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	_ = computer.inherited_longhand_hash_hint(parent,subject) or { panic('original hash') }
	mut mutable_parent := unsafe { parent }
	mutable_parent.computed_property_graph_token_=&ComputedPropertyGraphMutationToken{}
	mutable_parent.set_property(.color,parse_css_value(ParsingParams{},'blue',.color) or { panic('blue') },.no,.no)
	fresh := inherited_longhand_hash(parent) or { panic('fresh hash') }
	assert computer.inherited_longhand_hash_hint(parent,subject) or { panic('replacement hash') }==fresh
	mutable_parent.computed_property_graph_token_.generation=0
	mutable_parent.set_property(.color,parse_css_value(ParsingParams{},'green',.color) or { panic('green') },.no,.no)
	unknown := inherited_longhand_hash(parent) or { panic('unknown hash') }
	assert computer.inherited_longhand_hash_hint(parent,subject) or { panic('uncached unknown revision') }==unknown
}

fn test_parent_hash_hints_are_bounded_and_retire_at_the_outer_batch_boundary() {
	computer,child,_ := parent_hint_fixture()
	subject := dom.AbstractElement.new(child,none)
	computer.begin_computed_property_page_batch()
	computer.begin_computed_property_page_batch()
	mut first_parent := computed_properties_with_initial_values()
	_ = computer.inherited_longhand_hash_hint(first_parent,subject) or { panic('first parent') }
	for _ in 0 .. 1030 {
		parent := computed_properties_with_initial_values()
		_ = computer.inherited_longhand_hash_hint(parent,subject) or { panic('parent hash') }
	}
	if !retain_parent_longhand_hashing {
		assert computer.longhand_reuse_cache_.parent_hashes.len==1024
		first_parent.set_property(.color,parse_css_value(ParsingParams{},'blue',.color) or { panic('blue') },.no,.no)
		fresh := inherited_longhand_hash(first_parent) or { panic('fresh bounded hash') }
		assert computer.inherited_longhand_hash_hint(first_parent,subject) or { panic('updated bounded hash') }==fresh
		previous := computer.longhand_reuse_cache_.parent_hashes[u64(voidptr(first_parent))] or { panic('retained first parent') }
		assert previous.revision==first_parent.mutation_revision()
		assert computer.longhand_reuse_cache_.parent_hashes.len==1024
		computer.end_computed_property_page_batch()
		assert computer.longhand_reuse_cache_!=unsafe { nil }
	} else {
		assert computer.longhand_reuse_cache_==unsafe { nil }
		computer.end_computed_property_page_batch()
	}
	computer.end_computed_property_page_batch()
	assert computer.longhand_reuse_cache_==unsafe { nil }
}
