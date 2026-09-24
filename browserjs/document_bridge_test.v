module browserjs

import css
import dom
import html
import layout

fn bridge_test_element(document &dom.Document, selector string) &dom.Element {
	return css.query_selector(unsafe { &dom.Node(document) }, selector) or {
		panic('missing ${selector}')
	}
}

fn test_document_bridge_selected_index_runs_select_model_and_rebuilds_its_shadow_label() {
	$if darwin {
		mut document := html.parse_document('<select id="select"><option>Value 0</option><option>Value 1</option></select><script>select.selectedIndex = 1;</script>')
		document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
		mut runtime := Runtime.create()
		defer {
			runtime.close()
		}
		run_inline_document_scripts(document, 'about:blank', runtime)!

		select_element := bridge_test_element(document, '#select')
		select_control := unsafe { &dom.HTMLSelectElement(select_element) }
		assert html.html_select_element_selected_index(select_control) == 1
		shadow := select_element.shadow_root() or { panic('missing select shadow root') }
		border := unsafe { &dom.Node(shadow) }.first_child() or { panic('missing select border') }
		inner := border.first_child() or { panic('missing select label') }
		assert inner.child_text_content() == 'Value 1'

		snapshot := layout.dump_document_layout_snapshot(document, 800, 600) or {
			panic('layout failed')
		}
		assert snapshot.contains('"Value 1"')
		assert !snapshot.contains('"Value 0"')
	}
}

fn test_document_bridge_input_type_uses_one_shadow_tree_and_password_text_flag() {
	$if darwin {
		mut document := html.parse_document('<input id="input" type="text" value="hunter2"><script>input.type = "password";</script>')
		document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
		mut runtime := Runtime.create()
		defer {
			runtime.close()
		}
		run_inline_document_scripts(document, 'about:blank', runtime)!

		input_element := bridge_test_element(document, '#input')
		input_control := unsafe { &dom.HTMLInputElement(input_element) }
		model := html.HTMLInputElementModel.create(input_control)
		assert model.type_state() == .password
		shadow := input_element.shadow_root() or { panic('missing input shadow root') }
		shadow_children := unsafe { &dom.Node(shadow) }.children_as_vector()
		assert shadow_children.len == 1
		inner := shadow_children[0].first_child() or { panic('missing input inner text') }
		text := inner.first_child() or { panic('missing input text') }
		assert text.is_text()
		assert unsafe { &dom.Text(text) }.is_password_input()

		snapshot := layout.dump_document_layout_snapshot(document, 800, 600) or {
			panic('layout failed')
		}
		assert snapshot.count('flex-container(row)') == 1
		assert snapshot.contains('"●●●●●●●"')
		assert !snapshot.contains('"hunter2"')
	}
}

fn test_document_bridge_canvas_draw_image_snapshots_cross_canvas_and_self_sources() {
	$if darwin {
		mut document := html.parse_document('<canvas id="a" width="4" height="2"></canvas><canvas id="b" width="4" height="2"></canvas><script>const ca=a.getContext("2d"),cb=b.getContext("2d");ca.fillStyle="red";ca.fillRect(0,0,4,2);cb.drawImage(a,0,0);ca.fillStyle="blue";ca.fillRect(0,0,2,2);ca.drawImage(a,2,0);</script>')
		document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
		mut runtime := Runtime.create()
		defer {
			runtime.close()
		}
		run_inline_document_scripts(document, 'about:blank', runtime)!

		a_element := bridge_test_element(document, '#a')
		b_element := bridge_test_element(document, '#b')
		a_bitmap := html.html_canvas_element_present_existing_surface(unsafe {
			&dom.HTMLCanvasElement(a_element)
		}) or { panic('missing canvas A surface') }
		b_bitmap := html.html_canvas_element_present_existing_surface(unsafe {
			&dom.HTMLCanvasElement(b_element)
		}) or { panic('missing canvas B surface') }
		// B captured A while it was entirely red.
		assert b_bitmap.data[..4] == [u8(255), 0, 0, 255]
		assert b_bitmap.data[12..16] == [u8(255), 0, 0, 255]
		// A's self-draw samples the pre-draw state, so its blue left half is
		// copied to the right half instead of being read incrementally.
		assert a_bitmap.data[..4] == [u8(0), 0, 255, 255]
		assert a_bitmap.data[12..16] == [u8(0), 0, 255, 255]
	}
}

fn test_document_bridge_applies_async_created_elements_and_set_property_styles() {
	$if darwin {
		mut document := html.parse_document('<div id="host"></div><script>Promise.resolve().then(() => { const child = document.createElement("div"); child.className = "late"; child.style.setProperty("mask-image", "linear-gradient(black, black)"); host.appendChild(child); });</script>')
		document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
		mut runtime := Runtime.create()
		defer {
			runtime.close()
		}
		run_inline_document_scripts(document, 'about:blank', runtime)!

		child := bridge_test_element(document, '.late')
		parent := child.parent_element() or { panic('missing host parent') }
		assert parent.get_attribute_value('id') == 'host'
		assert child.get_attribute_value('style') == 'mask-image: linear-gradient(black, black)'
	}
}

fn test_document_bridge_replays_style_sheet_insert_rule_into_live_cssom_sheet() {
	$if darwin {
		mut document := html.parse_document('<style id="style">div::after { content: counter(a, dynamic-counter-style); }</style><div style="counter-reset: a 5"></div><script>style.sheet.insertRule(\'@counter-style dynamic-counter-style { symbols: "*"; }\', 0);</script>')
		document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
		mut runtime := Runtime.create()
		defer {
			runtime.close()
		}
		run_inline_document_scripts(document, 'about:blank', runtime)!

		registered := css.registered_counter_styles_for_document(document)
		style := registered['dynamic-counter-style'] or { panic('inserted counter style missing') }
		assert css.generate_a_counter_representation(style, registered, 5) == '*****'
		snapshot := layout.dump_document_layout_snapshot(document, 800, 600) or {
			panic('layout failed')
		}
		assert snapshot.contains('"*****"')
	}
}

fn test_document_bridge_replays_constructed_adopted_style_sheet_replacement() {
	$if darwin {
		mut document := html.parse_document('<div style="counter-reset: a 5"></div><script>let sheet = new CSSStyleSheet(); sheet.replaceSync(\'div::after { content: counter(a, dynamic-counter-style); }\'); document.adoptedStyleSheets = [sheet]; sheet.replaceSync(\'@counter-style dynamic-counter-style { symbols: "*"; } div::after { content: counter(a, dynamic-counter-style); }\');</script>')
		document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
		mut runtime := Runtime.create()
		defer {
			runtime.close()
		}
		run_inline_document_scripts(document, 'about:blank', runtime)!

		registered := css.registered_counter_styles_for_document(document)
		style := registered['dynamic-counter-style'] or { panic('adopted counter style missing') }
		assert css.generate_a_counter_representation(style, registered, 5) == '*****'
		snapshot := layout.dump_document_layout_snapshot(document, 800, 600) or {
			panic('layout failed')
		}
		assert snapshot.contains('"*****"')
	}
}
