module html

import dom
import page

// The browser installs each navigation's document directly into the existing
// navigable. A replacement must take the traversable's visibility, or rendering
// updates skip it and document.fonts.ready never settles.
fn test_replacement_navigation_document_takes_the_navigable_visibility() {
	owner := page.Page.create(1)!
	url := dom.URL{value: 'https://visibility.example/first'}
	first := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	host := first.cached_navigable() or { panic('missing first navigable') }
	model := navigable_model_for_host(host) or { panic('missing navigable model') }
	assert model.system_visibility_state() == .visible
	assert !first.hidden()
	second_url := dom.URL{value: 'https://visibility.example/second'}
	second := create_navigation_document_for_page(second_url, second_url.origin(), first,
		unsafe { &dom.Page(owner) })!
	assert voidptr(second.cached_navigable() or { panic('missing second navigable') }) == voidptr(host)
	assert second.visibility_state() == 'visible'
	assert !second.hidden()
}
