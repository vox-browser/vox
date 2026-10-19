// HTMLImageElement.idl binding transport. The real HTML model owns image
// selection, request state, decode microtasks/tasks and the Promise capability.
module browserjs

import platform
import css
import dom
import html

pub type ImageReplayHook = fn (&Runtime) !

// The native request model and its element retain the live CORS mode and
// document owner, including for a script-created or adopted image.
pub type ImageRequestFetchHook = fn (&dom.HTMLImageElement, &html.HTMLImageElementModel, dom.URL) !html.DecodedImageData

pub type ImageAsyncRequestFetchHook = fn (&dom.HTMLImageElement, &html.HTMLImageElementModel, dom.URL, html.HTMLImageFetchCompletion)

@[heap]
struct ImageHostRecord {
	key     string
	element &dom.HTMLImageElement
	model   &html.HTMLImageElementModel
}

@[heap]
pub struct ImageHost {
	document   &dom.Document
	settings   &html.EnvironmentSettingsObject
	fetch_hook ?html.HTMLImageFetchHook
	replay     ?ImageReplayHook
mut:
	runtime   &Runtime = unsafe { nil }
	elements  map[string]&dom.Element
	records   map[voidptr]&ImageHostRecord
	prototype voidptr
	closed    bool
	request_fetch_hook ?ImageRequestFetchHook
	async_request_fetch_hook ?ImageAsyncRequestFetchHook
	// One hook for all of this host's images, so no closure per image keeps
	// that image alive after its document is replaced.
	model_fetch_hook ?html.HTMLImageModelFetchHook
	model_async_fetch_hook ?html.HTMLImageModelAsyncFetchHook
}

pub fn ImageHost.create(document &dom.Document, fetch_hook ?html.HTMLImageFetchHook, replay ?ImageReplayHook) !&ImageHost {
	if document.relevant_settings_object() == unsafe { nil } {
		_ = html.WindowModel.create_top_level(document, none, '')!
	}
	mut host := &ImageHost{ document: document, settings: unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }, fetch_hook: fetch_hook, replay: replay }
	for index, element in css.query_selector_all(unsafe { &dom.Node(document) }, '*') {
		host.elements['__element_${index}'] = element
	}
	return host
}

pub fn ImageHost.create_with_request_fetch(document &dom.Document, fetch_hook ImageRequestFetchHook, replay ?ImageReplayHook) !&ImageHost {
	return ImageHost.create_with_request_fetch_hooks(document, fetch_hook, none, replay)
}

pub fn ImageHost.create_with_request_fetch_hooks(document &dom.Document, fetch_hook ImageRequestFetchHook, async_hook ?ImageAsyncRequestFetchHook, replay ?ImageReplayHook) !&ImageHost {
	mut host := ImageHost.create(document, none, replay)!
	host.request_fetch_hook = fetch_hook
	host.async_request_fetch_hook = async_hook
	if hook := async_hook {
		host.model_async_fetch_hook = fn [hook] (model &html.HTMLImageElementModel, resource_url dom.URL, complete html.HTMLImageFetchCompletion) {
			image := model.image_element() or {
				complete(none)
				platform.release_closure(voidptr(complete))
				return
			}
			hook(image, model, resource_url, complete)
		}
	} else {
		host.model_fetch_hook = fn [fetch_hook] (model &html.HTMLImageElementModel, resource_url dom.URL) !html.DecodedImageData {
			image := model.image_element() or { return error('Image request has no element') }
			return fetch_hook(image, model, resource_url)
		}
	}
	for _, element in host.elements {
		if !element.is_html_element() || element.local_name() != 'img' { continue }
		image := unsafe { &dom.HTMLImageElement(element) }
		mut model := host.configure_image_fetch(image)
		if element.has_attribute('src') || element.has_attribute('srcset') {
			model.update_the_image_data(false, false)
		}
	}
	return host
}

fn (host &ImageHost) configure_image_fetch(image &dom.HTMLImageElement) &html.HTMLImageElementModel {
	mut model := html.html_image_element_model_for_dom_element(image)
	if hook := host.model_async_fetch_hook {
		model.set_model_async_fetch_hook(hook)
	} else if hook := host.model_fetch_hook {
		model.set_model_fetch_hook(hook)
	} else {
		model.set_fetch_hook(host.fetch_hook)
	}
	return model
}

pub fn (host &ImageHost) elements_for_binding() map[string]&dom.Element {
	return host.elements.clone()
}

pub fn (host &ImageHost) image_for_binding(wrapper voidptr) !&dom.HTMLImageElement {
	record := host.records[wrapper] or { return error('TypeError: HTMLImageElement receiver is not an image') }
	return record.element
}

fn (mut host ImageHost) element_for_binding(key string) !&dom.Element {
	if element := host.runtime.canvas_element_for_binding(key) {
		host.elements[key] = element
	}
	if element := host.elements[key] {
		if element.is_html_element() && element.local_name() == 'img' { return element }
		return error('TypeError: HTMLImageElement receiver is not an image')
	}
	if !key.starts_with('__created_') {
		return error('TypeError: Image has no owning native element')
	}
	element := dom.create_element(host.document, 'img', 'http://www.w3.org/1999/xhtml', none, none, false)!
	host.elements[key] = element
	return element
}

fn (mut host ImageHost) replay_before_decode() ! {
	if replay := host.replay { replay(host.runtime)! }
}
