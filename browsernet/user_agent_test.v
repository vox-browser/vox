module browsernet

import adblock
import dom
import loader
import net
import net.http
import time

fn serve_user_agent_redirect(mut listener net.TcpListener) []string {
	mut agents := []string{}
	for hop in 0 .. 2 {
		mut socket := listener.accept() or { panic(err) }
		socket.set_read_timeout(2 * time.second)
		mut input := []u8{len: 4096}
		count := socket.read(mut input) or { panic(err) }
		request := http.parse_request_head_str(input[..count].bytestr()) or { panic(err) }
		agents << request.header.get(.user_agent) or { '' }
		response := if hop == 0 {
			'HTTP/1.1 302 Found\r\nLocation: /final\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
		} else {
			'HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok'
		}
		socket.write_string(response) or { panic(err) }
		socket.close() or {}
	}
	return agents
}

fn test_browser_requests_use_the_navigator_default_user_agent() {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(3 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	server := spawn serve_user_agent_redirect(mut listener)
	result := get(adblock.Request{url: '${address}/start', request_type: 'main_frame'}, '')!
	assert result.response.body == 'ok'
	assert server.wait() == [loader.default_user_agent(), loader.default_user_agent()]
}

fn test_browser_redirects_recompute_configured_site_user_agents() {
	mut resource_loader := loader.initialize()
	resource_loader.set_user_agent('Mozilla/5.0 Ladybird/1.0 TestBrowser/1.0')
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(3 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	mut compatibility := loader.SiteCompatibilityData{}
	compatibility.add_rule(loader.SiteCompatibilityRule.create(['${address}/final'], [.hide_ladybird], [])!)
	resource_loader.set_site_compatibility_data(compatibility)
	server := spawn serve_user_agent_redirect(mut listener)
	result := get(adblock.Request{url: '${address}/start', request_type: 'script'}, '')!
	assert result.response.body == 'ok'
	assert server.wait() == [
		resource_loader.user_agent_for_url(dom.URL{value: '${address}/start'}),
		resource_loader.user_agent_for_url(dom.URL{value: '${address}/final'}),
	]
	assert resource_loader.user_agent_for_url(dom.URL{value: '${address}/final'}) == 'Mozilla/5.0 TestBrowser/1.0'
}
