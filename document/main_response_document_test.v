module main

import css
import dom
import encoding.base64
import html
import net
import page
import time

fn serve_image_navigation_response(mut listener net.TcpListener, body string) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	socket.set_read_timeout(2 * time.second)
	mut input := []u8{len: 4096}
	_ := socket.read(mut input) or { panic(err) }
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: Image/PNG; charset=binary\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}') or {
		panic(err)
	}
}

fn test_http_image_navigation_decodes_the_response_as_an_image_without_binary_text() {
	image_data :=
		base64.decode_str('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(3 * time.second)
	defer { listener.close() or {} }
	server := spawn serve_image_navigation_response(mut listener, image_data)
	address := 'http://${listener.addr()!}/image.png'
	loaded := fetch_page(address, '')!
	server.wait()
	assert loaded.url == address
	assert !loaded.markup.contains('<pre>')
	mut owner := page.Page.create(1)!
	mut app := BrowserApp{
		page_model:      owner
		script_policy:   .disabled
		viewport_width:  320
		viewport_height: 200
	}
	app.install_loaded_page(loaded, false)
	mut document := app.document
	defer { document.finalize() }
	assert document.url.serialize() == address
	images := css.query_selector_all(document.as_node(), 'img')
	assert images.len == 1
	assert base64.decode_str(images[0].get_attribute_value('src').all_after(',')) == image_data
	image := unsafe { &dom.HTMLImageElement(images[0]) }
	assert html.html_image_element_is_image_available(image)
	assert html.html_image_element_natural_width(image) == 1
	assert html.html_image_element_natural_height(image) == 1
	assert app.paint_commands.any(it.kind == 'draw_replaced_image')
	assert !app.paint_commands.any(it.kind == 'draw_text')
}

fn test_non_image_navigation_keeps_html_and_escaped_text_documents() {
	markup := '<!doctype html><title>Page</title><p>Content</p>'
	assert browser_navigation_response_markup(markup, 'text/html; charset=utf-8') == markup
	assert browser_navigation_response_markup('<script>bad()</script>&', 'text/plain').contains('<pre>&lt;script&gt;bad()&lt;/script&gt;&amp;</pre>')
	assert browser_navigation_response_markup('bytes', 'invalid<type').contains('<h1>invalid&lt;type</h1>')
}
