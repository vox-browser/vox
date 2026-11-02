module layout

import html

fn inline_float_fit_find(node &Node, id string) ?&Node {
	if owner := node.dom_node() {
		if element := owner.as_element() {
			if element.get_attribute_value('id') == id { return node }
		}
	}
	for child in node.children() {
		if found := inline_float_fit_find(child, id) { return found }
	}
	return none
}

fn test_later_float_that_fits_still_moves_inline_content_to_its_side() {
	for side in ['left', 'right'] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0;font:13px/19.5px Arial}
			#item{display:inline-block;width:100px;height:30px}
			#float{float:${side};width:100px;height:40px}
		</style><div id="item"></div><div id="float"></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 1024, 768) or { panic('layout') }
		item := inline_float_fit_find(result.root, 'item') or { panic('item') }
		styled := item.as_node_with_style() or { panic('style') }
		used := result.used_values_for(styled) or { panic('used') }
		assert used.offset.x().to_double() == if side == 'left' { 100.0 } else { 0.0 }
	}
}

fn test_inline_block_after_full_width_float_does_not_expand_document_overflow() {
	for prefix in ['', '<main style="height:2000px"></main>'] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:12px 13px;font:13px/19.5px Arial}
			.grid{width:99.8%;margin-left:.1%;margin-right:.1%;float:left;display:block}
			footer{height:35px}
			section{margin-left:120px;margin-right:336px;position:relative;top:-19px;
				margin-top:19px;min-width:478px;display:inline-block}
			blockquote{margin:0;height:55px}
		</style>${prefix}<footer class="grid"></footer>
		<section id="quote"><blockquote class="grid">A short quotation</blockquote></section>
		<footer class="grid"></footer>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 1024, 768) or { panic('layout') }
		quote := inline_float_fit_find(result.root, 'quote') or { panic('quote') }
		styled := quote.as_node_with_style() or { panic('style') }
		used := result.used_values_for(styled) or { panic('used') }
		assert used.offset.x().to_double() == 120
		assert used.content_width().to_double() == 478
		overflow := result.paint_tree.scrollable_overflow or { panic('overflow') }
		assert overflow.x + overflow.width == 1024
	}
}
