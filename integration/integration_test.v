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
	doc := html.parse_document('<div style="width: 300px"><div style="height: 40px"></div><div style="width: 25%; height: 10px"></div></div>')
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

// Full-stack margin collapsing: two paragraphs with margin:25px. The between-siblings margins
// collapse to a 25px gap (not 50), and -- since the container has no border/padding -- the first
// p's top margin and the last p's bottom margin collapse OUT of the container (parent/child).
fn test_margin_collapse_over_parsed_document() {
	doc := html.parse_document('<div style="width: 300px"><p style="height: 20px; margin: 25px"></p><p style="height: 20px; margin: 25px"></p></div>')
	root := unsafe { &dom.Node(doc) }
	container := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(container, 0, 0, 1000, []&css.CSSRule{})
	assert box.children.len == 2
	assert box.y == 25.0 // container pushed down by the first p's collapsed-out top margin
	assert box.children[0].y == 25.0 // first p at the container's content top
	assert box.children[0].width == 250.0 // 300 - 50 (own left+right margins)
	assert box.children[1].y == 70.0 // 45 (first p's bottom border) + 25 (collapsed sibling margin)
	assert box.height == 65.0 // content only: 20 + 25 gap + 20; the outer p margins collapsed out
	assert box.outer_bottom_margin == 25.0 // last p's bottom margin became the container's
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

// Full-stack min/max: the classic responsive container -- width:auto capped by max-width -- clamps
// against a wide viewport, while a short element is raised to a min-height, all via author <style>.
fn test_min_max_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.wrap { max-width: 600px } .hero { min-height: 300px }</style></head><body><div class="wrap"><div class="hero"></div></div></body></html>')

	root_box := layout.layout_document(doc, 1440)
	wrap := root_box.children[0].children[0] // html > body > div.wrap
	assert wrap.tag_name == 'div'
	assert wrap.width == 600.0 // auto width clamped by max-width against the 1440 viewport
	hero := wrap.children[0]
	assert hero.width == 600.0 // fills the clamped container
	assert hero.height == 300.0 // empty, raised to min-height
}

// Full-stack: the canonical centered responsive container -- max-width + margin:0 auto -- against a
// wide viewport, all from an author <style>.
fn test_centered_container_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.container { max-width: 960px; margin: 0 auto }</style></head><body><div class="container"></div></body></html>')

	root_box := layout.layout_document(doc, 1440)
	body_box := root_box.children[0]
	assert body_box.margin.left == 8.0 // UA body margin narrows the container's containing block
	container := body_box.children[0] // html > body > div.container
	assert container.tag_name == 'div'
	assert container.width == 960.0 // auto width clamped to max-width
	// centered within body's content box (1440 - 2*8 = 1424): (1424 - 960) / 2 = 232.
	assert container.margin.left == 232.0
	assert container.margin.right == 232.0
	assert container.x == 240.0 // body's 8px content offset + 232 margin
}

// Full-stack BFC: an overflow:hidden wrapper contains its child paragraph's top margin instead of
// letting it collapse out (the classic "contain the margin" use of a BFC). Compare the plain-div
// case where the margin would collapse through.
fn test_bfc_contains_margin_over_parsed_document() {
	doc := html.parse_document('<div style="width: 300px; overflow: hidden"><div style="height: 20px; margin-top: 40px"></div></div>')
	root := unsafe { &dom.Node(doc) }
	wrapper := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(wrapper, 0, 0, 1000, []&css.CSSRule{})
	assert box.y == 0.0 // wrapper NOT pushed down; it contains the child's margin
	assert box.outer_top_margin == 0.0
	assert box.children[0].y == 40.0 // the child's top margin sits inside the wrapper
	assert box.height == 60.0 // 40 (margin inside) + 20
}

// Full-stack position: relative -- a nudged element moves but its sibling keeps its flow position.
fn test_relative_position_over_parsed_document() {
	doc := html.parse_document('<div style="width: 300px"><div style="height: 20px; position: relative; top: 5px; left: 12px"></div><div style="height: 20px"></div></div>')
	root := unsafe { &dom.Node(doc) }
	container := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(container, 0, 0, 1000, []&css.CSSRule{})
	assert box.children[0].x == 12.0 // left
	assert box.children[0].y == 5.0 // top, offset from its flow y (0)
	assert box.children[1].x == 0.0 // sibling unaffected
	assert box.children[1].y == 20.0 // flows after the first child's NORMAL box, not its offset one
	assert box.height == 40.0 // container height from the flow (20 + 20), ignoring the offset
}

// Full-stack absolute positioning: the classic "badge pinned to a corner of a relative container".
// The badge is positioned against .rel's padding box and is out of flow.
fn test_absolute_position_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.rel { position: relative; width: 400px; height: 200px } .badge { position: absolute; top: 5px; right: 8px; width: 30px; height: 30px }</style></head><body><div class="rel"><div class="badge"></div></div></body></html>')

	root_box := layout.layout_document(doc, 1200)
	rel := root_box.children[0].children[0] // html > body > div.rel
	assert rel.tag_name == 'div'
	assert rel.children.len == 1 // the badge (abspos), appended to its containing block
	badge := rel.children[0]
	assert badge.width == 30.0
	assert badge.height == 30.0
	// pinned to .rel's top-right: x = rel.x + (400 - 8 right - 30 width); y = rel.y + 5 top.
	assert badge.x == rel.x + 362.0
	assert badge.y == rel.y + 5.0
}

// Whole-pipeline snapshot: one realistic document exercises box-sizing, max-width clamping,
// margin:0 auto centering, a UA body-margin override, padding insets, sibling margin-bottom
// collapsing, display:none exclusion, position:relative establishing a containing block, and a
// position:absolute badge pinned to a corner -- all locked into one box-tree geometry dump. A
// regression in any of those features changes exactly one line of this diff.
fn test_full_pipeline_box_tree_snapshot() {
	css_rules := '* { box-sizing: border-box }
		body { margin: 0 }
		.container { max-width: 600px; margin: 0 auto; padding: 20px }
		.card { border: 2px solid; padding: 10px; margin-bottom: 16px; height: 50px }
		.hidden { display: none }
		.rel { position: relative; height: 80px }
		.badge { position: absolute; top: 0; right: 0; width: 40px; height: 40px }'
	markup := '<html><head><style>${css_rules}</style></head><body><div class="container"><div class="card"></div><div class="hidden"></div><div class="rel"><div class="badge"></div></div></div></body></html>'

	doc := html.parse_document(markup)
	box := layout.layout_document(doc, 1000)

	expected := [
		'html (0,0) 1000x186', // fills the 1000px viewport; height flows up from content
		'  body (0,0) 1000x186', // UA 8px margin overridden to 0
		'    div (220,20) 560x146', // .container: centered (200 margin + 20 pad), 600 border-box -> 560 content
		'      div (232,32) 536x26', // .card: inset by border+padding; 50 border-box height -> 26 content
		'      div (220,86) 560x80', // .rel: y = card bottom 70 + collapsed 16px margin (not stacked below .hidden)
		'        div (740,86) 40x40', // .badge: absolute, pinned to .rel's top-right corner
	].join('\n')
	assert box.tree_repr() == expected
}

