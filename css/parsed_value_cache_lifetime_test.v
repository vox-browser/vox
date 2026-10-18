module css

import dom

#include "parsed_value_cache_lifetime_test.h"

fn C.vox_css_cache_storage_id() u64
fn C.vox_css_cache_length() int
fn C.vox_css_cache_value_id(raw_value voidptr) u64
$if gcboehm ? {
	fn C.vox_css_cache_watch_owner(owner voidptr)
	fn C.vox_css_cache_owner_alive() int
	fn C.vox_css_cache_collect(depth u32)
	fn C.vox_css_cache_run_worker(work fn ())
}

fn test_parsed_value_cache_reuses_entries_and_detaches_storage_at_each_boundary() {
	begin_selector_parse_cache()
	assert css_parsed_value_cache_enabled
	first := parse_css_value_logic(.width, '17px') or { panic('missing width') }
	assert first.serialize(.normal) == '17px'
	assert C.vox_css_cache_length() == 1
	again := parse_css_value_logic(.width, '17px') or { panic('missing cached width') }
	assert C.vox_css_cache_value_id(voidptr(&first)) == C.vox_css_cache_value_id(voidptr(&again))
	storage := C.vox_css_cache_storage_id()
	end_selector_parse_cache()
	assert !css_parsed_value_cache_enabled
	assert C.vox_css_cache_length() == 0
	assert C.vox_css_cache_storage_id() != storage
	assert first.serialize(.normal) == '17px' && again.serialize(.normal) == '17px'
	assert (parse_css_value_logic(.width, '17px') or { panic('missing uncached parse') }).serialize(.normal) == '17px'
	assert C.vox_css_cache_length() == 0
}

fn test_nested_parse_cache_boundaries_preserve_returned_values_and_existing_enable_policy() {
	begin_selector_parse_cache()
	value := parse_css_value_logic(.width, 'calc(13px + 2%)') or { panic('missing value') }
	outer_storage := C.vox_css_cache_storage_id()
	begin_selector_parse_cache()
	assert css_parsed_value_cache_enabled && C.vox_css_cache_length() == 0
	assert C.vox_css_cache_storage_id() != outer_storage
	_ = parse_css_value_logic(.height, '7px') or { panic('missing inner value') }
	end_selector_parse_cache()
	assert !css_parsed_value_cache_enabled && C.vox_css_cache_length() == 0
	$if gcboehm ? { C.vox_css_cache_collect(8) }
	assert value.serialize(.normal).contains('13px') && value.serialize(.normal).contains('2%')
	end_selector_parse_cache()
	assert !css_parsed_value_cache_enabled && C.vox_css_cache_length() == 0
}

@[noinline]
fn parsed_cache_retain_only_image_owner() {
	// Construct the owner without initialize(): its separate cursor callback
	// lifetime must not act as a second root in this cache ownership test.
	// The real Document/Selection cycle remains owned solely by the cached image.
	mut document := &dom.Document{}
	document.node_type = .document_node
	document.document_ = document
	document.is_connected_ = true
	document.selection_ = dom.Selection.create(document)
	mut image := parse_css_value_logic(.list_style_image, 'url(retained.svg)') or { panic('missing cached image') }
	if mut image is ImageStyleValue {
		image.document_ = document
	} else {
		panic('expected image value')
	}
	$if gcboehm ? { C.vox_css_cache_watch_owner(voidptr(document)) }
	document.finalize()
}

fn parsed_cache_release_owner() {
	end_selector_parse_cache()
}

fn test_ending_parse_cache_releases_its_only_image_document_owner() {
	begin_selector_parse_cache()
	$if gcboehm ? {
		C.vox_css_cache_run_worker(parsed_cache_retain_only_image_owner)
	} $else {
		parsed_cache_retain_only_image_owner()
	}
	assert C.vox_css_cache_length() == 1
	$if gcboehm ? {
		C.vox_css_cache_collect(8)
		assert C.vox_css_cache_owner_alive() == 1
	}
	$if gcboehm ? {
		C.vox_css_cache_run_worker(parsed_cache_release_owner)
	} $else {
		parsed_cache_release_owner()
	}
	assert C.vox_css_cache_length() == 0
	$if gcboehm ? {
		C.vox_css_cache_collect(8)
		C.vox_css_cache_collect(8)
		assert C.vox_css_cache_owner_alive() == 0
	}
}
