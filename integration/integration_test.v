module integration

import html
import css
import layout
import dom

// Full-stack integration: parse an HTML string with the html parser, then query the resulting DOM
// tree with the css selector engine. Exercises html + dom + css composing end to end.

fn test_parse_then_query() {
	doc := html.parse_document('<body><div id="a"><p class="x">hello</p><p class="y">world</p><a href="u">link</a></div></body>')
	root := unsafe { &dom.Node(doc) }

	// Type selector (case-insensitive for HTML elements).
	assert css.query_selector_all(root, 'p').len == 2

	// Class selector on a parser-created element.
	p := css.query_selector(root, 'p.y') or { panic('no p.y') }
	assert (p.get_attribute('class') or { '' }) == 'y'
	assert (p.text_content() or { '' }) == 'world'

	// Id selector.
	div := css.query_selector(root, '#a') or { panic('no #a') }
	assert div.local_name() == 'div'

	// Attribute + descendant combinator.
	link := css.query_selector(root, 'div a[href]') or { panic('no link') }
	assert (link.get_attribute('href') or { '' }) == 'u'

	// closest walks up parser-built ancestors.
	assert (css.closest_matching_selector(link, '#a') or { panic('no closest') }).local_name() == 'div'
}

// Broader integration: the CSS selector engine + inline-style (declaration) parsing over a
// parser-built DOM. NOTE: full computed style (cascade + inheritance) is stubbed in this port, but
// inline/specified style — one cascade origin — and selector matching both work end to end.
fn test_selectors_and_inline_style_over_parsed_document() {
	doc := html.parse_document('<body>
		<ul id="list">
			<li class="item">a</li>
			<li class="item active" style="color: red; width: 10px">b</li>
			<li class="item">c</li>
		</ul>
		<p style="display: none">hidden</p>')
	root := unsafe { &dom.Node(doc) }

	// Structural pseudo-classes + combinators over parser-built elements.
	assert css.query_selector_all(root, 'ul#list > li.item').len == 3
	assert (css.query_selector(root, 'li:first-child') or { panic('first') }).text_content() or { '' } == 'a'
	assert (css.query_selector(root, 'li:last-child') or { panic('last') }).text_content() or { '' } == 'c'
	assert (css.query_selector(root, 'li.active') or { panic('active') }).text_content() or { '' } == 'b'

	// Parse the active item's inline style declaration and read specified values.
	active := css.query_selector(root, '.active') or { panic('active') }
	block := css.parse_css_property_declaration_block_with_parser(active.get_attribute('style') or { '' })
	assert block.length() == 2
	assert block.get_property_value('color') == 'red'
	assert block.get_property_value('width') == '10px'

	hidden := css.query_selector(root, 'p') or { panic('p') }
	hidden_block := css.parse_css_property_declaration_block_with_parser(hidden.get_attribute('style') or { '' })
	assert hidden_block.get_property_value('display') == 'none'
}

// Full-stack CSS cascade: parse HTML, then resolve cascaded/inherited property values over the
// parser-built DOM using the minimal cascade (inline + inheritance + initial). This composes the
// html parser + dom + css metadata/inline-parsing.
fn test_cascade_over_parsed_document() {
	doc := html.parse_document('<body style="color: navy"><div><p>text</p><span style="color: red">red</span></div></body>')
	root := unsafe { &dom.Node(doc) }
	body := css.query_selector(root, 'body') or { panic('no body') }
	p := css.query_selector(root, 'p') or { panic('no p') }
	span := css.query_selector(root, 'span') or { panic('no span') }

	color := css.property_id_from_string('color') or { panic('color id') }
	display := css.property_id_from_string('display') or { panic('display id') }

	// color inherits from <body> down through <div> to <p>; <span> overrides it inline.
	assert css.cascaded_value_for(body, color) == 'navy'
	assert css.cascaded_value_for(p, color) == 'navy'
	assert css.cascaded_value_for(span, color) == 'red'
	// display is not inherited -> its initial value.
	assert css.cascaded_value_for(p, display) == 'inline'
}

// Full-stack cascade WITH an author stylesheet: parse HTML + parse a stylesheet, then resolve
// cascaded/inherited values (author rules matched by selector + inheritance) over the parsed DOM.
fn test_cascade_with_stylesheet_over_parsed_document() {
	doc := html.parse_document('<body><div class="card"><h1>Title</h1><p>Body</p></div></body>')
	root := unsafe { &dom.Node(doc) }
	rules := css.parse_css_stylesheet_contents_with_parser('.card { color: navy } h1 { color: crimson }',
		map[string]bool{})
	color := css.property_id_from_string('color') or { panic('color id') }

	h1 := css.query_selector(root, 'h1') or { panic('no h1') }
	p := css.query_selector(root, 'p') or { panic('no p') }

	// h1 matches its own author rule (crimson); p has no rule and inherits .card's navy.
	assert css.cascaded_value_with_stylesheet(h1, color, rules) == 'crimson'
	assert css.cascaded_value_with_stylesheet(p, color, rules) == 'navy'
}

// Full-stack UA cascade: parse HTML, then resolve UA-default display values over the parsed DOM
// (no author styles) — div/li/span/head get their user-agent defaults.
fn test_ua_cascade_over_parsed_document() {
	doc := html.parse_document('<body><div><ul><li>x</li></ul><span>y</span></div></body>')
	root := unsafe { &dom.Node(doc) }
	display := css.property_id_from_string('display') or { panic('display id') }
	no_author := []&css.CSSRule{}

	div := css.query_selector(root, 'div') or { panic('no div') }
	li := css.query_selector(root, 'li') or { panic('no li') }
	span := css.query_selector(root, 'span') or { panic('no span') }
	head := css.query_selector(root, 'head') or { panic('no head') }

	assert css.cascaded_value_with_ua(div, display, no_author) == 'block'
	assert css.cascaded_value_with_ua(li, display, no_author) == 'list-item'
	assert css.cascaded_value_with_ua(span, display, no_author) == 'inline'
	assert css.cascaded_value_with_ua(head, display, no_author) == 'none'
}

// Full-stack computed font-size: parse HTML with font-sizes, then resolve computed px over the
// parsed DOM (em/% resolve up the inheritance chain).
fn test_computed_font_size_over_parsed_document() {
	doc := html.parse_document('<html style="font-size: 20px"><body><section style="font-size: 1.5em"><span style="font-size: 200%">x</span></section></body></html>')
	root := unsafe { &dom.Node(doc) }
	no_author := []&css.CSSRule{}

	section := css.query_selector(root, 'section') or { panic('no section') }
	span := css.query_selector(root, 'span') or { panic('no span') }

	// section: 1.5em of html's 20px (body inherits 20) = 30.
	assert css.computed_font_size_px(section, no_author) == 30.0
	// span: 200% of section's 30 = 60.
	assert css.computed_font_size_px(span, no_author) == 60.0
}

// Full-stack css -> layout bridge: parse HTML, resolve a computed length to px, and feed it into
// the layout module's AvailableSize.
fn test_computed_length_feeds_layout() {
	doc := html.parse_document('<body><div style="font-size: 16px; width: 10em"></div></body>')
	root := unsafe { &dom.Node(doc) }
	div := css.query_selector(root, 'div') or { panic('no div') }

	width_id := css.property_id_from_string('width') or { panic('width id') }
	width_px := css.computed_length_px(div, width_id, []&css.CSSRule{}) or { panic('no computed width') }
	assert width_px == 160.0 // 10em * 16px

	// Hand the computed px to layout's AvailableSize (css -> layout).
	available := layout.AvailableSize.make_definite(css.CSSPixels.nearest_value_for(width_px))
	assert available.is_definite()
	assert available.to_px_or_zero().to_double() == 160.0
}

// Full-stack computed color: parse HTML, resolve inherited color + currentColor over the DOM.
fn test_computed_color_over_parsed_document() {
	doc := html.parse_document('<body style="color: rgb(1, 2, 3)"><div><span style="border-top-color: currentColor">x</span></div></body>')
	root := unsafe { &dom.Node(doc) }
	span := css.query_selector(root, 'span') or { panic('no span') }
	no := []&css.CSSRule{}
	color_id := css.property_id_from_string('color') or { panic('color id') }
	border_id := css.property_id_from_string('border-top-color') or { panic('border id') }

	// span inherits color rgb(1 2 3) from body; border-top-color: currentColor resolves to it.
	assert (css.computed_color(span, color_id, no) or { panic('color') }).serialize() == 'rgb(1 2 3)'
	assert (css.computed_color(span, border_id, no) or { panic('border') }).serialize() == 'rgb(1 2 3)'
}

// Full-stack block layout: parse HTML, cascade computed widths/heights, run the minimal block-flow
// engine over the real DOM. A 300px container with two block children (auto width; 25% width).
fn test_block_flow_layout_over_parsed_document() {
	doc := html.parse_document('<div style="width: 300px"><p style="height: 40px"></p><p style="width: 25%; height: 10px"></p></div>')
	root := unsafe { &dom.Node(doc) }
	container := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(container, 0, 0, 1000, []&css.CSSRule{})
	assert box.width == 300.0 // explicit px, not the 1000 available width
	assert box.height == 50.0 // auto -> 40 + 10
	assert box.children.len == 2
	assert box.children[0].width == 300.0 // auto fills the 300px container
	assert box.children[0].height == 40.0
	assert box.children[1].width == 75.0 // 25% of 300
	assert box.children[1].y == 40.0 // stacked below the first child
}

// Full-stack box model: parse HTML, cascade margins/padding, lay out with real box geometry.
// A 400px container with padding:20 holds a p (margin:10, height:50).
fn test_block_box_model_over_parsed_document() {
	doc := html.parse_document('<div style="width: 400px; padding: 20px"><p style="height: 50px; margin: 10px"></p></div>')
	root := unsafe { &dom.Node(doc) }
	container := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(container, 0, 0, 1000, []&css.CSSRule{})
	// container content box inset by its 20px padding (no margin/border).
	assert box.width == 400.0
	assert box.x == 20.0
	assert box.y == 20.0
	// p: content_x = 20 (container) + 10 (own margin); width auto = 400 - 20 (own margins).
	assert box.children[0].x == 30.0
	assert box.children[0].y == 30.0
	assert box.children[0].width == 380.0
	// container content height = p's margin box = 10 + 50 + 10.
	assert box.height == 70.0
}

// Full-stack margin collapsing: two paragraphs with margin:25px collapse to a 25px gap (not 50px).
fn test_margin_collapse_over_parsed_document() {
	doc := html.parse_document('<div style="width: 300px"><p style="height: 20px; margin: 25px"></p><p style="height: 20px; margin: 25px"></p></div>')
	root := unsafe { &dom.Node(doc) }
	container := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(container, 0, 0, 1000, []&css.CSSRule{})
	assert box.children.len == 2
	assert box.children[0].y == 25.0 // first p offset by its own top margin
	assert box.children[0].width == 250.0 // 300 - 50 (own left+right margins)
	assert box.children[1].y == 70.0 // 45 (first p's bottom border) + 25 (collapsed margin)
	assert box.height == 115.0 // 25 + 20 + 25 (collapsed) + 20 + 25
}

// Full-stack display filter: laying out from <html>, the display:none <head> generates no box, and
// inside <body> an inline <span> generates no box while a block <div> does.
fn test_display_filter_over_parsed_document() {
	doc := html.parse_document('<html><head><title>t</title><style>x{}</style></head><body style="height: 50px"><span style="height: 999px">inline</span><div style="height: 30px"></div></body></html>')
	root := unsafe { &dom.Node(doc) }
	html_el := css.query_selector(root, 'html') or { panic('no html') }

	box := layout.layout_block(html_el, 0, 0, 1000, []&css.CSSRule{})
	assert box.children.len == 1 // <head> is display:none, only <body> remains
	assert box.children[0].tag_name == 'body'
	assert box.children[0].children.len == 1 // the inline <span> is skipped, only <div> lays out
	assert box.children[0].children[0].tag_name == 'div'
}

// Full-stack inline text: a text-only div gets a one-line height from the cascade's font/line-height.
// "Some words here" = 15 glyphs * 0.5*20 = 150px < 500px -> 1 line * 24px line-height.
fn test_inline_text_height_over_parsed_document() {
	doc := html.parse_document('<div style="width: 500px; font-size: 20px; line-height: 24px">Some words here</div>')
	root := unsafe { &dom.Node(doc) }
	div := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(div, 0, 0, 1000, []&css.CSSRule{})
	assert box.height == 24.0
	assert box.children.len == 0 // text is not a block box
}

// layout_document is the one-call reflow: parse HTML -> collect <style> author rules -> lay out from
// the root element within the viewport. Verifies author styles reach the cascade during layout.
fn test_layout_document_entry_point() {
	doc := html.parse_document('<html><head><style>.box { height: 40px; width: 120px }</style></head><body><div class="box"></div><p>text here</p></body></html>')

	root_box := layout.layout_document(doc, 800)
	assert root_box.tag_name == 'html'
	assert root_box.width == 800.0 // root fills the viewport (width:auto)
	assert root_box.children.len == 1 // <head> is display:none, only <body>
	body_box := root_box.children[0]
	assert body_box.tag_name == 'body'

	assert body_box.children.len == 2 // div.box and p
	assert body_box.children[0].tag_name == 'div'
	assert body_box.children[0].height == 40.0 // from the author <style> rule
	assert body_box.children[0].width == 120.0
	assert body_box.children[1].tag_name == 'p'
	assert body_box.children[1].height > 0.0 // text gives the paragraph a line box
	// root height spans its content (body + body's margins), so it's at least the body content.
	assert root_box.height >= 40.0
}

// Full-stack box-sizing: the near-universal `* { box-sizing: border-box }` reset from an author
// <style> reaches layout, so .card's specified 200px width includes its padding+border.
fn test_box_sizing_over_parsed_document() {
	doc := html.parse_document('<html><head><style>* { box-sizing: border-box } .card { width: 200px; padding: 20px; border: 5px solid }</style></head><body><div class="card"></div></body></html>')

	root_box := layout.layout_document(doc, 800)
	card := root_box.children[0].children[0] // html > body > div.card
	assert card.tag_name == 'div'
	assert card.width == 150.0 // 200 - 2*(20 padding + 5 border)
	assert card.margin_box_width() == 200.0 // border box stays at the specified width
}