// Full-stack word wrapping: "alpha beta gamma" over a 100px line -- "alpha beta" (50+10+40=100)
// fills the first line, "gamma" wraps to a second -> 2 lines * 25px line-height.
fn test_word_wrap_over_parsed_document() {
	doc := html.parse_document('<div style="width: 100px; font-size: 20px; line-height: 25px">alpha beta gamma</div>')
	root := unsafe { &dom.Node(doc) }
	div := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(div, 0, 0, 1000, []&css.CSSRule{})
	assert box.height == 50.0
}

// Full-stack <br>: three <br>-separated lines each fit the 500px box, so height is 3 line-heights.
fn test_br_over_parsed_document() {
	doc := html.parse_document('<div style="width: 500px; line-height: 20px">line one<br>line two<br>line three</div>')
	root := unsafe { &dom.Node(doc) }
	div := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(div, 0, 0, 1000, []&css.CSSRule{})
	assert box.height == 60.0 // 3 lines * 20px
}

// Full-stack text-align: centered text in a 300px box. "hey" = 3 glyphs * 8 (16px font) = 24px,
// centered -> x = (300 - 24) / 2.
fn test_text_align_over_parsed_document() {
	doc := html.parse_document('<div style="width: 300px; text-align: center; line-height: 20px">hey</div>')
	root := unsafe { &dom.Node(doc) }
	div := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(div, 0, 0, 1000, []&css.CSSRule{})
	assert box.lines.len == 1
	assert box.lines[0].width == 24.0
	assert box.lines[0].x == 138.0 // (300 - 24) / 2
}

// Full-stack <pre>: the UA sheet gives <pre> white-space: pre, so its newlines become forced line
// breaks (and it doesn't wrap) -- three source lines -> three line boxes.
fn test_pre_over_parsed_document() {
	doc := html.parse_document('<pre style="line-height: 20px">line one\nline two\nline three</pre>')
	root := unsafe { &dom.Node(doc) }
	pre := css.query_selector(root, 'pre') or { panic('no pre') }

	box := layout.layout_block(pre, 0, 0, 1000, []&css.CSSRule{})
	assert box.lines.len == 3
	assert box.height == 60.0 // 3 lines * 20px
}

// Full-stack intrinsic sizing: a width:max-content div hugs its widest line rather than filling.
fn test_max_content_over_parsed_document() {
	doc := html.parse_document('<div style="width: max-content; font-size: 20px">hello world</div>')
	root := unsafe { &dom.Node(doc) }
	div := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(div, 0, 0, 1000, []&css.CSSRule{})
	assert box.width == 110.0 // 50 + 10 space + 50, not the 1000 available width
}

// Full-stack floats: an overflow:hidden container clears its floated children (the clearfix): a
// float:left and a float:right are placed at the edges and the container grows to contain them.
fn test_floats_over_parsed_document() {
	doc := html.parse_document('<div style="width: 400px; overflow: hidden"><div style="float: left; width: 120px; height: 60px"></div><div style="float: right; width: 80px; height: 30px"></div></div>')
	root := unsafe { &dom.Node(doc) }
	container := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(container, 0, 0, 1000, []&css.CSSRule{})
	assert box.children.len == 2 // the two floats
	assert box.children[0].x == 0.0 // left float at the left edge
	assert box.children[0].width == 120.0
	assert box.children[1].x == 320.0 // right float: 400 - 80
	assert box.height == 60.0 // BFC contains the taller (left) float
}

// Full-stack float wrap-around: text in a container flows to the right of a left float, then
// returns to full width below it (the classic "float an image, text wraps around it").
fn test_float_wrap_over_parsed_document() {
	doc := html.parse_document('<div style="width: 200px; overflow: hidden; font-size: 20px; line-height: 20px"><div style="float: left; width: 150px; height: 40px"></div>aaaa bbbb cccc</div>')
	root := unsafe { &dom.Node(doc) }
	container := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(container, 0, 0, 1000, []&css.CSSRule{})
	assert box.lines.len == 3
	assert box.lines[0].x == 150.0 // beside the float
	assert box.lines[2].x == 0.0 // below the float, full width
	assert box.lines[2].y == 40.0
}

// Full-stack z-index: a modal (z-index:10) paints above a backdrop (z-index:1) in the same
// positioned container, regardless of source order.
fn test_paint_order_over_parsed_document() {
	doc := html.parse_document('<div style="position: relative"><div style="position: absolute; z-index: 10">modal</div><div style="position: absolute; z-index: 1">backdrop</div></div>')
	root := unsafe { &dom.Node(doc) }
	container := css.query_selector(root, 'div') or { panic('no div') }

	order := layout.layout_block(container, 0, 0, 800, []&css.CSSRule{}).paint_order()
	assert order.len == 3
	assert order[1].z_index == 1 // backdrop paints below
	assert order[2].z_index == 10 // modal paints on top (even though it came first in source)
}

// Full-stack inline fragments: each word in a parsed paragraph gets its own positioned box.
fn test_inline_fragments_over_parsed_document() {
	doc := html.parse_document('<div style="width: 500px; font-size: 20px; line-height: 24px">one two three</div>')
	root := unsafe { &dom.Node(doc) }
	div := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(div, 0, 0, 1000, []&css.CSSRule{})
	frags := box.lines[0].fragments
	assert frags.len == 3
	assert frags[0].text == 'one'
	assert frags[0].x == 0.0
	assert frags[1].text == 'two'
	assert frags[1].x == 40.0 // "one" = 3*10=30, + 10 space
	assert frags[2].text == 'three'
	assert frags[2].x == 80.0 // + "two" (20) + space (10) = 40 + 40
}

// Full-stack per-inline font: a bigger <span> inside a paragraph is measured at its own size and
// makes the line taller.
fn test_per_inline_font_over_parsed_document() {
	doc := html.parse_document('<div style="width: 500px; font-size: 20px">hi <span style="font-size: 40px">BIG</span></div>')
	root := unsafe { &dom.Node(doc) }
	div := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(div, 0, 0, 1000, []&css.CSSRule{})
	frags := box.lines[0].fragments
	assert frags.len == 2
	assert frags[0].text == 'hi'
	assert frags[0].height == 24.0 // 20px font -> 24 line-height
	assert frags[1].text == 'BIG'
	assert frags[1].width == 60.0 // measured at 40px
	assert frags[1].height == 48.0 // 40px font -> 48 line-height
	assert box.lines[0].height == 48.0 // line grows to the tallest word
}

// Full-stack justify: a wrapped justified paragraph fills each full line; the last line stays left.
fn test_justify_over_parsed_document() {
	doc := html.parse_document('<div style="width: 100px; font-size: 20px; line-height: 30px; text-align: justify">aaaa bbbb cccc</div>')
	root := unsafe { &dom.Node(doc) }
	div := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(div, 0, 0, 1000, []&css.CSSRule{})
	assert box.lines[0].width == 100.0 // first line fills the width
	assert box.lines[0].fragments[1].x == 60.0 // bbbb pushed right by the justify slack
	assert box.lines[1].width == 40.0 // last line: natural width, left-aligned
}

