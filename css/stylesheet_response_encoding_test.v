module css

import dom

fn test_stylesheet_bom_overrides_transport_and_environment_encoding() {
	for big_endian in [true, false] {
		mut bytes := if big_endian { [u8(0xfe), 0xff] } else { [u8(0xff), 0xfe] }
		for byte in 'html{--image:url(image.png)}'.bytes() {
			if big_endian { bytes << u8(0); bytes << byte } else { bytes << byte; bytes << u8(0) }
		}
		assert css_decode_bytes('windows-1252', 'utf-8', bytes)! == 'html{--image:url(image.png)}'
		url := 'https://encoding.test/${big_endian}.css'
		set_remote_link_style_sheet(url, bytes.bytestr())
		text := remote_link_style_sheets[url].css_text
		assert text == 'html{--image:url(image.png)}'
		assert parse_css_stylesheet_with_parser(text, url).rules.rules.len == 1
		mut document := dom.Document.create(dom.URL{value:'https://encoding.test/page.html'})
		mut link := document.create_element_ns(dom.namespace_html_uri, 'link')!
		link.set_attribute_value('rel', 'stylesheet')
		link.set_attribute_value('href', url)
		sheet := install_link_style_sheet(unsafe { &dom.HTMLLinkElement(link) }, bytes.bytestr(), url, false)
		assert sheet.rules.rules.len == 1
		declaration := sheet.rules.rules[0].style() or { panic('style rule') }
		assert declaration.custom_property('--image') != none
		// A redirect changes the resource base, while CSSOM keeps the original
		// URL and the response bytes still need BOM decoding before parsing.
		response_url := 'https://cdn.encoding.test/assets/${big_endian}.css'
		redirected := install_link_style_sheet_with_base(unsafe { &dom.HTMLLinkElement(link) },
			bytes.bytestr(), url, false, response_url)
		assert redirected.rules.rules.len == 1
		assert redirected.href()? == url
		assert redirected.base_url_for_bindings()? == response_url
		assert !redirected.base.origin_clean
		document.finalize()
	}
	assert css_decode_bytes(none, 'windows-1252', [u8(0xef), 0xbb, 0xbf, 0xc3, 0xa9])! == 'é'
}
