module url

fn test_default_port_for_scheme() {
	assert default_port_for_scheme('ftp')? == u16(21)
	assert default_port_for_scheme('http')? == u16(80)
	assert default_port_for_scheme('https')? == u16(443)
	assert default_port_for_scheme('ws')? == u16(80)
	assert default_port_for_scheme('wss')? == u16(443)
	// "file" is special but has no default port; other schemes have none.
	assert default_port_for_scheme('file') == none
	assert default_port_for_scheme('mailto') == none
	assert default_port_for_scheme('') == none
}

fn test_is_special_scheme() {
	for scheme in ['ftp', 'file', 'http', 'https', 'ws', 'wss'] {
		assert is_special_scheme(scheme)
	}
	assert !is_special_scheme('mailto')
	assert !is_special_scheme('data')
	assert !is_special_scheme('blob')
	assert !is_special_scheme('')
}

fn test_url_is_special() {
	assert URL{
		scheme: 'https'
	}.is_special()
	assert URL{
		scheme: 'file'
	}.is_special()
	assert !URL{
		scheme: 'mailto'
	}.is_special()
}

fn test_port_or_default() {
	// An explicit port wins.
	assert URL{
		scheme: 'https'
		port:   u16(8080)
	}.port_or_default() == u16(8080)
	// Otherwise the scheme default.
	assert URL{
		scheme: 'https'
	}.port_or_default() == u16(443)
	assert URL{
		scheme: 'http'
	}.port_or_default() == u16(80)
	// A scheme without a default port yields 0.
	assert URL{
		scheme: 'mailto'
	}.port_or_default() == u16(0)
}

fn test_cannot_have_a_username_or_password_or_port() {
	// A non-empty, non-file host can have credentials/port.
	assert !URL{
		scheme: 'https'
		host:   Host.from_string('example.com')
	}.cannot_have_a_username_or_password_or_port()
	assert !URL{
		scheme: 'https'
		host:   Host.ipv4(0)
	}.cannot_have_a_username_or_password_or_port()
	// A null host, an empty host, or the file scheme cannot.
	assert URL{
		scheme: 'https'
	}.cannot_have_a_username_or_password_or_port()
	assert URL{
		scheme: 'https'
		host:   Host.from_string('')
	}.cannot_have_a_username_or_password_or_port()
	assert URL{
		scheme: 'file'
		host:   Host.from_string('example.com')
	}.cannot_have_a_username_or_password_or_port()
}