// Full-stack display list: parse HTML, lay out, and produce paint commands (background fill + text)
// -- the complete pipeline from HTML source to a paintable display list.
fn test_display_list_over_parsed_document() {
	doc := html.parse_document('<div style="width: 200px; height: 100px; background-color: rgb(10, 20, 30); color: rgb(1, 2, 3)">hi</div>')
	root := unsafe { &dom.Node(doc) }
	div := css.query_selector(root, 'div') or { panic('no div') }

	cmds := layout.layout_block(div, 0, 0, 1000, []&css.CSSRule{}).paint_commands()
	assert cmds.len == 2
	assert cmds[0].kind == 'fill_rect'
	assert cmds[0].width == 200.0
	assert cmds[0].color == 'rgb(10 20 30)'
	assert cmds[1].kind == 'draw_text'
	assert cmds[1].text == 'hi'
	assert cmds[1].color == 'rgb(1 2 3)'
}

// Full-stack borders + per-inline colors in the display list: a bordered div whose two words paint
// in their own colors.
fn test_border_and_inline_color_over_parsed_document() {
	doc := html.parse_document('<div style="width: 200px; border: 4px solid green">text <span style="color: red">red</span></div>')
	root := unsafe { &dom.Node(doc) }
	div := css.query_selector(root, 'div') or { panic('no div') }

	cmds := layout.layout_block(div, 0, 0, 1000, []&css.CSSRule{}).paint_commands()
	assert cmds[0].kind == 'fill_rect' // first: the green border edges (no background)
	assert cmds[0].color == 'rgb(0 128 0)'
	mut texts := []layout.PaintCommand{}
	for c in cmds {
		if c.kind == 'draw_text' {
			texts << c
		}
	}
	assert texts.len == 2
	assert texts[0].text == 'text'
	assert texts[0].color == 'rgb(0 0 0)' // div default color
	assert texts[1].text == 'red'
	assert texts[1].color == 'rgb(255 0 0)' // the span's color
}

// Full-stack calc(): a width:calc(100% - 60px) box resolves against the containing width.
fn test_calc_over_parsed_document() {
	doc := html.parse_document('<div style="width: calc(100% - 60px)"></div>')
	root := unsafe { &dom.Node(doc) }
	div := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(div, 0, 0, 500, []&css.CSSRule{})
	assert box.width == 440.0 // 500 - 60
}

// Full-stack opacity: every paint command for an opacity:0.5 box (background + text) carries 0.5.
fn test_opacity_over_parsed_document() {
	doc := html.parse_document('<div style="width: 100px; height: 40px; opacity: 0.5; background-color: rgb(1, 2, 3)">hi</div>')
	root := unsafe { &dom.Node(doc) }
	div := css.query_selector(root, 'div') or { panic('no div') }

	cmds := layout.layout_block(div, 0, 0, 1000, []&css.CSSRule{}).paint_commands()
	assert cmds.len == 2 // background fill + one text word
	for c in cmds {
		assert c.opacity == 0.5
	}
}

// Full-stack transform: a translated box moves while its sibling keeps its flow position.
fn test_transform_over_parsed_document() {
	doc := html.parse_document('<div style="width: 300px"><div style="height: 40px; transform: translate(20px, 10px)"></div><div style="height: 25px"></div></div>')
	root := unsafe { &dom.Node(doc) }
	container := css.query_selector(root, 'div') or { panic('no div') }

	box := layout.layout_block(container, 0, 0, 1000, []&css.CSSRule{})
	assert box.children[0].x == 20.0 // translated
	assert box.children[0].y == 10.0
	assert box.children[1].y == 40.0 // sibling flows after the untransformed first box
	assert box.height == 65.0 // 40 + 25 (flow)
}

// Full-stack render: parse HTML, lay it out, and render to SVG -- the whole pipeline, HTML -> image.
fn test_render_svg_over_parsed_document() {
	doc := html.parse_document('<div style="width: 120px; height: 60px; background-color: rgb(240, 240, 240)"><div style="width: 50px; height: 20px; background-color: rgb(30, 60, 90); color: white; font-size: 16px; line-height: 20px">hi</div></div>')
	root := unsafe { &dom.Node(doc) }
	container := css.query_selector(root, 'div') or { panic('no div') }

	svg := layout.layout_block(container, 0, 0, 200, []&css.CSSRule{}).render_svg(120, 60)
	assert svg.contains('<svg xmlns="http://www.w3.org/2000/svg" width="120" height="60">')
	assert svg.contains('fill="rgb(240 240 240)"') // outer background
	assert svg.contains('fill="rgb(30 60 90)"') // inner background
	assert svg.contains('>hi</text>')
}

// Full-stack getComputedStyle: parse HTML + an author stylesheet, then read computed values as
// strings over the parsed DOM (color resolved to rgb(), font-size to px, inheritance applied).
fn test_get_computed_style_over_parsed_document() {
	doc := html.parse_document('<body><div class="card"><p>text</p></div></body>')
	root := unsafe { &dom.Node(doc) }
	rules := css.parse_css_stylesheet_contents_with_parser('.card { color: crimson; font-size: 24px }',
		map[string]bool{})
	p := css.query_selector(root, 'p') or { panic('no p') }

	style := css.get_computed_style(p, rules)
	assert style.get_property_value('color') == 'rgb(220 20 60)' // crimson, inherited to <p>
	assert style.get_property_value('font-size') == '24px' // inherited from .card
	assert style.get_property_value('display') == 'block' // UA default for <p>
}

// Full-stack dataset: parse HTML with data-* attributes and read them via the DOMStringMap.
fn test_dataset_over_parsed_document() {
	doc := html.parse_document('<div data-user-id="42" data-role="admin">x</div>')
	root := unsafe { &dom.Node(doc) }
	div := css.query_selector(root, 'div') or { panic('no div') }

	ds := div.dataset()
	assert (ds.get('userId') or { 'none' }) == '42'
	assert (ds.get('role') or { 'none' }) == 'admin'
	assert ds.get('missing') == none
	assert 'userId' in ds.keys()
	assert 'role' in ds.keys()
}

// Full-stack element.style: parse HTML, read + mutate inline style via the CSSStyleDeclaration, and
// see the change flow through to layout.
fn test_inline_style_over_parsed_document() {
	doc := html.parse_document('<div style="width: 100px; color: red">x</div>')
	root := unsafe { &dom.Node(doc) }
	div := css.query_selector(root, 'div') or { panic('no div') }

	style := css.inline_style(div)
	assert style.get_property_value('width') == '100px'
	assert style.get_property_value('color') == 'red'

	// Mutate the inline style, then lay out -- the new width takes effect.
	style.set_property('width', '250px')
	assert style.get_property_value('width') == '250px'
	box := layout.layout_block(div, 0, 0, 800, []&css.CSSRule{})
	assert box.width == 250.0
}

