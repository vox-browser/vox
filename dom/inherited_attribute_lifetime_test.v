module dom

#include "inherited_attribute_lifetime_test.h"

$if gcboehm ? {
	fn C.vox_inherited_attribute_watch_owner(owner voidptr)
	fn C.vox_inherited_attribute_owner_alive() int
	fn C.vox_inherited_attribute_collect(depth u32)
	fn C.vox_inherited_attribute_run_worker(work fn ())
}

fn inherited_attribute_watch(document &Document) {
	$if gcboehm ? { C.vox_inherited_attribute_watch_owner(voidptr(document)) }
}

fn inherited_attribute_element(document &Document, name string) &Element {
	return document.create_element_ns(namespace_html_uri, name) or { panic(err) }
}

@[noinline]
fn inherited_attribute_language_owner() {
	mut document := Document.create(url_about_blank())
	mut element := inherited_attribute_element(document, 'span')
	mut document_node := document.as_node()
	document_node.append_child(element.as_node()) or { panic(err) }
	element.set_attribute_value('lang', 'fr')
	assert element.lang() or { '' } == 'fr'
	inherited_attribute_watch(document)
	document.finalize()
}

@[noinline]
fn inherited_attribute_direction_owner() {
	mut document := Document.create(url_about_blank())
	mut element := inherited_attribute_element(document, 'input')
	element.set_attribute_value('dir', 'ltr')
	element.set_attribute_value('value', 'Wikipedia')
	assert element.dir() or { Dir.auto_ } == .ltr
	inherited_attribute_watch(document)
	document.finalize()
}

@[noinline]
fn inherited_attribute_auto_direction_owner() {
	mut document := Document.create(url_about_blank())
	mut element := inherited_attribute_element(document, 'div')
	element.set_attribute_value('dir', 'auto')
	mut document_node := document.as_node()
	document_node.append_child(element.as_node()) or { panic(err) }
	mut text := document.create_text_node('abc')
	mut element_node := element.as_node()
	element_node.append_child(text.as_node()) or { panic(err) }
	text.replace_data(0, text.length(), '\u05d0\u05d1\u05d2') or { panic(err) }
	assert text.directionality() or { Directionality.ltr } == .rtl
	assert element.needs_style_update()
	inherited_attribute_watch(document)
	document.finalize()
}

fn inherited_attribute_assert_collectible(work fn ()) {
	$if gcboehm ? {
		C.vox_inherited_attribute_run_worker(work)
		C.vox_inherited_attribute_collect(8)
		C.vox_inherited_attribute_collect(8)
		assert C.vox_inherited_attribute_owner_alive() == 0
	} $else {
		work()
	}
}

fn test_language_invalidation_releases_its_changed_document() {
	inherited_attribute_assert_collectible(inherited_attribute_language_owner)
}

fn test_direction_invalidation_releases_its_changed_document() {
	inherited_attribute_assert_collectible(inherited_attribute_direction_owner)
}

fn test_auto_direction_text_invalidation_releases_its_changed_document() {
	inherited_attribute_assert_collectible(inherited_attribute_auto_direction_owner)
}
