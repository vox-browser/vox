module layout

import html

fn test_accessible_marker_names_use_default_ordinals_and_alternatives() {
	mut document := html.parse_document('<!doctype html><style>#custom::marker{content:"* "}#alt::marker{content:"x" / "Bullet"}#empty::marker{content:"x" / ""}#summarycustom::marker{content:"visual "}</style><ul><li id="bullet">item</li><li id="custom">custom</li><li id="alt">alternative</li><li id="empty">empty</li></ul><ol start="7"><li id="ordinal">number</li></ol><button id="a" aria-labelledby="bullet"></button><button id="b" aria-labelledby="custom"></button><button id="c" aria-labelledby="alt"></button><button id="d" aria-labelledby="empty"></button><button id="e" aria-labelledby="ordinal"></button><details><summary id="summary" title="tooltip">contents</summary></details><details open><summary id="summaryopen">open contents</summary></details><details><summary id="summarycustom">custom contents</summary></details>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	for id, expected in {'a':'• item', 'b':'* custom', 'c':'Bullet alternative', 'd':'empty', 'e':'7. number', 'summary':'contents', 'summaryopen':'open contents', 'summarycustom':'custom contents'} {
		element := document.get_element_by_id(id) or { panic('missing fixture') }
		actual := element.as_node().accessible_name(document, .yes)!.fields().join(' ')
		assert actual == expected
	}
}
