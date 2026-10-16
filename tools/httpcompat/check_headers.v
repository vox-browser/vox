// Run through tools/httpcompat/check.py so the staged net.http module is used.
module main

import adblock
import browsernet
import net
import net.http
import time

fn main() {
	check_growth_and_wire_roundtrip()!
	check_header_value_copy_mutations()!
	check_late_empty_ad_response_header()!
	check_explicit_cookie_headers()!
	println('HTTP compatibility checks passed: 128+ fields, empty/repeated values, copy ownership, RU response filtering')
}

fn serve_cookie_header_check(mut listener net.TcpListener) []string {
	mut requests := []string{}
	for _ in 0 .. 3 {
		mut socket := listener.accept() or { panic(err) }
		socket.set_read_timeout(time.second)
		mut buffer := []u8{len: 4096}
		count := socket.read(mut buffer) or { panic(err) }
		requests << buffer[..count].bytestr()
		socket.write_string('HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok') or { panic(err) }
		socket.close() or {}
	}
	return requests
}

fn check_explicit_cookie_headers() ! {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(2 * time.second)
	defer { listener.close() or {} }
	server := spawn serve_cookie_header_check(mut listener)
	address := 'http://${listener.addr()!}/'
	mut header := http.new_header(key: .cookie, value: 'session=fixture; duplicate=first')
	header.add(.cookie, 'duplicate=second')
	_ := http.fetch(url: address, header: header)!
	_ := http.fetch(url: address, header: header, cookies: {'extra': 'map'})!
	_ := http.fetch(url: address)!
	requests := server.wait()
	assert requests[0].contains('Cookie: session=fixture; duplicate=first; duplicate=second\r\n')
	assert requests[0].count('Cookie:') == 1
	assert requests[1].contains('Cookie: extra=map; session=fixture; duplicate=first; duplicate=second\r\n')
	assert requests[1].count('Cookie:') == 1
	assert !requests[2].contains('Cookie:')
}

fn check_growth_and_wire_roundtrip() ! {
	mut header := http.new_header()
	for index in 0 .. 128 {
		header.add_custom('X-Field-${index}', 'value-${index}')!
	}
	header.add_custom('X-Empty', '')!
	header.add_custom('X-Repeated', '')!
	header.add_custom('x-repeated', 'second')!
	assert header.keys().len == 131
	assert header.custom_values('X-Repeated') == ['', 'second']
	assert header.contains_custom('X-Empty')
	assert (header.get_custom('X-Field-127') or { panic('missing header') }) == 'value-127'
	wire := header.render(version: .v1_1)
	assert wire.contains('X-Empty: \r\n')
	assert wire.contains('X-Repeated: \r\n')
	parsed := http.parse_response('HTTP/1.1 200 OK\r\n${wire}\r\nbody')!
	assert parsed.body == 'body'
	assert parsed.header.keys().len == 131
	assert parsed.header.custom_values('X-Repeated') == ['', 'second']
	assert (parsed.header.get_custom('X-Empty') or { panic('missing header') }) == ''
	mut common := http.new_header()
	for index in 0 .. 128 {
		common.add(.set_cookie, 'cookie-${index}=value')
	}
	assert common.values(.set_cookie).len == 128
	assert common.values(.set_cookie)[127] == 'cookie-127=value'
	mut configs := []http.HeaderConfig{}
	for index in 0 .. 128 {
		configs << http.HeaderConfig{
			key:   .set_cookie
			value: 'config-${index}'
		}
	}
	assert http.new_header(...configs).values(.set_cookie).len == 128
}

fn check_header_value_copy_mutations() ! {
	mut original := http.new_header()
	original.add_custom('X-First', 'one')!
	original.add_custom('X-Repeated', '')!
	original.add_custom('x-repeated', 'two')!
	original.add(.content_type, 'text/plain')
	original.add(.content_type, 'application/json')
	mut added := original
	added.add_custom('X-New', 'new')!
	assert !original.contains_custom('X-New')
	mut changed := original
	changed.set_custom('x-first', 'changed')!
	assert (original.get_custom('X-First') or { panic('missing header') }) == 'one'
	assert (changed.get_custom('X-First') or { panic('missing header') }) == 'changed'
	changed.set_custom('X-Repeated', '')!
	assert changed.custom_values('x-repeated') == ['']
	assert original.custom_values('X-Repeated') == ['', 'two']
	changed.set(.content_type, 'image/png')
	assert changed.values(.content_type) == ['image/png']
	assert original.values(.content_type) == ['text/plain', 'application/json']
	mut removed := original
	removed.delete_custom('x-first')
	assert !removed.contains_custom('X-First')
	assert original.contains_custom('X-First')
	assert removed.custom_values('x-repeated') == ['', 'two']
	mut joined := original.join(added)
	joined.set_custom('X-First', 'joined')!
	assert (original.get_custom('X-First') or { panic('missing header') }) == 'one'
	assert (added.get_custom('X-First') or { panic('missing header') }) == 'one'
}

fn check_late_empty_ad_response_header() ! {
	mut response := http.Response{
		status_code: 200
		body:        'advertisement'
	}
	for index in 0 .. 100 {
		response.header.add_custom('X-Before-${index}', '${index}')!
	}
	response.header.add_custom('llasalbbubrrl', '')!
	response.header.add_custom('Llasalbbubrrl', 'second')!
	fields := browsernet.response_headers(response)
	assert fields.len == 102
	assert fields[100].name.to_lower() == 'llasalbbubrrl'
	assert fields[100].value == ''
	assert fields[101].value == 'second'
	request := adblock.Request{
		url:          'https://pikabu.ru/ajax/header-overflow-check'
		source_url:   'https://pikabu.ru/'
		request_type: 'xmlhttprequest'
	}
	mut blocked := false
	browsernet.filter_response(request, response) or {
		blocked = err.msg().contains('Blocked by adblock:')
			&& err.msg().contains('responseheader=llasalbbubrrl')
	}
	assert blocked, '101st present-empty RU advertising header bypassed response filtering'
	browsernet.filter_response(adblock.Request{
		url:          request.url
		source_url:   request.source_url
		request_type: 'main_frame'
	}, response)!
}
