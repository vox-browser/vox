module css

#include "simple_selector_storage_test.h"

$if gcboehm ? {
	fn C.vox_compact_selector_watch_owner(index u32, owner voidptr)
	fn C.vox_compact_selector_alive_mask() u32
	fn C.vox_compact_selector_collect(depth u32)
	fn C.vox_compact_selector_run_worker(work fn ())
	fn C.vox_compact_selector_array_kind(data voidptr) int
	fn C.vox_compact_selector_array_size(data voidptr) usize
}

fn test_compact_simple_selector_defaults_and_all_single_payload_variants() {
	empty := SimpleSelector{}
	assert empty.fields() == SimpleSelectorInit{}
	assert empty == SimpleSelector.create(SimpleSelectorInit{})
	samples := [
		SimpleSelectorInit{ type_: .id, name: SelectorName.new('Id') },
		SimpleSelectorInit{ type_: .tag_name, qualified_name: SelectorQualifiedName{ namespace_type: .named, namespace_: 'ns', name: SelectorName.new('Tag') } },
		SimpleSelectorInit{ type_: .attribute, attribute: SelectorAttribute{ match_type: .exact_value_match, qualified_name: SelectorQualifiedName{ name: SelectorName.new('data-x') }, value: 'x', case_type: .case_sensitive_match } },
		SimpleSelectorInit{ type_: .pseudo_class, pseudo_class: PseudoClassSelector{ type_: .nth_child, an_plus_b_pattern: ANPlusBPattern{ step_size: 2, offset: 1 }, is_forgiving: true, languages: ['en'], ident: PseudoClassIdent{ keyword: .ltr, string_value: 'ltr' }, levels: [i64(2)] } },
		SimpleSelectorInit{ type_: .pseudo_element, pseudo_element: PseudoElementSelector{ type_: .part, name: 'part', value_kind: .ident_list, ident_list: [
			'one',
			'two',
		] } },
		SimpleSelectorInit{ type_: .invalid, invalid_text: ':unknown()' },
	]
	for fields in samples {
		selector := SimpleSelector.create(fields)
		assert selector.fields() == fields
		assert selector.payload_kind_ != .expanded
		// A semantic-kind change retained inactive fields in the old public record.
		mut copy := selector
		copy.type_ = .universal
		mut expected := fields
		expected.type_ = .universal
		assert copy.fields() == expected
		assert selector.fields() == fields
	}
}

fn test_compact_simple_selector_multifield_snapshots_and_cross_arm_updates_keep_value_copies() {
	fields := SimpleSelectorInit{ type_: .class, name: SelectorName.new('original'), qualified_name: SelectorQualifiedName{ namespace_type: .none, name: SelectorName.new('unused') }, invalid_text: 'inactive' }
	original := SimpleSelector.create(fields)
	assert original.payload_kind_ == .expanded
	mut changed := original
	changed.set_name(SelectorName.new('changed'))
	changed.set_attribute(SelectorAttribute{ value: 'attribute' })
	changed.set_pseudo_class(PseudoClassSelector{ type_: .lang, languages: ['en'] })
	changed.set_pseudo_element(PseudoElementSelector.new(.before))
	assert original.fields() == fields
	assert changed.name().name == 'changed'
	assert changed.attribute().value == 'attribute'
	assert changed.pseudo_class().languages == ['en']
	assert changed.pseudo_element().type_ == .before
	assert changed.qualified_name() == fields.qualified_name
	assert changed.invalid_text() == 'inactive'
	changed.set_invalid_text('')
	changed.set_qualified_name(SelectorQualifiedName{})
	assert original.fields() == fields
	assert changed.invalid_text() == ''
	assert changed.qualified_name() == SelectorQualifiedName{}
	changed.set_name(SelectorName{})
	changed.set_attribute(SelectorAttribute{})
	changed.set_pseudo_class(PseudoClassSelector{})
	changed.set_pseudo_element(PseudoElementSelector{})
	assert changed.fields() == SimpleSelectorInit{ type_: .class }
	assert changed.serialize() == '.'
}

fn test_compact_simple_selector_nested_array_sharing_and_top_level_copy_depth_are_unchanged() {
	mut languages := ['en', 'fr']
	original := SimpleSelector.with_pseudo_class(.pseudo_class, PseudoClassSelector{ type_: .lang, languages: languages })
	mut copied := original
	mut payload := copied.pseudo_class()
	// A V record copy historically shares the nested array until a caller clones it.
	payload.languages[0] = 'de'
	assert original.pseudo_class().languages[0] == 'de'
	payload.languages = payload.languages.clone()
	payload.languages[0] = 'es'
	copied.set_pseudo_class(payload)
	assert copied.pseudo_class().languages == ['es', 'fr']
	assert original.pseudo_class().languages == ['de', 'fr']
	copied.set_name(SelectorName.new('inactive'))
	assert copied.pseudo_class() == payload
	assert original.name() == SelectorName{}
}