// Full-stack getBoundingClientRect: parse a document, lay it out, and read a queried element's
// border-box rectangle in document coordinates.
fn test_bounding_client_rect_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.box { width: 200px; height: 60px; margin-left: 30px }</style></head><body style="margin: 0"><div class="box"></div></body></html>')
	root_box := layout.layout_document(doc, 800)
	root := unsafe { &dom.Node(doc) }
	target := css.query_selector(root, '.box') or { panic('no .box') }

	rect := root_box.bounding_rect_for(target) or { panic('no rect') }
	assert rect.x == 30.0 // margin-left, body margin overridden to 0
	assert rect.width == 200.0
	assert rect.height == 60.0
}

// Full-stack elementFromPoint: parse + lay out a document, then hit-test a point and get the element.
fn test_element_from_point_over_parsed_document() {
	doc := html.parse_document('<html><head><style>body { margin: 0 } .a { height: 50px } .b { height: 40px }</style></head><body><div class="a"></div><div class="b"></div></body></html>')
	root_box := layout.layout_document(doc, 400)
	root := unsafe { &dom.Node(doc) }

	// y=20 is inside .a (0..50); y=60 is inside .b (50..90).
	hit_a := root_box.element_at_point(10, 20, root) or { panic('no hit a') }
	assert (hit_a.get_attribute('class') or { '' }) == 'a'
	hit_b := root_box.element_at_point(10, 60, root) or { panic('no hit b') }
	assert (hit_b.get_attribute('class') or { '' }) == 'b'
}

