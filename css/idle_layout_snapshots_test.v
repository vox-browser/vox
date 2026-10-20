module css

import dom

#include "computed_property_store_test.h"

$if gcboehm ? {
	fn C.vox_property_store_watch(index u32, owner voidptr)
	fn C.vox_property_store_collect(depth u32)
	fn C.vox_property_store_worker(work fn ())
	fn C.vox_property_store_alive() u32
	__global idle_snapshot_surviving_style_ &ComputedProperties
}

fn idle_snapshot_style() &ComputedProperties {
	style := computed_properties_with_initial_values()
	_ = resolve_computed_values(style)
	return style
}

fn test_idle_snapshot_sharing_preserves_independent_writes_and_value_copies() {
	mut first := idle_snapshot_style()
	mut second := idle_snapshot_style()
	mut first_values := unsafe { &MutableComputedValues(first) }
	mut second_values := unsafe { &MutableComputedValues(second) }
	assert voidptr(first.computed_layout_cache()) != voidptr(second.computed_layout_cache())
	assert share_idle_layout_snapshots([first, second, first]) == 1
	snapshot := first.computed_layout_cache()
	assert voidptr(snapshot) == voidptr(second.computed_layout_cache())
	assert snapshot.owner_serial == 0
	assert snapshot.owner_identity == 0
	assert voidptr(snapshot.resolution_provenance) == unsafe { nil }
	copy := &ComputedProperties{...first}
	first_values.set_color(Color{1, 2, 3, 255})
	assert first_values.color() == Color{1, 2, 3, 255}
	assert second_values.color() == Color{0, 0, 0, 255}
	assert copy.computed_layout_cache().computed_values_color_ == second_values.color()
	assert voidptr(first.computed_layout_cache()) != voidptr(snapshot)
	second_values.set_width(Size.make_length(Length.make_px(73)))
	width_changed := second_values.width() != copy.computed_layout_cache().computed_values_width_
	assert width_changed
	assert voidptr(second.computed_layout_cache()) != voidptr(snapshot)
	assert share_idle_layout_snapshots([copy, copy]) == 0
}

fn test_idle_snapshot_sharing_checks_values_outside_its_coarse_hash() {
	first := idle_snapshot_style()
	mut second := idle_snapshot_style()
	mut second_values := unsafe { &MutableComputedValues(second) }
	second_values.set_width(Size.make_length(Length.make_px(37)))
	assert share_idle_layout_snapshots([first, second]) == 0
	second_values.set_width(first.computed_layout_cache().computed_values_width_)
	second_values.set_opacity(.5)
	assert share_idle_layout_snapshots([first, second]) == 0
	second_values.set_opacity(first.computed_layout_cache().computed_values_opacity_)
	assert share_idle_layout_snapshots([first, second]) == 1
}

fn test_idle_snapshot_sharing_leaves_unresolved_rare_and_writable_styles_local() {
	mut first := idle_snapshot_style()
	mut second := idle_snapshot_style()
	mut second_values := unsafe { &MutableComputedValues(second) }
	unresolved := computed_properties_with_initial_values()
	assert share_idle_layout_snapshots([unresolved, first, second]) == 1
	assert voidptr(unresolved.computed_layout_cache_) == unsafe { nil }
	second_values.set_transform_box(.border_box)
	assert share_idle_layout_snapshots([first, second]) == 0
	third := idle_snapshot_style()
	owned := first.begin_computed_layout_cache_write()
	assert share_idle_layout_snapshots([first, third]) == 0
	first.finish_computed_layout_cache_write(owned)
	assert share_idle_layout_snapshots([first, third]) == 1
}

fn test_idle_shared_snapshot_reresolves_against_each_raw_graph_and_document() {
	mut document := dom.Document.create(dom.URL{value: 'https://idle-snapshot.test/'})
	defer { document.finalize() }
	mut first := computed_properties_with_initial_values()
	mut second := computed_properties_with_initial_values()
	_ = resolve_computed_values_for_document(first, document)
	_ = resolve_computed_values_for_document(second, document)
	assert voidptr(first.computed_layout_cache().resolution_provenance) != unsafe { nil }
	assert voidptr(second.computed_layout_cache().resolution_provenance) != unsafe { nil }
	assert share_idle_layout_snapshots([first, second]) == 1
	snapshot := first.computed_layout_cache()
	assert voidptr(snapshot.resolution_provenance) == unsafe { nil }
	assert voidptr(snapshot.document_resolution_owner) == unsafe { nil }
	width := parse_css_value(ParsingParams{}, '71px', .width) or { panic('missing width') }
	second.set_property(.width, width, .no, .no)
	values := resolve_computed_values_for_document(second, document)
	width_matches := values.width() == Size.make_length(Length.make_px(71))
	assert width_matches
	assert voidptr(second.computed_layout_cache()) != voidptr(snapshot)
	assert second.computed_layout_cache().resolution_provenance.matches(second)
	assert voidptr(second.computed_layout_cache().document_resolution_owner) == voidptr(document)
	first_width_unchanged := first.computed_layout_cache().computed_values_width_ != values.width()
	assert first_width_unchanged
	assert snapshot.owner_serial == 0
}

fn prepare_shared_snapshot_owner_lifetime() {
	$if gcboehm ? {
		mut first := ComputedProperties.new()
		mut second := ComputedProperties.new()
		mut first_values := unsafe { &MutableComputedValues(first) }
		mut second_values := unsafe { &MutableComputedValues(second) }
		first_values.set_color(Color{1, 2, 3, 255})
		second_values.set_color(Color{1, 2, 3, 255})
		assert share_idle_layout_snapshots([first, second]) == 1
		C.vox_property_store_watch(0, voidptr(first))
		C.vox_property_store_watch(1, voidptr(second.computed_layout_cache()))
		idle_snapshot_surviving_style_ = second
	}
}

fn clear_shared_snapshot_owner_lifetime() {
	$if gcboehm ? { idle_snapshot_surviving_style_ = unsafe { nil } }
}

fn test_idle_shared_snapshot_does_not_retain_an_obsolete_owner() {
	$if gcboehm ? {
		C.vox_property_store_worker(prepare_shared_snapshot_owner_lifetime)
		C.vox_property_store_collect(8)
		C.vox_property_store_collect(8)
		assert C.vox_property_store_alive() & 3 == 2
		C.vox_property_store_worker(clear_shared_snapshot_owner_lifetime)
		C.vox_property_store_collect(8)
		C.vox_property_store_collect(8)
		assert C.vox_property_store_alive() & 3 == 0
	}
}
