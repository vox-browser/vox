module main

import adblock
import html
import layout
import page

fn browser_counter_labels_after_install(tree_only bool) !string {
	filtering := adblock.is_enabled()
	adblock.set_enabled(false)
	defer { adblock.set_enabled(filtering) }
	owner := page.Page.create(1)!
	mut app := BrowserApp{page_model: owner, script_policy: .enabled,
		layout_tree_only: tree_only, viewport_width: 800, viewport_height: 600}
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(LoadedPage{
		url: 'https://counter-navigation.example/'
		content_type: 'text/html'
		markup: '<!doctype html><style>:root{counter-reset:seq}.seq::before{counter-increment:seq;content:"" / counter(seq)}.set::before{counter-set:cnt 5051;content:"" / counter(cnt)}</style><button id="one" class="seq">label</button><h3 id="two" class="seq">label</h3><a href="#" id="three" class="seq">label</a><button id="set" class="set">label</button><script>window.counterPageLoaded=true;</script>'
	}, false)
	assert app.js_messages.len == 0
	initial := app.js_runtime.evaluate_host('JSON.stringify(["one","two","three","set"].map(id=>internals.getComputedLabel(document.getElementById(id))))')!
	changed := app.js_runtime.evaluate_host('document.styleSheets[0].cssRules[2].style.counterSet="cnt 228";internals.getComputedLabel(document.getElementById("set"))')!
	return initial + '/' + changed
}

fn test_installed_counter_alternative_names_with_typed_layout() {
	labels := browser_counter_labels_after_install(true)!
	assert labels == '["1 label","2 label","3 label","5051 label"]/228 label'
}

fn test_installed_counter_alternative_names_with_paint_projection() {
	labels := browser_counter_labels_after_install(false)!
	assert labels == '["1 label","2 label","3 label","5051 label"]/228 label'
}

fn test_generated_counter_names_are_invariant_under_device_layout_scale() {
	for scale in [1.0, 2.0, 3.0] {
		mut document := html.parse_document('<!doctype html><style>:root{counter-reset:seq}.seq::before{counter-increment:seq;content:"" / counter(seq)}.set::before{counter-set:cnt 5051;content:"" / counter(cnt)}.multi{counter-reset:n 10}.multi span::before{counter-increment:n;content:"" / counter(n)}.multi span:nth-child(2)::before{counter-increment:n 2}</style><button id="one" class="seq">label</button><h3 id="two" class="seq">label</h3><a href="#" id="three" class="seq">label</a><button id="set" class="set">label</button><button id="multi" class="multi"><span>alpha</span> <span>beta</span> <span>gamma</span></button><ol start="7"><li id="item">item</li></ol><button id="marker" aria-labelledby="item"></button>')
		defer { document.finalize() }
		document.set_layout_coordinate_scale(scale)
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		for id, expected in {'one':'1 label','two':'2 label','three':'3 label','set':'5051 label','multi':'11 alpha 13 beta 14 gamma','marker':'7. item'} {
			element := document.get_element_by_id(id) or { panic('missing counter fixture') }
			actual := element.as_node().accessible_name(document, .yes)!.fields().join(' ')
			assert actual == expected, 'scale=${scale} id=${id} actual=${actual}'
		}
	}
}