// Full-stack offset properties: parse + lay out a positioned container with a child, read offsetTop/
// Left/Width/Height and offsetParent.
fn test_offset_properties_over_parsed_document() {
	doc := html.parse_document('<html><head><style>body { margin: 0 } .box { position: relative; padding: 15px } .item { position: absolute; top: 25px; left: 35px; width: 40px; height: 30px }</style></head><body><div class="box"><div class="item"></div></div></body></html>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	item := css.query_selector(root, '.item') or { panic('no .item') }
	// The .box position:relative comes from the <style>, so offsetParent needs the author rules.
	rules := layout.collect_document_author_rules(doc)

	assert root_box.offset_width_for(item) or { -1 } == 40.0
	assert root_box.offset_height_for(item) or { -1 } == 30.0
	assert root_box.offset_top_for(item, rules) or { -1 } == 25.0 // relative to .box padding box
	assert root_box.offset_left_for(item, rules) or { -1 } == 35.0
	parent := layout.offset_parent_element(item, rules) or { panic('no offsetParent') }
	assert (parent.get_attribute('class') or { '' }) == 'box'
}

// Full-stack innerText: parse a document, then read the rendered text of an element — whitespace
// collapses, <p> is set off by a blank line, a display:none subtree is omitted, and an inline
// <span> adds no break.
fn test_inner_text_over_parsed_document() {
	doc := html.parse_document('<body><div id="host"><p>Hello   world</p><div style="display:none">secret</div><span>tail</span></div></body>')
	root := unsafe { &dom.Node(doc) }
	host := css.query_selector(root, '#host') or { panic('no #host') }
	rules := layout.collect_document_author_rules(doc)

	assert layout.inner_text(host, rules) == 'Hello world\n\ntail'
}

// Full-stack innerText round-trip: set an element's innerText (DOM setter builds Text + <br>), then
// read it back with the rendered-text getter — line breaks survive the round-trip, and the DOM has
// the expected Text/<br>/Text structure.
fn test_inner_text_set_then_get_roundtrip() {
	doc := html.parse_document('<body><div id="host">old contents</div></body>')
	root := unsafe { &dom.Node(doc) }
	host := css.query_selector(root, '#host') or { panic('no #host') }
	mut mutable_host := unsafe { &dom.Element(host) }
	mutable_host.set_inner_text('line1\nline2')

	rules := layout.collect_document_author_rules(doc)
	assert layout.inner_text(host, rules) == 'line1\nline2'

	kids := host.as_node().children_as_vector()
	assert kids.len == 3 // text, <br>, text
	assert kids[1].as_element() or { panic('expected <br>') }.local_name() == 'br'
}

// Full-stack text-transform: parse a document with an author stylesheet that uppercases a paragraph,
// lay it out, and confirm the transform flows through to the rendered inline fragments and the SVG.
fn test_text_transform_over_parsed_document() {
	doc := html.parse_document('<html><head><style>p { text-transform: uppercase }</style></head><body><p>hello world</p></body></html>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	p := css.query_selector(root, 'p') or { panic('no p') }

	// The <p>'s line-box fragments carry the uppercased words.
	p_box := root_box.find_box(i64(p.as_node().unique_id())) or { panic('no p box') }
	mut texts := []string{}
	for line in p_box.lines {
		for frag in line.fragments {
			texts << frag.text
		}
	}
	assert texts == ['HELLO', 'WORLD']

	// And the SVG output draws the uppercased text.
	svg := root_box.render_svg(600, root_box.height + 20)
	assert svg.contains('HELLO')
	assert svg.contains('WORLD')
	assert !svg.contains('hello')
}

// Full-stack visibility: an author stylesheet hides a paragraph's text; it still occupies layout
// space (the following paragraph sits below it) but its text is absent from the SVG output.
fn test_visibility_hidden_over_parsed_document() {
	doc := html.parse_document('<html><head><style>body { margin: 0 } p { margin: 0; height: 20px } .gone { visibility: hidden }</style></head><body><p class="gone">SECRET</p><p class="shown">VISIBLE</p></body></html>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	gone := css.query_selector(root, '.gone') or { panic('no .gone') }
	shown := css.query_selector(root, '.shown') or { panic('no .shown') }

	// Both paragraphs are laid out and reserve space: the shown one sits below the hidden one.
	gone_rect := root_box.bounding_rect_for(gone) or { panic('no .gone box') }
	shown_rect := root_box.bounding_rect_for(shown) or { panic('no .shown box') }
	assert gone_rect.y == 0.0
	assert shown_rect.y == 20.0 // below the hidden paragraph, which still took 20px

	// The SVG draws the visible text but not the hidden text.
	svg := root_box.render_svg(600, root_box.height + 20)
	assert svg.contains('VISIBLE')
	assert !svg.contains('SECRET')
}

// Full-stack text-decoration: an author stylesheet underlines a paragraph; the rendered fragment
// carries the decoration and the SVG output includes both the word and an underline rect.
fn test_text_decoration_over_parsed_document() {
	doc := html.parse_document('<html><head><style>p { text-decoration: underline }</style></head><body><p>linked</p></body></html>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	p := css.query_selector(root, 'p') or { panic('no p') }

	p_box := root_box.find_box(i64(p.as_node().unique_id())) or { panic('no p box') }
	assert p_box.lines[0].fragments[0].decoration.contains('underline')

	// The display list has the word plus an underline fill (the p has no background of its own).
	cmds := root_box.paint_commands()
	assert cmds.filter(it.kind == 'draw_text').len == 1
	assert cmds.filter(it.kind == 'fill_rect').len == 1

	svg := root_box.render_svg(600, root_box.height + 20)
	assert svg.contains('linked')
	assert svg.contains('<rect') // the underline
}

// Full-stack list markers: parse a <ul>, lay it out, and confirm each <li> gets a disc marker that
// reaches the SVG output alongside the item text.
fn test_list_markers_over_parsed_document() {
	doc := html.parse_document('<body><ul><li>alpha</li><li>beta</li></ul></body>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }

	lis := css.query_selector_all(root, 'li')
	assert lis.len == 2
	for li in lis {
		li_box := root_box.find_box(i64(li.as_node().unique_id())) or { panic('no li box') }
		assert li_box.lines[0].fragments[0].text == '•' // marker line prepended
	}

	svg := root_box.render_svg(600, root_box.height + 20)
	assert svg.contains('alpha')
	assert svg.contains('beta')
	assert svg.contains('•')
}

// Full-stack letter-spacing: an author stylesheet adds letter-spacing to a paragraph; the rendered
// fragment width reflects the widened glyph advances.
fn test_letter_spacing_over_parsed_document() {
	doc := html.parse_document('<html><head><style>p { font-size: 20px; letter-spacing: 5px }</style></head><body><p>hi</p></body></html>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	p := css.query_selector(root, 'p') or { panic('no p') }

	p_box := root_box.find_box(i64(p.as_node().unique_id())) or { panic('no p box') }
	frag := p_box.lines[0].fragments[0]
	assert frag.text == 'hi'
	assert frag.width == 30.0 // 2 runes × (10px glyph + 5px letter-spacing)
}

// Full-stack CSS logical properties: the UA sheet expresses block/inline edges logically
// (`p { margin-block: 1em }`, `ul { padding-inline-start: 40px }`); in LTR these map to the physical
// margin-top/bottom and padding-left the layout reads, so a parsed <p>/<ul> gets its real UA edges.
fn test_logical_properties_over_parsed_document() {
	doc := html.parse_document('<body><p></p><ul><li>x</li></ul></body>')
	root := unsafe { &dom.Node(doc) }
	p := css.query_selector(root, 'p') or { panic('no p') }
	ul := css.query_selector(root, 'ul') or { panic('no ul') }

	p_box := layout.layout_block(p, 0, 0, 1000, []&css.CSSRule{})
	assert p_box.margin.top == 16.0 // UA margin-block: 1em -> margin-top
	assert p_box.margin.bottom == 16.0

	ul_box := layout.layout_block(ul, 0, 0, 1000, []&css.CSSRule{})
	assert ul_box.padding.left == 40.0 // UA padding-inline-start: 40px -> padding-left
}

// Full-stack text-indent: an author stylesheet indents a paragraph's first line; the rendered first
// fragment starts at the indent offset.
fn test_text_indent_over_parsed_document() {
	doc := html.parse_document('<html><head><style>body { margin: 0 } p { margin: 0; font-size: 20px; text-indent: 40px }</style></head><body><p>hello</p></body></html>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	p := css.query_selector(root, 'p') or { panic('no p') }

	p_box := root_box.find_box(i64(p.as_node().unique_id())) or { panic('no p box') }
	frag := p_box.lines[0].fragments[0]
	assert frag.text == 'hello'
	// The <p>'s content-box left is 0 (body margin 0, no padding); the first line is indented 40px.
	assert frag.x == p_box.x + 40.0
}

// Full-stack border-radius: an author stylesheet rounds a card's background; the SVG rect gets rx/ry.
fn test_border_radius_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.card { width: 200px; height: 100px; background-color: rgb(10, 20, 30); border-radius: 12px }</style></head><body><div class="card"></div></body></html>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	card := css.query_selector(root, '.card') or { panic('no .card') }

	card_box := root_box.find_box(i64(card.as_node().unique_id())) or { panic('no card box') }
	assert card_box.border_radius == 12.0

	svg := root_box.render_svg(600, root_box.height + 20)
	assert svg.contains('rx="12"')
	assert svg.contains('fill="rgb(10 20 30)"')
}

// Full-stack outline: an author stylesheet outlines a focused input-like box; the four outline rects
// reach the SVG, drawn outside the border box in the outline color.
fn test_outline_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.focus { width: 120px; height: 30px; outline: 2px solid rgb(0, 90, 200) }</style></head><body><div class="focus"></div></body></html>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	focus := css.query_selector(root, '.focus') or { panic('no .focus') }

	focus_box := root_box.find_box(i64(focus.as_node().unique_id())) or { panic('no box') }
	assert focus_box.outline_width == 2.0

	svg := root_box.render_svg(600, root_box.height + 20)
	// The outline color appears in the SVG (as the four edge rects).
	assert svg.contains('fill="rgb(0 90 200)"')
}

// Full-stack box-shadow: an author stylesheet gives a card a blurred drop shadow; the shadow reaches
// the SVG as a blur-filtered rect behind the card's background.
fn test_box_shadow_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.card { width: 200px; height: 80px; background-color: rgb(255, 255, 255); box-shadow: 3px 5px 10px rgb(0, 0, 0) }</style></head><body><div class="card"></div></body></html>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	card := css.query_selector(root, '.card') or { panic('no .card') }

	card_box := root_box.find_box(i64(card.as_node().unique_id())) or { panic('no card box') }
	sh := card_box.shadow or { panic('no shadow') }
	assert sh.offset_x == 3.0
	assert sh.offset_y == 5.0
	assert sh.blur == 10.0

	svg := root_box.render_svg(600, root_box.height + 40)
	assert svg.contains('feGaussianBlur')
	assert svg.contains('filter="url(#blur0)"')
}

// Full-stack CSS-wide keywords: an author stylesheet uses `inherit` and `initial`; the values resolve
// through the parsed DOM (inherit -> ancestor's value; initial -> the property's initial).
fn test_css_wide_keywords_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.parent { color: rgb(20, 40, 60) } .child { color: inherit } .reset { display: initial }</style></head><body><div class="parent"><span class="child">x</span></div><div class="reset"></div></body></html>')
	root := unsafe { &dom.Node(doc) }
	rules := layout.collect_document_author_rules(doc)
	child := css.query_selector(root, '.child') or { panic('no .child') }
	reset := css.query_selector(root, '.reset') or { panic('no .reset') }

	color := css.property_id_from_string('color') or { panic('color id') }
	display := css.property_id_from_string('display') or { panic('display id') }

	// .child color: inherit resolves to .parent's rgb(20, 40, 60).
	assert css.cascaded_value_with_ua(child, color, rules) == 'rgb(20, 40, 60)'
	// .reset display: initial -> 'inline' (overriding the UA div block).
	assert css.cascaded_value_with_ua(reset, display, rules) == 'inline'
}

// Full-stack var(): an author stylesheet defines a custom property and uses it (with fallback) to
// drive layout width and a computed color over the parsed DOM.
fn test_var_custom_properties_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.box { --w: 150px; --brand: rgb(30, 60, 90); width: var(--w); height: var(--h, 40px); background-color: var(--brand) }</style></head><body><div class="box"></div></body></html>')
	root := unsafe { &dom.Node(doc) }
	rules := layout.collect_document_author_rules(doc)
	box_el := css.query_selector(root, '.box') or { panic('no .box') }

	// width from var(--w); height from the var(--h) fallback.
	box := layout.layout_block(box_el, 0, 0, 1000, rules)
	assert box.width == 150.0
	assert box.height == 40.0
	// background-color resolved from var(--brand).
	assert box.background_color.serialize() == 'rgb(30 60 90)'
}

// Full-stack @media: an author stylesheet gives .col a base width and a wider one inside a
// min-width media query; the box width depends on the viewport width passed to layout_document.
fn test_media_query_over_parsed_document() {
	markup := '<html><head><style>.col { width: 100px } @media (min-width: 600px) { .col { width: 300px } }</style></head><body><div class="col"></div></body></html>'

	// Narrow viewport: the media query does not match -> base 100px.
	narrow_doc := html.parse_document(markup)
	narrow_root := layout.layout_document(narrow_doc, 500)
	narrow_col := css.query_selector(unsafe { &dom.Node(narrow_doc) }, '.col') or { panic('no .col') }
	assert (narrow_root.find_box(i64(narrow_col.as_node().unique_id())) or { panic('box') }).width == 100.0

	// Wide viewport: the media query matches -> 300px.
	wide_doc := html.parse_document(markup)
	wide_root := layout.layout_document(wide_doc, 800)
	wide_col := css.query_selector(unsafe { &dom.Node(wide_doc) }, '.col') or { panic('no .col') }
	assert (wide_root.find_box(i64(wide_col.as_node().unique_id())) or { panic('box') }).width == 300.0
}

// Full-stack linear-gradient: an author stylesheet gives a hero a gradient background; it renders to
// an SVG linearGradient with the stop colors.
fn test_linear_gradient_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.hero { width: 300px; height: 120px; background: linear-gradient(to bottom, rgb(10, 20, 30), rgb(200, 210, 220)) }</style></head><body><div class="hero"></div></body></html>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	hero := css.query_selector(root, '.hero') or { panic('no .hero') }

	hero_box := root_box.find_box(i64(hero.as_node().unique_id())) or { panic('no hero box') }
	grad := hero_box.background_gradient or { panic('no gradient') }
	assert grad.colors.len == 2

	svg := root_box.render_svg(600, root_box.height + 20)
	assert svg.contains('<linearGradient')
	assert svg.contains('stop-color="rgb(10 20 30)"')
	assert svg.contains('stop-color="rgb(200 210 220)"')
}

// Full-stack resolved values: getComputedStyle returns the specified `%` width, while the layout-
// backed resolved_style_value returns the used px after laying out the parsed document.
fn test_resolved_style_value_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.wrap { width: 400px } .col { width: 25%; padding: 8px }</style></head><body><div class="wrap"><div class="col"></div></div></body></html>')
	root := unsafe { &dom.Node(doc) }
	rules := layout.collect_document_author_rules(doc)
	col := css.query_selector(root, '.col') or { panic('no .col') }

	// Layout-free getComputedStyle: the width is still the specified percentage.
	assert css.get_computed_style(col, rules).get_property_value('width') == '25%'

	// After layout, the resolved value is the used px (25% of 400 = 100).
	root_box := layout.layout_document(doc, 800)
	assert root_box.resolved_style_value(col, 'width', rules) == '100px'
	assert root_box.resolved_style_value(col, 'padding-left', rules) == '8px'
}

