module css

import dom
import os

fn test_local_link_media_mutations_keep_the_live_sheet_and_cssom_edits() {
	directory := os.join_path(os.temp_dir(), 'vox-link-media-${os.getpid()}')
	os.mkdir_all(directory)!
	defer { os.rmdir_all(directory) or {} }
	os.write_file(os.join_path(directory, 'sheet.css'), 'div { color: red }')!
	mut document := dom.Document.create(dom.URL{ value: 'file://${directory}/page.html' })
	mut root := document.create_element_ns(dom.namespace_html_uri, 'html')!
	mut link := document.create_element_ns(dom.namespace_html_uri, 'link')!
	link.set_attribute_value('rel', 'stylesheet')
	link.set_attribute_value('href', 'sheet.css')
	link.set_attribute_value('media', 'screen')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(link.as_node())!
	sync_document_style_elements(document)
	mut sheet := style_sheet_for_owner_node(document, link) or { panic('missing link sheet') }
	assert sheet.base.media.matches()
	assert sheet.insert_rule('span { color: blue }', 1)! == 1
	assert sheet.css_rules().length() == 2

	link.set_attribute_value('media', 'print')
	assert sheet.base.media.media_text() == 'print'
	sync_document_style_elements(document)
	assert !sheet.base.media.matches()
	assert voidptr(style_sheet_for_owner_node(document, link)?) == voidptr(sheet)
	assert sheet.css_rules().length() == 2

	link.remove_attribute('media')
	assert sheet.base.media.media_text() == ''
	sync_document_style_elements(document)
	assert sheet.base.media.matches()
	assert voidptr(style_sheet_for_owner_node(document, link)?) == voidptr(sheet)
	assert sheet.css_rules().length() == 2
}
