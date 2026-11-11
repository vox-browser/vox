module main

import css
import dom
import html
import layout

fn test_outer_part_rules_generate_and_size_shadow_pseudo_elements() {
	for example in [
		['div', '::before{display:block;content:"";height:46px}', '46'],
		['div', '::after{display:block;content:"";height:77px}', '77'],
		['details', '::details-content{height:371px}', '418'],
	] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><div id="host"></div>')
		mut host := document.get_element_by_id('host') or { panic('host') }
		shadow := host.attach_shadow(dom.ShadowRootInit{mode:.open})!
		mut part := document.create_element_ns(dom.namespace_html_uri, example[0])!
		part.set_attribute_value('part', 'label')
		if example[0] == 'details' {
			mut summary := document.create_element_ns(dom.namespace_html_uri, 'summary')!
			summary.set_attribute_value('style', 'height:47px')
			mut part_node := part.as_node()
			part_node.append_child(summary.as_node())!
		}
		mut shadow_node := shadow.as_node()
		shadow_node.append_child(part.as_node())!
		css.add_document_author_style_sheet(document, '::part(label)${example[1]}')
		_ = layout.layout_document_typed_in_viewport(document, 400, 300)
		r := host.get_bounding_client_rect()
		assert r.height == example[2].f64(), '${example[1]}: ${r.height}'
		document.finalize()
	}
}