fn test_compact_simple_selector_absolutization_and_default_namespace_keep_serialization_specificity() {
	selector := selector_from_text('div.foo:not(&, [data-x="x"]):nth-child(2n+1)')
	replacement := SimpleSelector.with_pseudo_class(.pseudo_class, PseudoClassSelector{ type_: .is_, argument_selector_list: SelectorList{ selectors: [selector_from_text('#parent')] } })
	before := selector.serialize()
	expanded := selector.absolutized(replacement) or { panic('absolutization failed') }
	assert selector.serialize() == before
	assert expanded.serialize() == 'div.foo:not(:is(#parent), [data-x="x"]):nth-child(2n+1)'
	assert selector_from_text('div.foo[data-x]:not(#x)').specificity() == u32(0x010201)
	assert SimpleSelector.with_qualified_name(.universal, SelectorQualifiedName{}).serialize() == '*'
	assert SimpleSelector.with_qualified_name(.tag_name, SelectorQualifiedName{ namespace_type: .none, name: SelectorName.new('svg') }).serialize() == '|svg'
}

fn test_compact_simple_selector_record_and_dynamic_array_capacity_are_reduced() {
	assert sizeof(SimpleSelectorPayload) == sizeof(SelectorQualifiedName)
	assert sizeof(SimpleSelector) <= sizeof(SelectorQualifiedName) + 8
	assert sizeof(SimpleSelector) * 2 < sizeof(SimpleSelectorInit)
	mut values := []SimpleSelector{}
	values << SimpleSelector.with_name(.class, SelectorName.new('one'))
	values << SimpleSelector.with_name(.class, SelectorName.new('two'))
	assert values.len == 2 && values.cap == 2
	$if gcboehm ? {
		assert C.vox_compact_selector_array_kind(values.data) == 1
		assert C.vox_compact_selector_array_size(values.data) >= usize(values.len * int(sizeof(SimpleSelector)))
		assert C.vox_compact_selector_array_size(values.data) < usize(values.cap * int(sizeof(SimpleSelectorInit)))
	}
}

__global compact_selector_retained []SimpleSelector

fn compact_selector_create_sole_owner() {
	nested_a := selector_from_text('.retained-one')
	nested_b := selector_from_text('.retained-two')
	outer := SimpleSelector.with_pseudo_class(.pseudo_class, PseudoClassSelector{ type_: .is_, argument_selector_list: SelectorList{ selectors: [
		nested_a,
		nested_b,
	] } })
	mut values := []SimpleSelector{}
	values << outer
	compact_selector_retained = unsafe { values }
	$if gcboehm ? {
		assert C.vox_compact_selector_array_kind(values.data) == 1
		C.vox_compact_selector_watch_owner(0, voidptr(nested_a.data_))
		C.vox_compact_selector_watch_owner(1, voidptr(nested_b.data_))
	}
}

fn compact_selector_verify_live_payload() {
	assert compact_selector_retained.len == 1
	assert compact_selector_retained[0].serialize() == ':is(.retained-one, .retained-two)'
}

fn compact_selector_replace_with_small_payload() {
	// This replaces the complete record, so no inactive old arm is retained.
	compact_selector_retained[0] = SimpleSelector.with_name(.class, SelectorName.new('new-small-payload'))
}

fn compact_selector_replace_with_empty_literal() {
 compact_selector_retained[0] = SimpleSelector{}
}

fn compact_selector_replace_with_empty_factory() {
 compact_selector_retained[0] = SimpleSelector.create(SimpleSelectorInit{})
}

fn test_compact_simple_selector_union_array_traces_sole_nested_owners_and_releases_overwritten_arm() {
 $if gcboehm ? {
  for overwrite in [compact_selector_replace_with_small_payload, compact_selector_replace_with_empty_literal, compact_selector_replace_with_empty_factory] {
   C.vox_compact_selector_run_worker(compact_selector_create_sole_owner)
   for _ in 0 .. 6 { C.vox_compact_selector_collect(8) }
   assert C.vox_compact_selector_alive_mask() == 3
   C.vox_compact_selector_run_worker(compact_selector_verify_live_payload)
   C.vox_compact_selector_run_worker(overwrite)
   for _ in 0 .. 8 { C.vox_compact_selector_collect(8) }
   assert C.vox_compact_selector_alive_mask() == 0
  }
  compact_selector_retained = []SimpleSelector{}

	} $else {
		compact_selector_create_sole_owner()
		compact_selector_verify_live_payload()
		compact_selector_replace_with_small_payload()
		assert compact_selector_retained[0].serialize() == '.new-small-payload'
		compact_selector_retained = []SimpleSelector{}
	}
}
