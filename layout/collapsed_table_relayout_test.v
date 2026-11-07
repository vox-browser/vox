module layout

import html

// GitHub's README tables are display:block, width:max-content tables with
// collapsed borders. A later image load relayouts the page; the cached
// intrinsic widths must still restore the table's outer border shares, or the
// wrapper loses 1px and the columns shrink below their max-content widths.
fn test_collapsed_table_columns_survive_a_relayout_with_cached_intrinsic_widths() {
	source := '<!doctype html><style>body{margin:0;font:16px/1.5 Arial}
	.m{width:838px}
	table{border-spacing:0;border-collapse:collapse;width:max-content;max-width:100%;display:block;overflow:auto}
	th,td{border:1px solid #ccc;padding:6px 13px}
	code{white-space:break-spaces;padding:.2em .4em;font-size:85%;font-family:Menlo}
	</style><article class="m"><table id="t"><thead><tr><th id="a">Tag</th><th id="b">Base</th><th id="c">Notes</th></tr></thead><tbody>
	<tr><td><code>:latest</code>, <code>:debian</code></td><td>Debian</td><td>the default: programs built here run on Debian, Ubuntu, Fedora</td></tr>
	<tr><td><code>:static-&lt;version&gt;</code></td><td><code>scratch</code></td><td>a static V compiler; base for compiled static programs</td></tr>
	</tbody></table></article>'
	mut document := html.parse_document(source)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut passes := [][]f64{}
	for _ in 0 .. 3 {
		run_document_layout(document, 1000, 400) or { panic('layout') }
		mut widths := []f64{}
		for id in ['t', 'a', 'b', 'c'] {
			widths << (document.get_element_by_id(id) or { panic(id) }).get_bounding_client_rect().width
		}
		passes << widths
		mut body := document.body() or { panic('body') }
		body.as_node().set_needs_layout_update(.style_change)
	}
	// The columns fill the table's border box less its two 0.5px outer shares.
	assert passes[0][1] + passes[0][2] + passes[0][3] == passes[0][0] - 1
	assert passes[1] == passes[0]
	assert passes[2] == passes[0]
}
