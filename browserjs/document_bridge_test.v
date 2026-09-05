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
