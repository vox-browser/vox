module layout

import css

fn test_generated_content_snapshots_are_per_node_and_keep_explicit_empty_alternatives() {
	mut first := &NodeWithStyle{ Node:Node{has_style_:true} }
	mut second := &NodeWithStyle{ Node:Node{has_style_:true} }
	first.set_content(css.ContentData{ type_:.list, text:'visual', has_alt_text:true, alt_text:'1' })
	second.set_content(css.ContentData{ type_:.list, text:'visual', has_alt_text:true, alt_text:'2' })
	old := *first
	first.set_content(css.ContentData{ type_:.list, text:'visual', has_alt_text:true })
	assert old.content()?.alt_text == '1'
	assert second.content()?.alt_text == '2'
	assert first.content()?.has_alt_text
	assert layout_generated_accessible_text(voidptr(first))? == ''
	assert layout_generated_accessible_text(voidptr(second))? == '2'
	first.set_content(css.ContentData{ type_:.list, text:'painted' })
	assert layout_generated_accessible_text(voidptr(first))? == 'painted'
}
