module layout

import dom
import html

fn static_generated_box(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing #${id}') }
	mirror := element.as_node().unsafe_layout_node() or { panic('missing layout for #${id}') }
	return unsafe { &Node(mirror.real_layout_handle()) }
}

fn static_generated_blocked(document &dom.Document, id string) bool {
	result := document_layout_result(document) or { panic('missing layout result') }
	box := static_generated_box(document, id)
	return subtree_reuse_blocked(result.state, box, box)
}

fn static_generated_check_full_rebuild(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing full paint') }).dump() == before
}

// Bullets and authored strings depend on nothing outside their box, so the
// committed layout of a clean subtree containing them can be restored.
// Ordinals, counters and quotes still run through layout again.
fn test_only_counter_and_quote_content_blocks_committed_subtree_reuse() {
	cases := {
		'<ul id="box"><li>one</li><li>two</li></ul>':                                              false
		'<ul id="box" style="list-style-type:square"><li>one</li></ul>':                           false
		'<style>.s::before{content:"> "}.s::after{content:""}</style><div id="box"><p class="s">text</p></div>': false
		'<ol id="box"><li>one</li><li>two</li></ol>':                                              true
		'<style>.c{counter-increment:n}.c::before{content:counter(n) ". "}</style><div id="box"><p class="c">text</p></div>': true
		'<style>.q::before{content:open-quote}</style><div id="box"><p class="q">text</p></div>':   true
	}
	for content, blocked in cases {
		mut document := html.parse_document('<!doctype html><body><p id="changed">first</p><section id="stable">${content}</section></body>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		assert static_generated_blocked(document, 'box') == blocked, content
		assert static_generated_blocked(document, 'stable') == blocked, content
	}
}

// Restored subtrees with static generated content paint exactly like a
// complete layout after changes elsewhere, with and without a tree rebuild.
fn test_subtrees_with_static_generated_content_match_a_complete_layout() {
	for content in ['<ul><li>one</li><li>two <b>bold</b></li></ul>',
		'<style>.s::before{content:"> ";color:green}.s::after{content:"";display:block;height:3px}</style><div><p class="s">text</p><p class="s">more</p></div>',
		'<ol><li>one</li><li>two</li></ol>',
		'<style>.c{counter-increment:n}.c::before{content:counter(n) ". "}</style><div><p class="c">text</p></div>'] {
		mut document := html.parse_document('<!doctype html><style>#changed.tall{padding-top:9px}</style><body><p id="changed" class="c">first</p><section id="stable" style="display:flow-root">${content}</section><p>tail</p></body>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		// Subtree reuse restores independent formatting contexts.
		reusable := !static_generated_blocked(document, 'stable')
		mut changed := document.get_element_by_id('changed')?
		for index in 0 .. 3 {
			reused_before := incremental_layout_reused_subtree_count()
			if index == 1 {
				changed.set_attribute_value('class', 'c tall')
			} else {
				changed.set_inner_html('branch <i>${index}</i>') or { panic(err) }
			}
			document.update_layout(.debugging)
			if reusable {
				assert incremental_layout_reused_subtree_count() > reused_before, content
			}
			static_generated_check_full_rebuild(mut document)
		}
	}
}
