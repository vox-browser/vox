module layout

import dom
import html
import os

fn min_height_probe_matches_full_rebuild(mut document dom.Document, label string) {
	before := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('full paint') }).dump() == before, label
}

fn min_height_probe_shell(rows int) &dom.Document {
	mut paragraphs := []string{}
	for index in 0 .. rows {
		paragraphs << '<p id="p${index}">row ${index} <a href="#">link</a></p>'
	}
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:16px/20px sans-serif}p{margin:4px 0}#app{display:flex;flex-direction:column;min-height:100vh}header{display:flex;gap:8px;border-bottom:1px solid}main{flex:1;border:2px solid}footer{height:30px;border-top:1px solid}</style><body><div id="app"><header><span>logo</span><nav><a href="#">one</a><a href="#">two</a></nav></header><main id="main"><div id="deep"><section id="rows">${paragraphs.join('')}</section></div></main><footer>end</footer></div></body>')
	_ = layout_document_typed_in_viewport(document, 800, 600)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	return document
}

// An app shell with `min-height: 100vh` and taller content: its min-height
// probe matched its real layout, so a change inside the page that keeps the
// heights relays out from a root below the shell instead of running the
// complete pass.
fn test_changes_inside_a_tall_min_height_shell_relayout_incrementally() {
	mut document := min_height_probe_shell(60)
	defer { document.finalize() }
	enabled := os.getenv('VOX_RETAIN_MIN_HEIGHT_PROBE_MARKS') == ''
		&& os.getenv('VOX_DISABLE_INCREMENTAL_LAYOUT') == ''
	if enabled {
		assert min_height_probe_cleared_mark_count() > 0
	}
	for step in ['style', 'text', 'insert'] {
		before := incremental_layout_pass_count()
		match step {
			'style' {
				mut deep := document.get_element_by_id('deep') or { panic('deep') }
				deep.set_attribute_value('style', 'padding-left:3px')
			}
			'text' {
				mut row := document.get_element_by_id('p7') or { panic('p7') }
				mut text := row.as_node().first_child() or { panic('text') }
				text.set_node_value('row 7, edited ') or { panic(err) }
			}
			else {
				mut row := document.get_element_by_id('p9') or { panic('p9') }
				mut extra := document.create_element('b') or { panic(err) }
				extra.as_node().append_child(document.create_text_node('new').as_node()) or { panic(err) }
				row.as_node().append_child(extra.as_node()) or { panic(err) }
			}
		}
		document.update_layout(.debugging)
		if enabled {
			assert incremental_layout_pass_count() > before, step
		}
		min_height_probe_matches_full_rebuild(mut document, step)
	}
}

// Content shorter than the minimum: the real layout used the minimum, so the
// probe keeps its marks; changes still lay out exactly as a rebuild.
fn test_changes_inside_a_short_min_height_shell_match_a_rebuild() {
	mut document := min_height_probe_shell(3)
	defer { document.finalize() }
	mut row := document.get_element_by_id('p1') or { panic('p1') }
	mut text := row.as_node().first_child() or { panic('text') }
	text.set_node_value('a longer first row') or { panic(err) }
	document.update_layout(.debugging)
	min_height_probe_matches_full_rebuild(mut document, 'short')
}

// Removing content until the shell is shorter than its minimum changes the
// probe's outcome: the main area must grow to fill the minimum again.
fn test_content_falling_below_the_minimum_matches_a_rebuild() {
	mut document := min_height_probe_shell(60)
	defer { document.finalize() }
	mut rows := document.get_element_by_id('rows') or { panic('rows') }
	for index in 2 .. 60 {
		mut row := document.get_element_by_id('p${index}') or { panic('p${index}') }
		rows.as_node().remove_child(row.as_node()) or { panic(err) }
	}
	document.update_layout(.debugging)
	min_height_probe_matches_full_rebuild(mut document, 'shrunk')
}
