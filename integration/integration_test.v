module integration

import html
import css
import layout
import dom
import math

fn test_parsed_empty_and_invalid_media_groups() {
	doc :=
		html.parse_document('<style>div { display: none } @media { div.first { display: block } } @media ,, { div.invalid { display: block } }</style><div class="first"></div><div class="invalid"></div>')
	css.sync_document_style_elements(doc)
	mut computer := css.css_style_computer_for(doc)
	root_element := doc.document_element() or { panic('missing document element') }
	css.recompute_style_for_subtree(mut computer, root_element.as_node())
	root := unsafe { &dom.Node(doc) }
	first := css.query_selector(root, '.first') or { panic('missing first') }
	invalid := css.query_selector(root, '.invalid') or { panic('missing invalid') }
	first_style := css.computed_properties_for_element(first) or { panic('missing first style') }
	invalid_style := css.computed_properties_for_element(invalid) or {
		panic('missing invalid style')
	}
	assert first_style.display().is_block_outside()
	assert invalid_style.display().is_none()
}

// Full-stack integration: parse an HTML string with the html parser, then query the resulting DOM
// tree with the css selector engine. Exercises html + dom + css composing end to end.

fn test_parse_then_query() {
	doc :=
		html.parse_document('<body><div id="a"><p class="x">hello</p><p class="y">world</p><a href="u">link</a></div></body>')
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
	assert (css.query_selector(root, 'li:first-child') or { panic('first') }).text_content() or {
		''
	} == 'a'
	assert (css.query_selector(root, 'li:last-child') or { panic('last') }).text_content() or { '' } == 'c'
	assert (css.query_selector(root, 'li.active') or { panic('active') }).text_content() or { '' } == 'b'

	// Parse the active item's inline style declaration and read specified values.
	active := css.query_selector(root, '.active') or { panic('active') }
	block := css.parse_css_property_declaration_block_with_parser(active.get_attribute('style') or {
		''
	})
	assert block.length() == 2
	assert block.get_property_value('color') == 'red'
	assert block.get_property_value('width') == '10px'

	hidden := css.query_selector(root, 'p') or { panic('p') }
	hidden_block := css.parse_css_property_declaration_block_with_parser(hidden.get_attribute('style') or {
		''
	})
	assert hidden_block.get_property_value('display') == 'none'
}

