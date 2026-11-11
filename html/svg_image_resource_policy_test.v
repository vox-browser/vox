// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module html

import dom
import fetch

__global svg_image_connection_attempts int

fn svg_image_test_connection(_ dom.URL) ! {
	svg_image_connection_attempts++
}

fn test_only_decoded_svg_settings_project_the_data_only_fetch_policy() {
	mut document := dom.Document.create(dom.URL{value: 'https://svg.test/image.svg'})
	defer { document.finalize() }
	document.populate_with_html_head_and_body()!
	_ = WindowModel.create_top_level(document, none, '')!
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut request := fetch.Request.create()
	request.set_client(settings)
	assert !request.client_is_svg_image
	document.set_is_svg_image_document(true)
	request.set_client(settings)
	assert request.client_is_svg_image
	assert request.clone().client_is_svg_image
}

fn test_decoded_svg_suppresses_dns_preconnect_and_non_data_link_requests() {
	mut document := dom.Document.create(dom.URL{value: 'https://svg.test/image.svg'})
	defer { document.finalize() }
	mut model := HTMLLinkElementModel.create(document.url)
	model.set_parser_document(document)
	model.set_href('https://other.test/')
	model.set_connection_hooks(svg_image_test_connection, svg_image_test_connection)
	svg_image_connection_attempts = 0
	model.fetch_and_process_linked_dns_prefetch_resource()
	model.fetch_and_process_linked_preconnect_resource()
	assert svg_image_connection_attempts == 2
	document.set_is_svg_image_document(true)
	model.fetch_and_process_linked_dns_prefetch_resource()
	model.fetch_and_process_linked_preconnect_resource()
	assert svg_image_connection_attempts == 2
	assert model.create_link_request(model.create_link_options()) == none
	model.set_href('data:text/css,p%7Bcolor:red%7D')
	assert model.create_link_request(model.create_link_options()) != none
}
