module html

import dom

fn test_html_document_exact_construction_and_creation() {
	constructed := HTMLDocument.construct_impl()!
	assert constructed.as_document().url_string() == 'about:blank'
	created := HTMLDocument.create(dom.URL{ value: 'https://example.test/page' })
	assert created.as_document().url_string() == 'https://example.test/page'
}