// layout_document is the one-call reflow: parse HTML -> collect <style> author rules -> lay out from
// the root element within the viewport. Verifies author styles reach the cascade during layout.
fn test_layout_document_entry_point() {
	doc :=
		html.parse_document('<html><head><style>.box { height: 40px; width: 120px }</style></head><body><div class="box"></div><p>text here</p></body></html>')

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

// Regression for example.com and the native browser host: vw/vh use the actual content viewport,
// the body's background propagates to the whole canvas, and CSS font attributes reach painting.
fn test_example_domain_layout_matches_browser_viewport() {
	markup := '<!doctype html><html lang="en"><head><title>Example Domain</title><style>body{background:#eee;width:60vw;margin:15vh auto;font-family:system-ui,sans-serif}h1{font-size:1.5em}div{opacity:0.8}a:link,a:visited{color:#348}</style></head><body><div><h1>Example Domain</h1><p>This domain is for use in documentation examples without needing permission. Avoid use in operations.</p><p><a href="https://iana.org/domains/example">Learn more</a></p></div></body></html>'
	doc := html.parse_document(markup)
	root_node := unsafe { &dom.Node(doc) }
	body := css.query_selector(root_node, 'body') or { panic('no body') }
	heading := css.query_selector(root_node, 'h1') or { panic('no heading') }
	paragraph := css.query_selector(root_node, 'p') or { panic('no paragraph') }

	root_box := layout.layout_document_in_viewport(doc, 1024, 656)
	assert doc.viewport_rect() == dom.Rect{0, 0, 1024, 656}
	body_box := root_box.find_box(i64(body.as_node().unique_id())) or { panic('no body box') }
	assert math.abs(body_box.width - 614.4) < 0.01 // 60vw of the real 1024px content viewport
	assert math.abs(body_box.x - 204.8) < 0.01 // margin-inline:auto centers it
	assert math.abs(body_box.margin.top - 98.4) < 0.01 // 15vh of the real 656px viewport

	commands := root_box.paint_commands()
	assert commands[0].kind == 'fill_rect'
	assert commands[0].x == 0 && commands[0].y == 0
	assert commands[0].width == 1024 && commands[0].height == 656
	assert commands[0].color == 'rgb(238 238 238)'
	assert commands.filter(it.kind == 'fill_rect' && it.color == 'rgb(238 238 238)').len == 1
	heading_runs := commands.filter(it.kind == 'draw_text' && it.text == 'Example Domain')
	assert heading_runs.len == 1
	assert heading_runs[0].font_size == 24
	assert heading_runs[0].bold
	heading_glyph_run := heading_runs[0].glyph_run or { panic('missing heading glyph run') }
	assert heading_glyph_run.font().weight == 700

	heading_box := root_box.find_box(i64(heading.as_node().unique_id())) or {
		panic('no heading box')
	}
	heading_fragment := heading_box.lines[0].fragments[0]
	assert heading_fragment.font_size == 24
	assert heading_fragment.bold
	paragraph_box := root_box.find_box(i64(paragraph.as_node().unique_id())) or {
		panic('no paragraph box')
	}
	assert paragraph_box.lines[0].fragments[0].font_size == 16
}

// A top-level positioned box uses the explicit viewport height as its initial containing block,
// rather than the much shorter content height of this document.
fn test_top_level_absolute_position_uses_browser_viewport_height() {
	doc :=
		html.parse_document('<html><head><style>body{margin:0}.badge{position:absolute;left:0;bottom:10px;width:30px;height:20px}</style></head><body><div class="badge"></div></body></html>')
	root_node := unsafe { &dom.Node(doc) }
	badge := css.query_selector(root_node, '.badge') or { panic('no badge') }

	root_box := layout.layout_document_in_viewport(doc, 800, 500)
	badge_box := root_box.find_box(i64(badge.as_node().unique_id())) or { panic('no badge box') }
	assert badge_box.y == 470 // 500px viewport - 10px bottom - 20px height
}

// Full-stack box-sizing: the near-universal `* { box-sizing: border-box }` reset from an author
// <style> reaches layout, so .card's specified 200px width includes its padding+border.
fn test_box_sizing_over_parsed_document() {
	doc :=
		html.parse_document('<html><head><style>* { box-sizing: border-box } .card { width: 200px; padding: 20px; border: 5px solid }</style></head><body><div class="card"></div></body></html>')

	root_box := layout.layout_document(doc, 800)
	card := root_box.children[0].children[0] // html > body > div.card
	assert card.tag_name == 'div'
	assert card.width == 150.0 // 200 - 2*(20 padding + 5 border)
	assert card.border_box().width == 200.0 // border box stays at the specified width
}

// Full-stack min/max: the classic responsive container -- width:auto capped by max-width -- clamps
// against a wide viewport, while a short element is raised to a min-height, all via author <style>.
fn test_min_max_over_parsed_document() {
	doc :=
		html.parse_document('<html><head><style>.wrap { max-width: 600px } .hero { min-height: 300px }</style></head><body><div class="wrap"><div class="hero"></div></div></body></html>')

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
	doc :=
		html.parse_document('<html><head><style>.container { max-width: 960px; margin: 0 auto }</style></head><body><div class="container"></div></body></html>')

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

// Full-stack absolute positioning: the classic "badge pinned to a corner of a relative container".
// The badge is positioned against .rel's padding box and is out of flow.
fn test_absolute_position_over_parsed_document() {
	doc :=
		html.parse_document('<html><head><style>.rel { position: relative; width: 400px; height: 200px } .badge { position: absolute; top: 5px; right: 8px; width: 30px; height: 30px }</style></head><body><div class="rel"><div class="badge"></div></div></body></html>')

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
		'html (0,0) 1000x600', // the initial containing block is the 1000x600 viewport
		'  body (0,0) 1000x600', // body stretches to the root's viewport height
		'    div (220,20) 560x146', // .container: centered (200 margin + 20 pad), 600 border-box -> 560 content
		'      div (232,32) 536x26', // .card: inset by border+padding; 50 border-box height -> 26 content
		'      div (220,86) 560x80', // .rel: y = card bottom 70 + collapsed 16px margin (not stacked below .hidden)
		'        div (740,86) 40x40', // .badge: absolute, pinned to .rel's top-right corner
	].join('\n')
	assert box.tree_repr() == expected
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

// Full-stack getBoundingClientRect: parse a document, lay it out, and read a queried element's
// border-box rectangle in document coordinates.
fn test_bounding_client_rect_over_parsed_document() {
	doc :=
		html.parse_document('<html><head><style>.box { width: 200px; height: 60px; margin-left: 30px }</style></head><body style="margin: 0"><div class="box"></div></body></html>')
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
	doc :=
		html.parse_document('<html><head><style>body { margin: 0 } .a { height: 50px } .b { height: 40px }</style></head><body><div class="a"></div><div class="b"></div></body></html>')
	root_box := layout.layout_document(doc, 400)
	root := unsafe { &dom.Node(doc) }

	// y=20 is inside .a (0..50); y=60 is inside .b (50..90).
	hit_a := root_box.element_at_point(10, 20, root) or { panic('no hit a') }
	assert (hit_a.get_attribute('class') or { '' }) == 'a'
	hit_b := root_box.element_at_point(10, 60, root) or { panic('no hit b') }
	assert (hit_b.get_attribute('class') or { '' }) == 'b'
}

// Full-stack text-transform: parse a document with an author stylesheet that uppercases a paragraph,
// lay it out, and confirm the transform flows through to the rendered inline fragments and the SVG.
fn test_text_transform_over_parsed_document() {
	doc :=
		html.parse_document('<html><head><style>p { text-transform: uppercase }</style></head><body><p>hello world</p></body></html>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	p := css.query_selector(root, 'p') or { panic('no p') }

	// The committed <p> fragment retains the uppercased shaped run.
	p_box := root_box.find_box(i64(p.as_node().unique_id())) or { panic('no p box') }
	mut texts := []string{}
	for line in p_box.lines {
		for frag in line.fragments {
			texts << frag.text
		}
	}
	assert texts == ['HELLO WORLD']

	// And the SVG output draws the uppercased text.
	svg := root_box.render_svg(600, root_box.height + 20)
	assert svg.contains('HELLO')
	assert svg.contains('WORLD')
	assert !svg.contains('hello')
}

// Full-stack visibility: an author stylesheet hides a paragraph's text; it still occupies layout
// space (the following paragraph sits below it) but its text is absent from the SVG output.
fn test_visibility_hidden_over_parsed_document() {
	doc :=
		html.parse_document('<html><head><style>body { margin: 0 } p { margin: 0; height: 20px } .gone { visibility: hidden }</style></head><body><p class="gone">SECRET</p><p class="shown">VISIBLE</p></body></html>')
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
// carries the decoration and the SVG output includes both the word and an underline line.
fn test_text_decoration_over_parsed_document() {
	doc :=
		html.parse_document('<html><head><style>p { text-decoration: underline }</style></head><body><p>linked</p></body></html>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	p := css.query_selector(root, 'p') or { panic('no p') }

	p_box := root_box.find_box(i64(p.as_node().unique_id())) or { panic('no p box') }
	assert p_box.lines[0].fragments[0].decoration.contains('underline')

	// The source-shaped decoration path records a DrawLine, not the former fill-rect approximation.
	cmds := root_box.paint_commands()
	assert cmds.filter(it.kind == 'draw_text').len == 1
	assert cmds.filter(it.kind == 'draw_line').len == 1

	svg := root_box.render_svg(600, root_box.height + 20)
	assert svg.contains('linked')
	assert svg.contains('<line') // the underline
}

// Full-stack list markers: parse a <ul>, lay it out, and confirm each <li> gets
// the generated marker text produced by the current list-item tree builder.
fn test_list_markers_over_parsed_document() {
	doc := html.parse_document('<body><ul><li>alpha</li><li>beta</li></ul></body>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }

	lis := css.query_selector_all(root, 'li')
	assert lis.len == 2
	for li in lis {
		li_box := root_box.find_box(i64(li.as_node().unique_id())) or { panic('no li box') }
		assert li_box.lines[0].fragments[0].text in ['alpha', 'beta']
	}

	commands := root_box.paint_commands()
	markers := commands.filter(it.kind == 'draw_text' && it.text.trim_space() == '•')
	assert markers.len == 2
	svg := root_box.render_svg(600, root_box.height + 20)
	assert svg.contains('alpha')
	assert svg.contains('beta')
	assert svg.count('>• ') == 2
	assert !svg.contains('<ellipse')
}

// Full-stack letter-spacing: an author stylesheet adds letter-spacing to a paragraph; the rendered
// fragment width reflects the widened glyph advances.
fn test_letter_spacing_over_parsed_document() {
	doc :=
		html.parse_document('<html><head><style>p { font: 20px SerenitySans; letter-spacing: 5px }</style></head><body><p>hi</p></body></html>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	p := css.query_selector(root, 'p') or { panic('no p') }

	p_box := root_box.find_box(i64(p.as_node().unique_id())) or { panic('no p box') }
	frag := p_box.lines[0].fragments[0]
	assert frag.text == 'hi'
	assert frag.width == 27.328125 // shaped glyph advances plus 5px spacing per character
}

// Full-stack text-indent: an author stylesheet indents a paragraph's first line; the rendered first
// fragment starts at the indent offset.
fn test_text_indent_over_parsed_document() {
	doc :=
		html.parse_document('<html><head><style>body { margin: 0 } p { margin: 0; font-size: 20px; text-indent: 40px }</style></head><body><p>hello</p></body></html>')
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
	doc :=
		html.parse_document('<html><head><style>.card { width: 200px; height: 100px; background-color: rgb(10, 20, 30); border-radius: 12px }</style></head><body><div class="card"></div></body></html>')
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
	doc :=
		html.parse_document('<html><head><style>.focus { width: 120px; height: 30px; outline: 2px solid rgb(0, 90, 200) }</style></head><body><div class="focus"></div></body></html>')
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
	doc :=
		html.parse_document('<html><head><style>.card { width: 200px; height: 80px; background-color: rgb(255, 255, 255); box-shadow: 3px 5px 10px rgb(0, 0, 0) }</style></head><body><div class="card"></div></body></html>')
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
	assert svg.contains('filter="url(#outer-shadow-blur')
}

// Full-stack @media: an author stylesheet gives .col a base width and a wider one inside a
// min-width media query; the box width depends on the viewport width passed to layout_document.
fn test_media_query_over_parsed_document() {
	markup := '<html><head><style>.col { width: 100px } @media (min-width: 600px) { .col { width: 300px } }</style></head><body><div class="col"></div></body></html>'

	// Narrow viewport: the media query does not match -> base 100px.
	narrow_doc := html.parse_document(markup)
	narrow_root := layout.layout_document(narrow_doc, 500)
	narrow_col := css.query_selector(unsafe { &dom.Node(narrow_doc) }, '.col') or {
		panic('no .col')
	}
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
	doc :=
		html.parse_document('<html><head><style>.hero { width: 300px; height: 120px; background: linear-gradient(to bottom, rgb(10, 20, 30), rgb(200, 210, 220)) }</style></head><body><div class="hero"></div></body></html>')
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

// Full-stack flexbox: an author stylesheet lays a nav's items in a row; they sit side by side and
// the bar's height matches the tallest item.
fn test_flex_row_over_parsed_document() {
	doc :=
		html.parse_document('<html><head><style>.bar { display: flex; width: 600px } .a { width: 120px; height: 40px } .b { width: 80px; height: 60px }</style></head><body><div class="bar"><div class="a"></div><div class="b"></div></div></body></html>')
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
	doc :=
		html.parse_document('<html><head><style>.nav { display: flex; justify-content: space-between; width: 500px } .item { width: 100px; height: 30px }</style></head><body><div class="nav"><div class="item" id="l"></div><div class="item" id="r"></div></div></body></html>')
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
	doc :=
		html.parse_document('<html><head><style>.bar { display: flex; align-items: center; width: 500px; height: 80px } .item { width: 100px; height: 40px }</style></head><body><div class="bar"><div class="item" id="i"></div></div></body></html>')
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
	doc :=
		html.parse_document('<html><head><style>.row { display: flex; gap: 16px; width: 500px } .box { width: 90px; height: 30px }</style></head><body><div class="row"><div class="box" id="p"></div><div class="box" id="q"></div></div></body></html>')
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
	doc :=
		html.parse_document('<html><head><style>.row { display: flex; width: 600px } .side { width: 200px; height: 40px } .main { flex: 1; height: 40px }</style></head><body><div class="row"><div class="side" id="s"></div><div class="main" id="m"></div></div></body></html>')
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
	doc :=
		html.parse_document('<html><head><style>.cards { display: flex; width: 600px; font-size: 20px } .card { width: 200px }</style></head><body><div class="cards"><div class="card" id="short">a</div><div class="card" id="tall">a<br>b<br>c</div></div></body></html>')
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
	doc :=
		html.parse_document('<html><head><style>.menu { display: flex; flex-direction: column; align-items: center; row-gap: 8px; width: 240px } .item { width: 120px; height: 36px }</style></head><body><div class="menu"><div class="item" id="one"></div><div class="item" id="two"></div></div></body></html>')
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
	doc :=
		html.parse_document('<html><head><style>.orb { width: 120px; height: 120px; background: radial-gradient(circle, rgb(240, 240, 240), rgb(40, 40, 40)) }</style></head><body><div class="orb"></div></body></html>')
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

// Full-stack list-style-type: a parsed ordered list paints generated lower-alpha
// marker text as a./b./c.
fn test_list_style_type_over_parsed_document() {
	doc :=
		html.parse_document('<body><ol style="list-style-type: lower-alpha"><li>x</li><li>y</li><li>z</li></ol></body>')
	root_box := layout.layout_document(doc, 600)
	markers := root_box.paint_commands().filter(it.kind == 'draw_text' && it.text.trim_space() in [
		'a.',
		'b.',
		'c.',
	]).map(it.text.trim_space())
	assert markers == ['a.', 'b.', 'c.']
}

// Full-stack inline-block: a badge with display:inline-block sits inline within a paragraph and is
// laid out as its own box (with its size), painted alongside the text.
fn test_inline_block_over_parsed_document() {
	doc :=
		html.parse_document('<html><head><style>body { margin: 0 } p { margin: 0; font: 20px SerenitySans } .badge { display: inline-block; width: 50px; height: 24px; background-color: rgb(200, 0, 0) }</style></head><body><p>x<span class="badge" id="b"></span>y</p></body></html>')
	root_box := layout.layout_document(doc, 600)
	root := unsafe { &dom.Node(doc) }
	badge := css.query_selector(root, '#b') or { panic('no #b') }

	badge_rect := root_box.bounding_rect_for(badge) or { panic('no badge box') }
	assert badge_rect.width == 50.0
	assert badge_rect.height == 24.0
	// The source has no whitespace between `x` and the span, so it sits immediately after the glyph.
	assert badge_rect.x == 12.125

	// Its background reaches the SVG.
	assert root_box.render_svg(600, root_box.height + 20).contains('fill="rgb(200 0 0)"')
}

// Full-stack table: a parsed <table> (with the implicit <tbody>) arranges its cells in a grid —
// columns side by side (wider for wider content), rows stacked, filling the table width.
fn test_table_over_parsed_document() {
	doc :=
		html.parse_document('<body><table style="width: 400px"><tr><td id="a">x</td><td id="b">yyyy</td></tr><tr><td id="c">z</td><td id="d">w</td></tr></table></body>')
	root_box := layout.layout_document(doc, 800)
	root := unsafe { &dom.Node(doc) }
	a := css.query_selector(root, '#a') or { panic('no #a') }
	b := css.query_selector(root, '#b') or { panic('no #b') }
	c := css.query_selector(root, '#c') or { panic('no #c') }

	a_rect := root_box.bounding_rect_for(a) or { panic('no #a box') }
	b_rect := root_box.bounding_rect_for(b) or { panic('no #b box') }
	c_rect := root_box.bounding_rect_for(c) or { panic('no #c box') }
	// Ladybird's UA sheet gives separate-border tables 2px border spacing.
	// Row 1: b is to the right of a and its column (yyyy) is wider than a's (x).
	assert b_rect.x == a_rect.x + a_rect.width + 2.0
	assert b_rect.width > a_rect.width
	// Row 2: c is below a.
	assert c_rect.y == a_rect.y + a_rect.height + 2.0
	// Columns plus the leading, inter-column, and trailing spacing fill the 400px table.
	assert a_rect.width + b_rect.width + 6.0 == 400.0
}

// Full-stack grid: a parsed card grid (repeat(3, 1fr), gap) places its cards across three equal
// columns and wraps to the next row.
fn test_grid_over_parsed_document() {
	doc :=
		html.parse_document('<html><head><style>.grid { display: grid; width: 620px; grid-template-columns: repeat(3, 1fr); gap: 10px } .card { height: 50px }</style></head><body><div class="grid"><div class="card" id="c0"></div><div class="card" id="c1"></div><div class="card" id="c2"></div><div class="card" id="c3"></div></div></body></html>')
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
	doc :=
		html.parse_document('<html><head><style>.tags { display: flex; flex-wrap: wrap; gap: 10px; width: 220px } .tag { width: 100px; height: 24px }</style></head><body><div class="tags"><div class="tag" id="t0"></div><div class="tag" id="t1"></div><div class="tag" id="t2"></div></div></body></html>')
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
	doc :=
		html.parse_document('<html><head><style>.g { display: grid; width: 300px; grid-template-columns: repeat(3, 1fr) } .feature { grid-column: span 2; height: 40px } .card { height: 40px }</style></head><body><div class="g"><div class="feature" id="f"></div><div class="card" id="c"></div></div></body></html>')
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
	mut doc :=
		html.parse_document('<body style="color: navy"><div><p>text</p><span style="color: red">red</span></div></body>')
	doc.set_browsing_context(&dom.BrowsingContext{})
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
	result := layout.run_document_layout(doc, 800.0, 600.0) or {
		panic('layout produced no result')
	}

	// The layout root is the Viewport (pinned to the viewport rectangle); <html> is its single box child.
	viewport_nws := result.root.as_node_with_style() or { panic('viewport not a NodeWithStyle') }
	viewport_uv := result.used_values_for(viewport_nws) or { panic('no viewport used values') }
	assert viewport_uv.content_width().to_double() == 800.0
	assert result.root.children().len == 1
	html_box := result.root.children()[0]

	// <html> fills the viewport width.
	html_nws := html_box.as_node_with_style() or { panic('html not a NodeWithStyle') }
	html_uv := result.used_values_for(html_nws) or { panic('no html used values') }
	assert html_uv.content_width().to_double() == 800.0

	// <head> is display:none, so <html>'s only box child is <body>.
	assert html_box.children().len == 1
	body_box := html_box.children()[0]
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