// Full-stack flexbox: an author stylesheet lays a nav's items in a row; they sit side by side and
// the bar's height matches the tallest item.
fn test_flex_row_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.bar { display: flex; width: 600px } .a { width: 120px; height: 40px } .b { width: 80px; height: 60px }</style></head><body><div class="bar"><div class="a"></div><div class="b"></div></div></body></html>')
	root_box := layout.layout_document(doc, 800)
	root := unsafe { &dom.Node(doc) }
	bar := css.query_selector(root, '.bar') or { panic('no .bar') }
	a := css.query_selector(root, '.a') or { panic('no .a') }
	b := css.query_selector(root, '.b') or { panic('no .b') }

	a_rect := root_box.bounding_rect_for(a) or { panic('no .a box') }
	b_rect := root_box.bounding_rect_for(b) or { panic('no .b box') }
	// .a and .b are side by side: .b's left edge is at .a's right edge.
	assert b_rect.x == a_rect.x + a_rect.width
	assert a_rect.y == b_rect.y // same cross-start
	// The bar's height is the tallest item (60px).
	assert (root_box.find_box(i64(bar.as_node().unique_id())) or { panic('no bar') }).height == 60.0
}

// Full-stack justify-content: a space-between nav puts the first item at the start and the last at
// the end of the parsed, laid-out bar.
fn test_justify_content_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.nav { display: flex; justify-content: space-between; width: 500px } .item { width: 100px; height: 30px }</style></head><body><div class="nav"><div class="item" id="l"></div><div class="item" id="r"></div></div></body></html>')
	root_box := layout.layout_document(doc, 800)
	root := unsafe { &dom.Node(doc) }
	nav := css.query_selector(root, '.nav') or { panic('no .nav') }
	l := css.query_selector(root, '#l') or { panic('no #l') }
	r := css.query_selector(root, '#r') or { panic('no #r') }

	nav_rect := root_box.bounding_rect_for(nav) or { panic('no .nav box') }
	l_rect := root_box.bounding_rect_for(l) or { panic('no #l box') }
	r_rect := root_box.bounding_rect_for(r) or { panic('no #r box') }
	// first item at the nav's start, last item's right edge at the nav's right edge.
	assert l_rect.x == nav_rect.x
	assert r_rect.x + r_rect.width == nav_rect.x + nav_rect.width // last item pushed to the end
}

// Full-stack align-items: a fixed-height bar centers its items vertically (align-items: center); the
// shorter item is centered within the bar's cross size.
fn test_align_items_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.bar { display: flex; align-items: center; width: 500px; height: 80px } .item { width: 100px; height: 40px }</style></head><body><div class="bar"><div class="item" id="i"></div></div></body></html>')
	root_box := layout.layout_document(doc, 800)
	root := unsafe { &dom.Node(doc) }
	bar := css.query_selector(root, '.bar') or { panic('no .bar') }
	item := css.query_selector(root, '#i') or { panic('no #i') }

	bar_rect := root_box.bounding_rect_for(bar) or { panic('no bar box') }
	item_rect := root_box.bounding_rect_for(item) or { panic('no item box') }
	// The 40px item is centered in the 80px bar: 20px of space above and below.
	assert item_rect.y == bar_rect.y + 20.0
	assert item_rect.y + item_rect.height == bar_rect.y + bar_rect.height - 20.0
}

// Full-stack flex gap: items in a gap:16px row are separated by 16px between adjacent margin boxes.
fn test_flex_gap_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.row { display: flex; gap: 16px; width: 500px } .box { width: 90px; height: 30px }</style></head><body><div class="row"><div class="box" id="p"></div><div class="box" id="q"></div></div></body></html>')
	root_box := layout.layout_document(doc, 800)
	root := unsafe { &dom.Node(doc) }
	p := css.query_selector(root, '#p') or { panic('no #p') }
	q := css.query_selector(root, '#q') or { panic('no #q') }

	p_rect := root_box.bounding_rect_for(p) or { panic('no #p box') }
	q_rect := root_box.bounding_rect_for(q) or { panic('no #q box') }
	// q starts 16px after p's right edge.
	assert q_rect.x == p_rect.x + p_rect.width + 16.0
}

