module layout

import html

// The display list of `source` laid out with automatic height answers, after
// checking that it equals the one produced by measuring every item, and the
// answers and measurements the first layout used.
fn automatic_height_layout(source string) (string, u64, u64) {
	mut painted := []string{}
	mut answered := u64(0)
	mut measured := u64(0)
	for suspended in [false, true] {
		automatic_height_answers_suspended = suspended
		mut document := html.parse_document(source)
		answered_before, measured_before, _ := automatic_height_answer_statistics()
		_ = layout_document_typed_in_viewport(document, 400, 300)
		answered_after, measured_after, _ := automatic_height_answer_statistics()
		if !suspended {
			answered = answered_after - answered_before
			measured = measured_after - measured_before
		} else {
			assert answered_after == answered_before
		}
		painted << (document.record_display_list() or { panic('missing paint') }).dump()
		document.finalize()
	}
	automatic_height_answers_suspended = false
	assert painted[0] == painted[1], source
	return painted[0], answered, measured
}

const automatic_height_style = '<!doctype html><style>body{margin:0}.c{display:flex;flex-direction:column}.r{display:flex}p{margin:6px 0}</style>'

// Block items of column flex containers take their flex base size from the
// layout that just ran, at every nesting depth, and paint as when measured.
fn test_block_items_of_nested_columns_are_not_measured_again() {
	leaf := '<div><p>some text that wraps over a few lines in a narrow column of the page</p><ul><li>one</li><li>two</li></ul></div>'
	mut nested := leaf
	for _ in 0 .. 4 {
		nested = '<div><div class="c">${nested}<div><p>sibling</p></div></div></div>'
	}
	_, answered, measured := automatic_height_layout(automatic_height_style + '<body><div class="c">${nested}</div></body>')
	// Every item is a block container.
	assert answered >= 9
	assert measured == 0
}

// The answer is the automatic content height: min-height, max-height,
// padding, borders, box-sizing and margins of the item apply afterwards, as
// with the measurement.
fn test_answers_precede_the_items_own_constraints() {
	for item_style in ['min-height:120px', 'max-height:20px', 'max-height:20px;overflow:hidden',
		'padding:7px;border:3px solid', 'box-sizing:border-box;padding:9px;min-height:80px',
		'margin:11px 0', 'flex:1', 'flex:0 0 auto', 'flex-basis:content', 'flex-shrink:0;min-height:0',
		'overflow:auto', 'position:relative;top:4px', 'width:50%', 'align-self:flex-start',
		'display:flow-root', 'display:list-item;margin-left:30px'] {
		for container_style in ['', 'height:90px', 'max-height:70px', 'min-height:200px',
			'height:90px;flex-wrap:wrap', 'gap:5px;justify-content:space-between;height:260px'] {
			_, answered, _ := automatic_height_layout(automatic_height_style +
				'<body><div class="c" style="${container_style}"><div style="${item_style}"><p>first paragraph with enough text to wrap in the column</p><p>second</p></div><div><p>tail</p></div></div><p>after</p></body>')
			assert answered > 0, '${item_style} | ${container_style}'
		}
	}
}

// Content whose height depends on the item's own height, floats, tables,
// replaced boxes and inline-level containers inside an answered item.
fn test_answers_match_measurements_for_varied_content() {
	for content in ['<div style="height:50%"><p>half</p></div><p>below</p>',
		'<div style="float:left;width:60px;height:70px"></div><p>beside the float</p>',
		'<div style="float:left;width:60px;height:70px"></div>',
		'<table><tbody><tr><td>cell</td><td>next</td></tr></tbody></table>',
		'<span style="display:inline-block;width:40px;height:33px"></span> text <b>bold</b>',
		'<div class="r"><div style="flex:1"><p>left</p><p>more</p></div><div style="height:100%">right</div></div>',
		'<div class="c"><div><p>inner item</p></div><div class="r"><span>row</span></div></div>',
		'<div style="display:grid;grid-template-columns:1fr 1fr"><p>a</p><p>b</p><p>c</p></div>',
		'<div style="position:absolute;top:0;left:0;height:500px">out of flow</div><p>in flow</p>',
		'<div style="min-height:100%"><p>min</p></div>', '<p style="margin:40px 0">margins</p>',
		'<div style="columns:2"><p>one</p><p>two</p><p>three</p><p>four</p></div>',
		'<textarea rows="3"></textarea><button>ok</button>', ''] {
		_, answered, _ := automatic_height_layout(automatic_height_style +
			'<body><div class="c"><div>${content}</div><div><p>tail</p></div></div></body>')
		assert answered > 0, content
	}
}

// Flex and grid containers, clamped lines and vertical flows are measured:
// their own formatting context runs differently in intrinsic-sizing mode.
fn test_other_formatting_contexts_keep_the_measurement() {
	for item in ['<div class="r" style="flex-wrap:wrap"><span style="width:300px">a</span><span style="width:300px">b</span></div>',
		'<div style="display:grid"><p>a</p></div>',
		'<div style="display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:2;overflow:hidden">one line<br>two<br>three<br>four</div>',
		'<div style="writing-mode:vertical-rl"><p>vertical</p></div>'] {
		_, answered, measured := automatic_height_layout(automatic_height_style +
			'<body><div class="c">${item}</div></body>')
		assert answered == 0, item
		assert measured > 0, item
	}
}
