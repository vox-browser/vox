module svg

fn test_decode_fragment_identifier_percent_decodes_utf8() {
	assert decode_fragment_identifier('paint%20server') == 'paint server'
	assert decode_fragment_identifier('%E2%9C%93') == '✓'
	assert decode_fragment_identifier('plain-id') == 'plain-id'
	assert local_fragment_identifier('#a%2Fb')? == 'a/b'
	assert local_fragment_identifier('other.svg#a') == none
}

fn test_decode_fragment_identifier_replaces_invalid_utf8() {
	assert decode_fragment_identifier('%FF') == '�'
	assert decode_fragment_identifier('%E2%28%A1') == '�(�'
	assert decode_fragment_identifier('%EF%BB%BFid') == '﻿id'
	assert decode_fragment_identifier('%GG') == '%GG'
}

fn test_svg_resource_lookups_share_fragment_decoding() {
	target := Element{ tag: 'linearGradient' }
	document := {
		'paint server': target
		'%32':          Element{ tag: 'pattern' }
	}
	element := new_element('rect')
	assert element.resolve_url_to_element('url(#paint%20server)', document)?.tag == 'linearGradient'
	assert element.resolve_url_to_element('#%2532', document)?.tag == 'pattern'
	assert resolve_geometry_reference('#shape%2Fone', {
		'shape/one': Element{ tag: 'rect' }
	})?.tag == 'rect'

	mut use_reference := UseReference{}
	use_reference.process_url('#paint%20server', document)
	assert use_reference.target_id == 'paint server'
	assert use_reference.state == .ready
}