// Full-stack flex-grow: a sidebar has a fixed width and the main area grows to fill the rest of the row.
fn test_flex_grow_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.row { display: flex; width: 600px } .side { width: 200px; height: 40px } .main { flex: 1; height: 40px }</style></head><body><div class="row"><div class="side" id="s"></div><div class="main" id="m"></div></div></body></html>')
	root_box := layout.layout_document(doc, 800)
	root := unsafe { &dom.Node(doc) }
	s := css.query_selector(root, '#s') or { panic('no #s') }
	m := css.query_selector(root, '#m') or { panic('no #m') }

	s_rect := root_box.bounding_rect_for(s) or { panic('no #s box') }
	m_rect := root_box.bounding_rect_for(m) or { panic('no #m box') }
	assert s_rect.width == 200.0 // fixed sidebar
	assert m_rect.width == 400.0 // main grows to fill the remaining 600 - 200
	assert m_rect.x == s_rect.x + s_rect.width // main starts after the sidebar
}

// Full-stack align-items: stretch — a card row makes all cards the height of the tallest, even though
// one card has more content (its natural height is larger).
fn test_align_items_stretch_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.cards { display: flex; width: 600px; font-size: 20px } .card { width: 200px }</style></head><body><div class="cards"><div class="card" id="short">a</div><div class="card" id="tall">a<br>b<br>c</div></div></body></html>')
	root_box := layout.layout_document(doc, 800)
	root := unsafe { &dom.Node(doc) }
	short := css.query_selector(root, '#short') or { panic('no #short') }
	tall := css.query_selector(root, '#tall') or { panic('no #tall') }

	short_rect := root_box.bounding_rect_for(short) or { panic('no #short box') }
	tall_rect := root_box.bounding_rect_for(tall) or { panic('no #tall box') }
	// The 3-line card is taller; stretch grows the 1-line card to the same height.
	assert tall_rect.height > 0.0
	assert short_rect.height == tall_rect.height
}

// Full-stack column flex: a vertical menu stacks its items and centers them horizontally; the second
// item sits below the first plus the row-gap.
fn test_flex_column_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.menu { display: flex; flex-direction: column; align-items: center; row-gap: 8px; width: 240px } .item { width: 120px; height: 36px }</style></head><body><div class="menu"><div class="item" id="one"></div><div class="item" id="two"></div></div></body></html>')
	root_box := layout.layout_document(doc, 800)
	root := unsafe { &dom.Node(doc) }
	menu := css.query_selector(root, '.menu') or { panic('no .menu') }
	one := css.query_selector(root, '#one') or { panic('no #one') }
	two := css.query_selector(root, '#two') or { panic('no #two') }

	menu_rect := root_box.bounding_rect_for(menu) or { panic('no .menu box') }
	one_rect := root_box.bounding_rect_for(one) or { panic('no #one box') }
	two_rect := root_box.bounding_rect_for(two) or { panic('no #two box') }
	// stacked vertically with the 8px row-gap.
	assert two_rect.y == one_rect.y + one_rect.height + 8.0
	// centered horizontally: (240 - 120)/2 = 60 from the menu's left.
	assert one_rect.x == menu_rect.x + 60.0
}

// Full-stack radial-gradient: an author stylesheet gives an element a radial background; it renders
// to an SVG radialGradient with the stop colors.
fn test_radial_gradient_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.orb { width: 120px; height: 120px; background: radial-gradient(circle, rgb(240, 240, 240), rgb(40, 40, 40)) }</style></head><body><div class="orb"></div></body></html>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	orb := css.query_selector(root, '.orb') or { panic('no .orb') }

	orb_box := root_box.find_box(i64(orb.as_node().unique_id())) or { panic('no orb box') }
	grad := orb_box.background_gradient or { panic('no gradient') }
	assert grad.radial == true

	svg := root_box.render_svg(600, root_box.height + 20)
	assert svg.contains('<radialGradient')
	assert svg.contains('stop-color="rgb(240 240 240)"')
	assert svg.contains('stop-color="rgb(40 40 40)"')
}

