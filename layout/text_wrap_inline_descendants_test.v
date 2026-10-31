module layout

import html

fn wrapped_inline_descendant_lines(markup string, extra string) []string {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{width:220px;font:600 16px/24px ui-sans-serif,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;text-wrap:balance;overflow-wrap:break-word;${extra}}</style><div id="target">${markup}</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	mut pending := [result.root]
	for pending.len > 0 {
		node := pending.pop()
		if source := node.dom_node() {
			if element := source.as_element() {
				if element.get_attribute_value('id') == 'target' {
					used := result.used_values_for(node.as_node_with_style() or { panic('style') }) or { panic('used') }
					mut lines := []string{}
					for line in used.line_boxes {
						mut text := ''
						for fragment in line.fragments_ { text += fragment.text() or { '' } }
						lines << text.trim_space()
					}
					return lines
				}
			}
		}
		pending << node.children()
	}
	panic('missing target')
}

fn test_balance_crosses_compatible_nested_inline_text_and_link_boundaries() {
	$if !macos {
		return
	}
	assert wrapped_inline_descendant_lines('<span>Get responses</span> <a>tailored to you</a>', '') == [
		'Get responses',
		'tailored to you',
	]
	assert wrapped_inline_descendant_lines('<span>Get <em style="font-style:normal">responses</em></span> <span>tailored to you</span>', '') == [
		'Get responses',
		'tailored to you',
	]
}

fn test_balance_preserves_descendant_nowrap_and_inline_edge_constraints() {
	$if !macos {
		return
	}
	for markup in [
		'<span style="white-space:nowrap">Get responses tailored to</span> you',
		'<span style="padding-inline:2px">Get responses</span> tailored to you',
	] {
		balanced := wrapped_inline_descendant_lines(markup, '')
		ordinary := wrapped_inline_descendant_lines(markup, 'text-wrap:wrap')
		assert balanced == ordinary
	}
}

fn test_balanced_nested_legal_copy_does_not_leave_the_final_link_orphaned() {
	$if !macos {
		return
	}
	markup := '<span>ChatGPT is AI. By using it, you agree to our <a>Terms</a> &amp; <a>Privacy Policy</a><span>. Chats may be reviewed and used to improve our AI models. </span><a>Learn more</a></span>'
	assert wrapped_inline_descendant_lines(markup, 'width:764px;font-size:12px;font-weight:400;line-height:16px;letter-spacing:-.1px') == [
		'ChatGPT is AI. By using it, you agree to our Terms & Privacy Policy.',
		'Chats may be reviewed and used to improve our AI models. Learn more',
	]
}
