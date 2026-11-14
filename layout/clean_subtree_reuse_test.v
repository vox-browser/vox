module layout

import dom
import html

fn clean_subtree_handle(document &dom.Document, id string) voidptr {
	element := document.get_element_by_id(id) or { panic('missing #${id}') }
	return element.as_node().unsafe_layout_node() or { panic('missing layout for #${id}') }.real_layout_handle()
}

// A complete rebuild of the same DOM must paint exactly what the kept boxes do.
fn clean_subtree_check_full_rebuild(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing full paint') }).dump() == before
}

fn clean_subtree_rebuild_elsewhere(mut document dom.Document, index int) {
	mut changed := document.get_element_by_id('changed') or { panic('missing changed') }
	changed.set_inner_html('<p>new branch ${index}</p>') or { panic(err) }
	document.update_layout(.debugging)
}

const clean_subtree_stable_branches = [
	'<button id="inner" type="button">Press <b>me</b></button>',
	'<table><tbody><tr><td id="inner">cell</td><td>next</td></tr><tr><td colspan="2">wide</td></tr></tbody></table>',
	'<div style="position:relative"><span id="inner" style="position:absolute;top:2px;left:3px">badge</span>text</div>',
	'<style>.tag::before{content:"# ";color:green}.tag::after{content:"";display:block}</style><p id="inner" class="tag">heading</p>',
	'<ul><li>one</li><li id="inner" style="position:relative">two <a href="#x" style="position:absolute;right:0">link</a></li></ul>',
	'<div style="display:flex"><div style="display:inline-flex"><span id="inner">a</span><span>b</span></div><div style="flex:1">c</div></div>',
	'<details open><summary>More</summary><p id="inner">body</p></details>',
	'<p>before <svg id="inner" width="16" height="16" viewBox="0 0 16 16"><path d="M0 0h16v16H0z"></path></svg> after</p>',
]

// Boxes of branches the invalidation flags leave untouched survive a rebuild
// of another branch, whatever kinds of boxes they contain.
fn test_clean_branches_keep_their_boxes_across_rebuilds_elsewhere() {
	for branch in clean_subtree_stable_branches {
		mut document := html.parse_document('<!doctype html><body><div id="changed"></div><section id="stable">${branch}</section><p id="tail">tail</p></body>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		for index in 0 .. 3 {
			stable := clean_subtree_handle(document, 'stable')
			inner := clean_subtree_handle(document, 'inner')
			tail := clean_subtree_handle(document, 'tail')
			roots_before, boxes_before, _ := clean_subtree_reuse_statistics()
			clean_subtree_rebuild_elsewhere(mut document, index)
			roots_after, boxes_after, _ := clean_subtree_reuse_statistics()
			assert clean_subtree_handle(document, 'stable') == stable, branch
			assert clean_subtree_handle(document, 'inner') == inner, branch
			assert clean_subtree_handle(document, 'tail') == tail, branch
			assert roots_after > roots_before && boxes_after > boxes_before, branch
		}
		clean_subtree_check_full_rebuild(mut document)
	}
}

