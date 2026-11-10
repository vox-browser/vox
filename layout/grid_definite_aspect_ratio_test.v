// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module layout

import dom
import html

// Definite/fixed-row paths from Ladybird 56f9461b3d6d and 8660dc09cd3c.
fn test_grid_normal_alignment_transfers_definite_height_through_aspect_ratio() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for height in ['40px', '50%'] {
			for alignment in ['normal', 'stretch'] {
				mut document := html.parse_document('<!doctype html><style>body{margin:0}
					#grid{display:grid;width:200px;grid-template-rows:80px}
					#item{height:${height};aspect-ratio:2;justify-self:${alignment}}
					</style><div id="grid"><div id="item"></div></div>')
				defer { document.finalize() }
				document.set_font_rendering_policy(policy)
				_ = layout_document_typed_in_viewport(document, 800, 600)
				rect := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
				assert rect.width == if alignment == 'stretch' { 200.0 } else { 80.0 }
				assert rect.height == 40
			}
		}
	}
}

fn test_grid_normal_block_alignment_preserves_an_automatic_aspect_ratio_height() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for alignment in ['normal', 'stretch'] {
			mut document := html.parse_document('<!doctype html><style>body{margin:0}
				#grid{display:grid;width:200px;grid-template-rows:160px}
				#item{width:100px;aspect-ratio:2;align-self:${alignment}}
				</style><div id="grid"><div id="item"></div></div>')
			defer { document.finalize() }
			document.set_font_rendering_policy(policy)
			_ = layout_document_typed_in_viewport(document, 800, 600)
			rect := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
			assert rect.width == 100
			assert rect.height == if alignment == 'stretch' { 160.0 } else { 50.0 }
		}
	}
}

fn test_grid_definite_height_transfer_respects_border_box_ratio_and_height_limits() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}
		#grid{display:grid;width:240px;grid-template-rows:100px}
		#item{height:80px;max-height:60px;aspect-ratio:2;box-sizing:border-box;padding:5px;border:5px solid}
		</style><div id="grid"><div id="item"></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 800, 600)
	rect := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
	assert rect.width == 120
	assert rect.height == 60
}
