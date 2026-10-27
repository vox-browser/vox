module css

import dom
import platform

struct InheritanceProofFixture {
mut:
	document &dom.Document
	source &ComputedProperties
	target &ComputedProperties
	proof &LayoutInheritanceProof
}

fn inheritance_proof_fixture() &InheritanceProofFixture {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	mut source := computed_properties_with_initial_values()
	mut target := computed_properties_with_initial_values()
	_ = resolve_computed_values_for_document(source, document)
	_ = resolve_computed_values_for_document(target, document)
	mut target_values := unsafe { &MutableComputedValues(target) }
	target_values.inherit_from(unsafe { &ComputedValues(source) })
	proof := refresh_layout_inheritance_proof(unsafe { nil }, target, source, document)
	allocations.finish()
	return &InheritanceProofFixture{document: document, source: source, target: target, proof: proof}
}

fn (mut fixture InheritanceProofFixture) finish() {
	owner := fixture.document.native_storage()
	fixture.document.finalize()
	fixture.document.release_native_storage()
	$if prealloc {
		for _ in 0 .. 100 {
			if owner.arena.usage().capacity == 0 { break }
			platform.pump_native_events(0.01)
		}
		assert owner.arena.usage().capacity == 0
	}
}

fn test_layout_inheritance_proof_observes_raw_flags_fonts_context_and_resolved_values() {
	mut fixture := inheritance_proof_fixture()
	defer { fixture.finish() }
	mut allocations := fixture.document.enter_native_storage()
	defer { allocations.finish() }
	mut source := fixture.source
	mut source_values := unsafe { &MutableComputedValues(source) }
	source_immutable := unsafe { &ComputedValues(source) }
	mut target := fixture.target
	mut target_values := unsafe { &MutableComputedValues(target) }
	document := fixture.document
	proof := fixture.proof
	assert layout_inheritance_is_current(proof, target, source, document)
	assert voidptr(target.cached_computed_font_list_owner_) == voidptr(source.cached_computed_font_list_owner_)
	target.set_property_important(.color, .yes)
	assert !layout_inheritance_is_current(proof, target, source, document)
	target.set_property_important(.color, .no)
	assert !layout_inheritance_is_current(proof, target, source, document)
	_ = refresh_layout_inheritance_proof(proof, target, source, document)
	assert layout_inheritance_is_current(proof, target, source, document)
	target.set_property_inherited(.color, .no)
	assert !layout_inheritance_is_current(proof, target, source, document)
	target.set_property_inherited(.color, .yes)
	assert !layout_inheritance_is_current(proof, target, source, document)
	_ = refresh_layout_inheritance_proof(proof, target, source, document)
	assert layout_inheritance_is_current(proof, target, source, document)

	source.cached_computed_font_list_generation_++
	assert !layout_inheritance_is_current(proof, target, source, document)
	source.cached_computed_font_list_generation_--
	source.root_font_size_px_ += 1
	assert !layout_inheritance_is_current(proof, target, source, document)
	source.root_font_size_px_ -= 1
	target.computed_values_line_height_ = target.computed_values_line_height_.scaled(2)
	assert !layout_inheritance_is_current(proof, target, source, document)
	target_values.inherit_from(source_immutable)
	_ = refresh_layout_inheritance_proof(proof, target, source, document)
	assert layout_inheritance_is_current(proof, target, source, document)

	source.set_property(.color, &dom.StyleValue{css_text: 'blue'}, .no, .no)
	assert !layout_inheritance_is_current(proof, target, source, document)
	target_values.inherit_from(source_immutable)
	_ = refresh_layout_inheritance_proof(proof, target, source, document)
	assert layout_inheritance_is_current(proof, target, source, document)
	source_values.set_color(Color{10, 20, 30, 255})
	assert !layout_inheritance_is_current(proof, target, source, document)
}

fn test_layout_inheritance_proof_freezes_snapshots_before_later_animation_reuse() {
	mut fixture := inheritance_proof_fixture()
	defer { fixture.finish() }
	mut allocations := fixture.document.enter_native_storage()
	defer { allocations.finish() }
	mut source := fixture.source
	mut source_values := unsafe { &MutableComputedValues(source) }
	source_immutable := unsafe { &ComputedValues(source) }
	before := source.computed_layout_cache_
	previous_color := source_immutable.color()
	previous := begin_layout_cache_reuse(source)
	source_values.set_color(Color{31, 63, 95, 255})
	end_layout_cache_reuse(previous)
	assert voidptr(before) != voidptr(source.computed_layout_cache_)
	assert before.computed_values_color_ == previous_color
	assert !layout_inheritance_is_current(fixture.proof, fixture.target, source, fixture.document)
}

fn test_layout_inheritance_proof_compares_counter_definitions_and_rejects_mutable_font_variations() {
	mut fixture := inheritance_proof_fixture()
	defer { fixture.finish() }
	mut allocations := fixture.document.enter_native_storage()
	defer { allocations.finish() }
	mut source := fixture.source
	mut source_values := unsafe { &MutableComputedValues(source) }
	source_immutable := unsafe { &ComputedValues(source) }
	mut target := fixture.target
	mut target_values := unsafe { &MutableComputedValues(target) }
	mut counter := CounterStyle.decimal()
	source_values.set_list_style_type(ListStyleType{kind: .counter_style, name: 'test', counter_style: counter})
	target_values.inherit_from(source_immutable)
	proof := refresh_layout_inheritance_proof(fixture.proof, target, source, fixture.document)
	assert layout_inheritance_is_current(proof, target, source, fixture.document)
	counter.suffix_ = ' changed'
	source_values.set_list_style_type(ListStyleType{kind: .counter_style, name: 'test', counter_style: counter})
	assert !layout_inheritance_is_current(proof, target, source, fixture.document)
	target_values.inherit_from(source_immutable)
	_ = refresh_layout_inheritance_proof(proof, target, source, fixture.document)
	source_values.set_font_variation_settings({'wght': f64(525)})
	target_values.inherit_from(source_immutable)
	_ = refresh_layout_inheritance_proof(proof, target, source, fixture.document)
	assert !layout_inheritance_is_current(proof, target, source, fixture.document)
	assert voidptr(target.font_variation_storage_) != voidptr(source.font_variation_storage_)
}
