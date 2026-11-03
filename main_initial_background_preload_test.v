module main

import html
import layout

fn initial_background_preload_urls(markup string) []string {
	mut document := html.parse_document(markup)
	defer { document.finalize() }
	layout.prepare_initial_resource_styles(document, 320, 200)
	mut found := InitialBackgroundPreloads{}
	collect_initial_background_preloads(document.as_node(), mut found)
	assert document.layout_root == unsafe { nil }
	return found.urls
}

fn test_initial_background_preloads_use_computed_cascade_and_skip_nonpainted_backgrounds() {
	urls := initial_background_preload_urls('<!doctype html><style>.gone{display:none}.contents{display:contents}.hidden{visibility:hidden}.visible{visibility:visible}#overridden{background-image:none!important}</style><div class="gone"><i style="background:url(https://background.test/hidden-subtree.svg)"></i></div><div class="contents" style="background:url(https://background.test/contents.svg)"><p style="background:url(https://background.test/first.svg)"></p></div><div class="hidden" style="background:url(https://background.test/hidden.svg)"><span class="visible" style="background:url(https://background.test/second.svg)"></span></div><p id="overridden" style="background:url(https://background.test/overridden.svg)"></p>')
	assert urls == ['https://background.test/first.svg', 'https://background.test/second.svg']
}

fn test_initial_background_preloads_deduplicate_and_bound_speculative_work() {
	mut markup := '<!doctype html>'
	for index in 0 .. initial_background_preload_limit + 3 {
		markup += '<div style="background:url(https://background.test/${index}.svg),url(https://background.test/${index}.svg)"></div>'
	}
	urls := initial_background_preload_urls(markup)
	assert urls.len == initial_background_preload_limit
	assert urls[0] == 'https://background.test/0.svg'
	assert urls.last() == 'https://background.test/${initial_background_preload_limit - 1}.svg'
}

fn test_initial_background_preloads_leave_gradients_image_sets_and_local_urls_to_paint() {
	urls := initial_background_preload_urls('<!doctype html><div style="background-image:linear-gradient(red,blue),url(data:image/png;base64,AA==),url(file:///tmp/background.svg)"></div><p style="background-image:image-set(url(https://background.test/set.svg) 1x)"></p>')
	assert urls.len == 0
}