// Removing a child flags its parent: every box below that parent is rebuilt
// unless the separate validated salvage accepts it, which it does not for a
// button.
fn test_branches_below_a_flagged_parent_are_not_kept_on_the_flags_alone() {
	mut document := html.parse_document('<!doctype html><body><main id="parent"><div id="removed">gone</div><section id="stable"><button id="inner" type="button">Press</button></section></main></body>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	stable := clean_subtree_handle(document, 'stable')
	inner := clean_subtree_handle(document, 'inner')
	removed := document.get_element_by_id('removed')?
	mut removed_node := unsafe { &dom.Node(removed.as_node()) }
	removed_node.remove(false)
	document.update_layout(.debugging)
	assert clean_subtree_handle(document, 'stable') != stable
	assert clean_subtree_handle(document, 'inner') != inner
	clean_subtree_check_full_rebuild(mut document)
}

// Generated content derived from counters or quotes depends on the document
// order outside its branch; such branches keep the complete builder.
fn test_counter_and_quote_content_is_rebuilt_with_current_values() {
	for style in ['#stable p::before{content:counter(item) ". "} #changed p,#stable p{counter-increment:item}',
		'#stable p::before{content:open-quote} #stable p::after{content:close-quote}',
		'#stable li{list-style-type:decimal}'] {
		mut document := html.parse_document('<!doctype html><style>${style}</style><body><div id="changed"></div><section id="stable"><p id="inner">text</p><ol><li>item</li></ol></section></body>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		for index in 0 .. 2 {
			clean_subtree_rebuild_elsewhere(mut document, index)
			clean_subtree_check_full_rebuild(mut document)
		}
	}
}

// A display change is reported on the parent that owns the insertion, so the
// restyled branch and its siblings are rebuilt; later clean passes keep them.
fn test_restyled_branch_is_rebuilt_then_kept() {
	mut document := html.parse_document('<!doctype html><style>.row{display:flex}.gone{display:none}</style><body><div id="changed"></div><section id="stable"><button id="inner" type="button">Press</button><span>label</span></section></body>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	for class in ['row', 'gone', ''] {
		mut stable_element := document.get_element_by_id('stable')?
		stable_element.set_attribute_value('class', class)
		document.update_layout(.debugging)
		clean_subtree_check_full_rebuild(mut document)
		if class == 'gone' { continue }
		stable := clean_subtree_handle(document, 'stable')
		inner := clean_subtree_handle(document, 'inner')
		clean_subtree_rebuild_elsewhere(mut document, 0)
		assert clean_subtree_handle(document, 'stable') == stable
		assert clean_subtree_handle(document, 'inner') == inner
		clean_subtree_check_full_rebuild(mut document)
	}
}

// Text edits and insertions inside a kept branch flag that branch; the next
// pass rebuilds exactly it and paints the new content.
fn test_mutations_inside_a_kept_branch_are_painted() {
	mut document := html.parse_document('<!doctype html><body><div id="changed"></div><section id="stable"><table><tbody><tr><td id="inner">cell</td></tr></tbody></table><button type="button">Press</button></section><p id="tail">tail</p></body>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	clean_subtree_rebuild_elsewhere(mut document, 0)
	tail := clean_subtree_handle(document, 'tail')
	mut inner := document.get_element_by_id('inner')?
	inner.set_inner_html('edited <b>cell</b>') or { panic(err) }
	document.update_layout(.debugging)
	assert clean_subtree_handle(document, 'tail') == tail
	painted := (document.record_display_list() or { panic("missing paint") }).dump()
	assert painted.contains("edited")
	clean_subtree_check_full_rebuild(mut document)
}

// A style pass that replaces every computed style with an equal one, or that
// restyles a kept branch without changing its boxes, leaves the branch kept
// and painted like a complete rebuild.
fn test_kept_branches_follow_restyles_that_do_not_rebuild_boxes() {
	for branch in clean_subtree_stable_branches {
		mut document := html.parse_document('<!doctype html><style>.tint{color:rgb(200,0,0);background:rgb(240,240,255)}.wide{padding-left:7px}</style><body><div id="changed"></div><section id="stable">${branch}</section></body>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		for class in ['tint', 'tint wide', ''] {
			document.set_needs_full_style_update(true)
			document.update_style()
			mut stable_element := document.get_element_by_id('stable')?
			stable_element.set_attribute_value('class', class)
			stable := clean_subtree_handle(document, 'stable')
			clean_subtree_rebuild_elsewhere(mut document, 0)
			// A marker box is rebuilt once its ::marker style has been replaced.
			if !branch.contains('<li') && !branch.contains('<summary') {
				assert clean_subtree_handle(document, 'stable') == stable, branch
			}
			clean_subtree_check_full_rebuild(mut document)
		}
	}
}
