module layout

import html

fn test_accessible_names_follow_aria_owns_order_visibility_and_cycles() {
	mut document := html.parse_document('<!doctype html><button id="playbutton" aria-owns="play"><div aria-hidden="true"><span id="play">Play</span><span>Pause</span></div></button><a id="link" href="#" aria-owns="extra">base </a><div aria-hidden="true"><span id="extra"> extra</span></div><span aria-owns="car"></span><h4 id="heading">Speeding <mark id="car">car</mark></h4><h3 id="hiddenowner"><span hidden aria-owns="treasure">ignored</span><mark id="treasure">treasure</mark></h3><button id="hidden-target" aria-owns="hidden-target-text">visible</button><div hidden><span id="hidden-target-text">hidden</span></div><button id="aria-target" aria-owns="aria-target-text">visible</button><span id="aria-target-text" aria-hidden="true">hidden</span><div role="button" id="order" aria-owns="b a b"><div id="a">A</div><div id="b">B</div><div>tail</div></div><div role="button" id="cycle-a" aria-owns="cycle-b">A</div><div role="button" id="cycle-b" aria-owns="cycle-a">B</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	for id, expected in {'playbutton':'Play', 'link':'base extra', 'heading':'Speeding', 'hiddenowner':'treasure', 'hidden-target':'visible', 'aria-target':'visible', 'order':'tail B A', 'cycle-a':'A B', 'cycle-b':'B'} {
		element := document.get_element_by_id(id) or { panic('missing fixture') }
		actual := element.as_node().accessible_name(document, .yes)!.fields().join(' ')
		assert actual == expected, id + ': ' + actual
	}
}
