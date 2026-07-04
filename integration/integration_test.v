module integration

import html
import css
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
