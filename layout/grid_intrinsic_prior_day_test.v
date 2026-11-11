// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module layout

import dom
import html

fn prior_day_grid_columns(document &dom.Document, id string) []f64 {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	node := element.as_node().layout_node() or { panic('missing ${id} layout') }
	return node.used_grid_data().columns
}

// Ladybird 7fdd515b8492cc4080e7d1567a83f11b82546f30.
fn test_scroll_containers_retain_their_min_content_track_contribution() {
	for chromium in [false, true] {
		mut document := html.parse_document('<!doctype html><style>
			#grid{display:grid;grid-template-columns:1fr min-content 1fr;width:200px}
			.item{grid-column:2;display:flex;overflow:hidden}.content{width:58px;height:58px}
		</style><div id="grid"><div class="item"><div class="content"></div></div></div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		_ = layout_document_typed_in_viewport(document, 800, 600)
		assert prior_day_grid_columns(document, 'grid') == [71.0, 58.0, 71.0]
	}
}

// Ladybird fb6ad7dba03d6336417c583d93c91579f9f6d7e8.
fn test_min_content_grid_constraints_keep_item_minimum_contributions() {
	for chromium in [false, true] {
		mut document := html.parse_document('<!doctype html><style>
			.grid{display:grid;width:min-content;grid-template-columns:auto}.box{width:60px;height:20px}
		</style><div class="grid" id="minimum"><div style="min-width:50px"><div class="box"></div></div></div>
		<div class="grid" id="percentage"><div style="min-width:150%"><div class="box"></div></div></div>
		<div class="grid" id="scroll"><div style="overflow:hidden"><div class="box"></div></div></div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		_ = layout_document_typed_in_viewport(document, 800, 600)
		assert prior_day_grid_columns(document, 'minimum') == [50.0]
		assert prior_day_grid_columns(document, 'percentage') == [0.0]
		assert prior_day_grid_columns(document, 'scroll') == [0.0]
	}
}

// Ladybird f260091d7d3d06a38b6d8221c63b3e869c64d7b7.
fn test_zero_flex_and_min_content_maximum_do_not_grow_under_max_content() {
	for chromium in [false, true] {
		mut document := html.parse_document('<!doctype html><style>
			.grid{display:grid;width:max-content}.box{display:inline-block;width:40px;height:20px;vertical-align:top}
		</style><div class="grid" id="span" style="grid-template-columns:0fr 0fr"><div style="grid-column:span 2"><span class="box"></span><span class="box"></span></div></div>
		<div class="grid" id="single" style="grid-template-columns:0fr"><div><span class="box"></span><span class="box"></span></div></div>
		<div class="grid" id="maximum" style="grid-template-columns:minmax(auto,min-content)"><div><span class="box"></span><span class="box"></span></div></div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		_ = layout_document_typed_in_viewport(document, 800, 600)
		assert prior_day_grid_columns(document, 'span') == [0.0, 0.0]
		assert prior_day_grid_columns(document, 'single') == [40.0]
		assert prior_day_grid_columns(document, 'maximum') == [40.0]
	}
}

// Ladybird 9c6ce29e8df242fa338a6e81dd9f37d1e8619879.
fn test_fixed_grid_automatic_minimum_leaves_room_for_outer_edges() {
	for chromium in [false, true] {
		mut document := html.parse_document('<!doctype html><style>
			.grid{display:grid;grid-template-columns:minmax(auto,50px);width:300px}.box{width:58px;height:20px}
		</style><div class="grid" id="margin"><div style="margin:5px"><div class="box"></div></div></div>
		<div class="grid" id="padding"><div style="padding:7px"><div class="box"></div></div></div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		_ = layout_document_typed_in_viewport(document, 800, 600)
		assert prior_day_grid_columns(document, 'margin') == [50.0]
		assert prior_day_grid_columns(document, 'padding') == [50.0]
	}
}

// Ladybird 717b2a5ddfbfb35bd662c96b0471e60f3885600a.
fn test_fit_content_grid_items_contribute_intrinsic_sizes() {
	for chromium in [false, true] {
		mut document := html.parse_document('<!doctype html><style>
			.grid{display:grid;width:200px}.item{width:fit-content}.box{display:inline-block;width:40px;height:40px}
		</style><div class="grid" id="minimum" style="grid-template-columns:min-content"><div class="item"><span class="box"></span><span class="box"></span></div></div>
		<div class="grid" id="flex" style="width:min-content;grid-template-columns:1fr 1fr"><div class="item" style="grid-column:span 2"><span class="box"></span></div></div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		_ = layout_document_typed_in_viewport(document, 800, 600)
		assert prior_day_grid_columns(document, 'minimum') == [40.0]
		assert prior_day_grid_columns(document, 'flex') == [0.0, 0.0]
	}
}