// Full-stack list-style-type: a parsed ordered list with lower-alpha markers renders a./b./c.
fn test_list_style_type_over_parsed_document() {
	doc := html.parse_document('<body><ol style="list-style-type: lower-alpha"><li>x</li><li>y</li><li>z</li></ol></body>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	lis := css.query_selector_all(root, 'li')
	assert lis.len == 3

	mut markers := []string{}
	for li in lis {
		li_box := root_box.find_box(i64(li.as_node().unique_id())) or { panic('no li box') }
		markers << li_box.lines[0].fragments[0].text
	}
	assert markers == ['a.', 'b.', 'c.']
}

// Full-stack inline-block: a badge with display:inline-block sits inline within a paragraph and is
// laid out as its own box (with its size), painted alongside the text.
fn test_inline_block_over_parsed_document() {
	doc := html.parse_document('<html><head><style>body { margin: 0 } p { margin: 0; font-size: 20px } .badge { display: inline-block; width: 50px; height: 24px; background-color: rgb(200, 0, 0) }</style></head><body><p>x<span class="badge" id="b"></span>y</p></body></html>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	badge := css.query_selector(root, '#b') or { panic('no #b') }

	badge_rect := root_box.bounding_rect_for(badge) or { panic('no badge box') }
	assert badge_rect.width == 50.0
	assert badge_rect.height == 24.0
	// It sits after the 'x' glyph and a space (10px each at 20px font).
	assert badge_rect.x == 20.0

	// Its background reaches the SVG.
	assert root_box.render_svg(600, root_box.height + 20).contains('fill="rgb(200 0 0)"')
}

// Full-stack table: a parsed <table> (with the implicit <tbody>) arranges its cells in a grid —
// columns side by side (wider for wider content), rows stacked, filling the table width.
fn test_table_over_parsed_document() {
	doc := html.parse_document('<body><table style="width: 400px"><tr><td id="a">x</td><td id="b">yyyy</td></tr><tr><td id="c">z</td><td id="d">w</td></tr></table></body>')
	root_box := layout.layout_document(doc, 800)
	root := unsafe { &dom.Node(doc) }
	a := css.query_selector(root, '#a') or { panic('no #a') }
	b := css.query_selector(root, '#b') or { panic('no #b') }
	c := css.query_selector(root, '#c') or { panic('no #c') }

	a_rect := root_box.bounding_rect_for(a) or { panic('no #a box') }
	b_rect := root_box.bounding_rect_for(b) or { panic('no #b box') }
	c_rect := root_box.bounding_rect_for(c) or { panic('no #c box') }
	// Row 1: b is to the right of a and its column (yyyy) is wider than a's (x).
	assert b_rect.x == a_rect.x + a_rect.width
	assert b_rect.width > a_rect.width
	// Row 2: c is below a.
	assert c_rect.y == a_rect.y + a_rect.height
	// Columns fill the 400px table.
	assert a_rect.width + b_rect.width == 400.0
}

// Full-stack grid: a parsed card grid (repeat(3, 1fr), gap) places its cards across three equal
// columns and wraps to the next row.
fn test_grid_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.grid { display: grid; width: 620px; grid-template-columns: repeat(3, 1fr); gap: 10px } .card { height: 50px }</style></head><body><div class="grid"><div class="card" id="c0"></div><div class="card" id="c1"></div><div class="card" id="c2"></div><div class="card" id="c3"></div></div></body></html>')
	root_box := layout.layout_document(doc, 800)
	root := unsafe { &dom.Node(doc) }
	grid := css.query_selector(root, '.grid') or { panic('no .grid') }
	grid_rect := root_box.bounding_rect_for(grid) or { panic('no grid box') }

	mut rects := []layout.LayoutRect{}
	for id in ['c0', 'c1', 'c2', 'c3'] {
		el := css.query_selector(root, '#${id}') or { panic('no #${id}') }
		rects << (root_box.bounding_rect_for(el) or { panic('no box') })
	}
	// Three equal columns of (620 - 2*10 gap)/3 = 200 each.
	assert rects[0].width == 200.0
	assert rects[0].x == grid_rect.x // first column at the grid's left
	assert rects[1].x == grid_rect.x + 210.0 // + 200 + 10 gap
	assert rects[2].x == grid_rect.x + 420.0 // + 2*(200+10)
	// c3 wraps to row 2, column 0.
	assert rects[3].x == grid_rect.x
	assert rects[3].y == rects[0].y + 60.0 // card height 50 + 10 row-gap
}

// Full-stack flex-wrap: a wrapping tag row with a gap breaks tags onto a second line with row-gap.
fn test_flex_wrap_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.tags { display: flex; flex-wrap: wrap; gap: 10px; width: 220px } .tag { width: 100px; height: 24px }</style></head><body><div class="tags"><div class="tag" id="t0"></div><div class="tag" id="t1"></div><div class="tag" id="t2"></div></div></body></html>')
	root_box := layout.layout_document(doc, 800)
	root := unsafe { &dom.Node(doc) }
	mut rects := []layout.LayoutRect{}
	for id in ['t0', 't1', 't2'] {
		el := css.query_selector(root, '#${id}') or { panic('no #${id}') }
		rects << (root_box.bounding_rect_for(el) or { panic('no box') })
	}
	// t0, t1 on line 1 (100 + 10 gap + 100 = 210 <= 220); t2 wraps to line 2.
	assert rects[0].y == rects[1].y // same line
	assert rects[1].x == rects[0].x + 110.0 // 100 + 10 gap
	assert rects[2].x == rects[0].x // line 2, first column
	assert rects[2].y == rects[0].y + 34.0 // 24 height + 10 row-gap
}

// Full-stack grid span: a feature card spans two of three columns; the next card takes the third.
fn test_grid_span_over_parsed_document() {
	doc := html.parse_document('<html><head><style>.g { display: grid; width: 300px; grid-template-columns: repeat(3, 1fr) } .feature { grid-column: span 2; height: 40px } .card { height: 40px }</style></head><body><div class="g"><div class="feature" id="f"></div><div class="card" id="c"></div></div></body></html>')
	root_box := layout.layout_document(doc, 800)
	root := unsafe { &dom.Node(doc) }
	g := css.query_selector(root, '.g') or { panic('no .g') }
	f := css.query_selector(root, '#f') or { panic('no #f') }
	c := css.query_selector(root, '#c') or { panic('no #c') }

	g_rect := root_box.bounding_rect_for(g) or { panic('no g') }
	f_rect := root_box.bounding_rect_for(f) or { panic('no f') }
	c_rect := root_box.bounding_rect_for(c) or { panic('no c') }
	assert f_rect.width == 200.0 // spans two 100px columns
	assert c_rect.width == 100.0 // one column
	assert c_rect.x == g_rect.x + 200.0 // third column
	assert c_rect.y == f_rect.y // same row
}

// Full-stack REAL StyleComputer (not the minimal cascade) over a parser-built document: the whole
// pipeline (css_style_computer_for -> update_style -> bridge -> computed_value_for) resolves inline
// styles + inheritance over the html-parser-built DOM tree.
fn test_real_style_computer_over_parsed_document() {
	doc := html.parse_document('<body style="color: navy"><div><p>text</p><span style="color: red">red</span></div></body>')
	root := unsafe { &dom.Node(doc) }
	body := css.query_selector(root, 'body') or { panic('no body') }
	p := css.query_selector(root, 'p') or { panic('no p') }
	span := css.query_selector(root, 'span') or { panic('no span') }
	color := css.property_id_from_string('color') or { panic('color id') }

	body_color := css.computed_value_for(body, color) or { panic('no computed body color') }
	p_color := css.computed_value_for(p, color) or { panic('no computed p color') }
	span_color := css.computed_value_for(span, color) or { panic('no computed span color') }

	// color inherits from <body> through <div> to <p>; <span> overrides it inline -- all by the REAL StyleComputer.
	assert p_color == body_color
	assert span_color != body_color
}

// Full-stack REAL layout: parse HTML, then lay it out through the real layout engine
// (run_document_layout = build_layout_tree + block flow), producing real box geometry — the whole
// parse -> style -> layout pipeline end to end on the real StyleComputer + real layout engine.
fn test_real_layout_over_parsed_document() {
	doc := html.parse_document('<div style="height: 30px"></div><div style="height: 40px"></div>')
	result := layout.run_document_layout(doc, 800.0, 600.0) or { panic('layout produced no result') }

	// <html> fills the viewport width.
	root_nws := result.root.as_node_with_style() or { panic('root not a NodeWithStyle') }
	root_uv := result.used_values_for(root_nws) or { panic('no root used values') }
	assert root_uv.content_width().to_double() == 800.0

	// <head> is display:none, so <html>'s only box child is <body>.
	assert result.root.children().len == 1
	body_box := result.root.children()[0]
	body_el := (body_box.dom_node() or { panic('body box has no dom node') }).as_element() or {
		panic('body box dom node not element')
	}
	assert body_el.local_name() == 'body'
	// body's UA margin (8px each side) shrinks its content width from 800 to 784.
	body_nws := body_box.as_node_with_style() or { panic('body not nws') }
	body_uv := result.used_values_for(body_nws) or { panic('no body used values') }
	assert body_uv.content_width().to_double() == 784.0

	// The two divs stack inside body with their definite heights.
	assert body_box.children().len == 2
	div1_uv := result.used_values_for(body_box.children()[0].as_node_with_style() or { panic('d1') }) or {
		panic('no div1 used values')
	}
	div2_uv := result.used_values_for(body_box.children()[1].as_node_with_style() or { panic('d2') }) or {
		panic('no div2 used values')
	}
	assert div1_uv.content_height().to_double() == 30.0
	assert div2_uv.content_height().to_double() == 40.0
	assert div2_uv.offset.y().to_double() == 30.0
}
