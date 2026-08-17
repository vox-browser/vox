@[has_globals]
module html

import dom

__global navigation_requests []EmbeddedNavigationRequest

fn embedded_navigation_hook(request EmbeddedNavigationRequest) ! {
	navigation_requests << request
}

fn embedded_object_fetch(url dom.URL) !ObjectResourceResponse {
	if url.serialize().ends_with('.png') {
		return ObjectResourceResponse{
			content_type: 'image/png'
			bitmap:       &dom.ImmutableBitmap_{
				width:  20
				height: 10
				pitch:  80
				data:   []u8{len: 800}
			}
		}
	}
	if url.serialize().ends_with('.html') {
		return ObjectResourceResponse{
			content_type: 'text/html'
			body:         '<p>child</p>'.bytes()
		}
	}
	return error('network error')
}

fn test_navigable_container_origin_navigation_and_destruction() {
	mut container := NavigableContainerModel.create(dom.URL{ value: 'https://example.test/a/' }, dom.Origin{
		value: 'https://example.test'
	})
	container.set_name('frame')
	container.set_src('child.html')
	container.set_navigation_hook(embedded_navigation_hook)
	navigable := container.create_new_child_navigable()
	assert navigable.target_name == 'frame'
	url := container.shared_attribute_processing_steps(.yes, [])?
	container.navigate_an_iframe_or_frame(url, .origin, none, .yes)!
	assert navigation_requests.last().url.serialize() == 'https://example.test/a/child.html'
	assert container.content_document() != none
	mut child := navigable.active_document
	child.origin = dom.Origin{
		value: 'https://cross-origin.test'
	}
	assert container.content_document() == none
	assert container.content_document_without_origin_check() != none
	container.destroy_the_child_navigable()
	assert container.content_navigable() == none
}

fn test_iframe_srcdoc_sandbox_lazy_loading_and_events() {
	mut iframe := HTMLIFrameElementModel.create(dom.URL{ value: 'https://example.test/' }, dom.Origin{
		value: 'https://example.test'
	})
	iframe.set_navigation_hook(embedded_navigation_hook)
	iframe.set_sandbox('allow-scripts')
	iframe.set_loading_lazy(true)
	iframe.set_srcdoc('<h1>Hello</h1>')
	iframe.post_connection(true, [])!
	assert iframe.current_navigation_was_lazy_loaded()
	assert iframe.event_count('load') == 0
	assert iframe.iframe_sandboxing_flag_set().contains(.sandboxed_origin)
	assert !iframe.iframe_sandboxing_flag_set().contains(.sandboxed_scripts)
	iframe.resume_lazy_load()
	assert iframe.event_count('load') == 1
	navigable := iframe.container.content_navigable()?
	assert navigable.active_document.url.serialize() == 'about:srcdoc'
	assert navigable.last_srcdoc? == '<h1>Hello</h1>'
	iframe.removed_from_document()
	assert iframe.container.content_navigable() == none
}

fn test_object_representation_image_document_and_fallback() {
	mut object := HTMLObjectElementModel.create(dom.URL{ value: 'https://example.test/' }, dom.Origin{
		value: 'https://example.test'
	})
	object.set_fetch_hook(embedded_object_fetch)
	object.set_data('/image.png')
	object.run_object_representation_steps()
	assert object.representation() == .image
	assert object.image_data()?.width == 20
	assert object.event_count('load') == 1

	object.set_data('/child.html')
	object.run_object_representation_steps()
	assert object.representation() == .content_navigable
	assert object.container.content_document_without_origin_check()?.content_type == 'text/html'

	object.set_data('/missing.bin')
	object.run_object_representation_steps()
	assert object.representation() == .children
	assert object.event_count('error') == 1
}

fn test_embed_and_object_presentational_hints() {
	hints := embedded_presentational_hints({
		'align':  'CENTER'
		'width':  '320'
		'height': '200'
		'hspace': '4'
		'vspace': '6'
		'border': '2'
	}, true)
	assert hints.text_align? == 'center'
	assert hints.width? == 320
	assert hints.height? == 200
	assert hints.margin_left? == 4
	assert hints.margin_top? == 6
	assert hints.border_width? == 2
}
