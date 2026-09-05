module url

fn test_public_suffix_data_matches_upstream_examples() {
	assert is_public_suffix('com')
	assert is_public_suffix('com.br')
	assert !is_public_suffix('not-a-public-suffix.com')
	assert get_public_suffix('') == none
	assert get_public_suffix('not-a-public-suffix') == none
	assert get_public_suffix('not-a-public-suffix.com')? == 'com'
	assert get_public_suffix('not-a-public-suffix.com.br')? == 'com.br'
	assert get_registrable_domain('www.example.co.uk')? == 'example.co.uk'
}

fn test_host_public_suffix_and_registrable_domain() {
	host := Host.from_string('www.example.co.uk')
	assert host.public_suffix()? == 'co.uk'
	assert host.registrable_domain()? == 'example.co.uk'
	assert Host.from_string('co.uk').registrable_domain() == none
	assert Host.ipv4(0x7f000001).public_suffix() == none
	assert Host.from_string('www.example.co.uk.').public_suffix()? == 'co.uk.'
	assert Host.from_string('www.example.co.uk.').registrable_domain()? == 'example.co.uk.'
}
