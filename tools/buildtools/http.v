module buildtools

import os
import json2 as json

fn snippets() Record {
	return json.parse($embed_file('snippets.json').to_string()) or { panic(err) }.as_map()
}

fn snippet(key string) string {
	return (snippets()[key] or { panic('Missing build adapter snippet: ' + key) }).str()
}

fn compiler_vlib(selected string, work string) !string {
	tmp := temporary(work, 'compiler-root-')!
	defer { remove(tmp) or {} }
	probe := join(tmp, 'compiler_root.v')
	os.write_file(probe, "module main\nimport os\nfn main() {\n executable := os.args[0]\n if executable.trim_space() == '' || executable.to_lower_ascii() == '' { exit(2) }\n println(@VEXEROOT)\n}\n")!
	mut env := os.environ()
	env['V_MACOS_V3_NO_FALLBACK'] = '1'
	mut process := os.new_process(selected)
	process.set_args(['-b', 'c', '-memory-limit', '10G', 'run', probe])
	process.set_environment(env)
	process.set_redirect_stdio()
	process.run()
	output := process.stdout_slurp()
	errors := process.stderr_slurp()
	process.wait()
	code := process.code
	process.close()
	if code != 0 {
		return error('V compiler/runtime probe failed for ' + selected + '. Set V_BIN to a compiler with its matching vlib.\n' + if errors.len > 4000 {
			errors[errors.len - 4000..]
		} else {
			errors
		})
	}
	return real(join(output.trim_space(), 'vlib'))
}

fn private_helper(source string, name string) !string {
	signature := 'fn ${name}('
	if !source.contains(signature) { return source }
	start, end := function_span(source, signature)!
	mut first := start
	mut candidate := start
	mut notes := false
	for candidate > 0 {
		previous_end := if source[candidate - 1] == `\n` { candidate - 1 } else { candidate }
		previous_start := (source[..previous_end].last_index('\n') or { -1 }) + 1
		line := source[previous_start..previous_end].trim_space()
		if line.starts_with('//') || line.starts_with('@[') {
			notes = true
			candidate = previous_start
			first = candidate
		} else if line.len == 0 {
			candidate = previous_start
			if notes { first = candidate }
		} else {
			break
		}
	}
	if !notes { first = start }
	last := if end < source.len && source[end] == `\n` { end + 1 } else { end }
	remaining := source[..first] + source[last..]
	code := remaining.split_into_lines().map(it.all_before('//')).join('\n')
	if code.contains(name) { return source }
	return remaining
}

fn patch_header(source string) !string {
	mut text := replace_once(source, 'data [max_headers]HeaderKV', 'data []HeaderKV')!
	text = text.replace_once('pub const max_headers = 50', '// Retained for source compatibility; Header storage grows beyond this value.\npub const max_headers = 50')
	for signature, replacement in (snippets()['header_replacements'] or { panic('Missing header replacements') }).as_map() {
		text = replace_function(text, signature, replacement.str())!
	}
	text += snippet('header_value_replacement')
	return private_helper(text, 'header_value_without_ows')
}

fn patch_response(source string) !string {
	if source.count('import x.compress.brotli\n') == 1 && !source.contains('import compress.brotli\n') {
		return source
	}
	return replace_once(source, 'import compress.brotli\n', 'import x.compress.brotli\n')
}

fn patch_brotli(source string) !string {
	marker := 'import compress.brotli as native_brotli\n'
	if !source.contains(marker) {
		if source.contains('native_brotli.') { return error('Unsupported native Brotli encoder') }
		return source
	}
	mut text := source.replace_once(marker, '')
	start := text.index('\n\tif ') or { return error('Missing Brotli native branch') }
	// Locate the optional native encoder's outer conditional, not an earlier check.
	native := text.index('native_brotli.compress(data,') or { return error('Missing native Brotli call') }
	begin := text[..native].last_index('\n\tif ') or { return error('Missing Brotli native branch') }
	end := text.index_after('\n\t\t}\n\t}\n', native) or { return error('Missing Brotli native branch end') }
	_ = start
	text = text[..begin] + '\n' + text[end + '\n\t\t}\n\t}\n'.len..]
	if text.contains('native_brotli') { return error('Unsupported optional native Brotli encoder') }
	return text.replace('// Large inputs without metadata, custom dictionaries, or large windows may use\n// the system encoder when available; other inputs use the V encoder.\n', '// Vox always uses the V encoder, including large inputs.\n')
}

fn patch_request(source string) !string {
	mut text := source
	for text.contains('u64(usize(') {
		start := text.index('u64(usize(') or { break }
		end := text.index_after('))', start) or { return error('Unsupported request pointer cast') }
		text = text[..start] + 'u64(voidptr(' + text[start + 10..end] + '))' + text[end + 2..]
	}
	if text.contains('fn (req &Request) method_and_url_to_response(') {
		old := "p := url.escaped_path().trim_left('/')\n\tpath := if url.query().len > 0 { '/\${p}?\${url.query().encode()}' } else { '/\${p}' }"
		if text.count(old) == 1 {
			text = text.replace_once(old, 'path := url.request_uri()')
		} else if text.count('path := url.request_uri()') != 1 {
			return error('Unsupported HTTP request target')
		}
	}
	if !text.contains('cookie_header_value_with_header(header)') {
		start, end := function_span(text, 'fn (req &Request) build_request_cookies_header_with_header(header Header) string')!
		body := replace_once(text[start..end], "if req.cookies.len < 1 {\n\t\treturn ''\n\t}", "if req.cookies.len < 1 {\n\t\tvalues := header.values(.cookie)\n\t\treturn if values.len == 0 { '' } else { 'Cookie: ' + values.join('; ') + '\\r\\n' }\n\t}")!
		text = text[..start] + body + text[end..]
	}
	text = patch_receive_buffer(text)!
	return replace_once(text, 'if req.proxy == unsafe { nil } && !req.disable_connection_reuse', 'if (req.proxy == unsafe { nil } || vox_transport_tunnels_proxy()) && !req.disable_connection_reuse')
}

fn patch_receive_buffer(source string) !string {
	if source.contains('mut received := VoxHTTPReceiveBuffer{}') { return source }
	start, end := function_span(source, 'fn (req &Request) receive_all_data_from_cb_in_builder(mut content strings.Builder, con voidptr, receive_chunk_cb FnReceiveChunk) !ReceivedResponseInfo')!
	mut body := source[start..end]
	for old, count in {
		'content.write_ptr(': 2
		'content.write(':     1
		'content.len':        1
	} {
		if body.count(old) != count {
			return error('Unsupported HTTP receive-buffer write: ${old}')
		}
		body = body.replace(old, old.replace('content.', 'received.'))
	}
	entry := body.index('{') or { return error('Missing receive function body') }
	if body[entry + 1..].contains('content.') {
		return error('Unsupported HTTP receive-buffer access')
	}
	body = body[..entry + 1] + snippet('receive_buffer_entry') + body[entry + 1..]
	return source[..start] + body + source[end..]
}

fn patch_proxy(source string) !string {
	mut text := source
	if text.count('struct HttpProxy {') != 1 { return error('Unsupported HTTP proxy declaration') }
	if !text.contains('pub struct HttpProxy {') {
		text = text.replace_once('struct HttpProxy {', 'pub struct HttpProxy {')
	}
	old := "pr.ssl_dial('\${host_name}:\${port}')"
	new := "pr.ssl_dial('\${host_name}:\${port}', req)"
	mut signature := 'fn (pr &HttpProxy) ssl_dial(host string) !&ssl.SSLConn'
	if text.count(old) == 1 && text.count(signature) == 1 {
		text = text.replace_once(old, new)
	} else {
		signature = 'fn (pr &HttpProxy) ssl_dial(host string, req &Request) !&ssl.SSLConn'
		if text.count(new) != 1 || text.count(signature) != 1 {
			return error('Unsupported HTTP proxy TLS call')
		}
	}
	target := "'\${host.scheme}://\${host_name}\${port_part}\${path}', data, header)"
	if text.count(target) == 1 {
		text = text.replace_once(target, 'path, data, header)')
		start := text.index('\tport_part :=') or { return error('Missing proxy port') }
		end := text.index_after('\n\ts :=', start) or { return error('Missing proxy request') }
		text = text[..start] + text[end..]
	} else if !text.contains('req.build_request_headers_with(method, host_name, port, default_port, path, data') {
		return error('Unsupported HTTP proxy request target')
	}
	text = replace_function(text, signature, snippet('proxy_tls'))!
	text = private_helper(text, 'proxy_request_target')!
	return private_helper(text, 'request_ssl_connect_config')
}

fn patch_tls(source string, http2 bool) !string {
	probe := http2 && source.contains('fn h2_dial_probe_ssl(')
	name := if probe {
		'fn h2_dial_probe_ssl('
	} else if http2 {
		'fn (mut t Transport) h2_dial_and_do('
	} else {
		'fn (mut t Transport) tls_fresh_round_trip('
	}
	start := source.index(name) or { return error('Missing HTTP TLS dial') }
	begin := source.index_after('\tmut ssl_conn := ssl.new_ssl_conn(', start) or { return error('Missing TLS configuration') }
	end := if probe {
		(source.index_after('\tssl_conn.dial(host, port)!', begin) or { return error('Missing HTTP/2 probe dial') }) + '\tssl_conn.dial(host, port)!'.len
	} else {
		source.index_after('\n\tif req.read_timeout > 0 {', begin) or { return error('Missing TLS timeout') }
	}
	previous := source[begin..end]
	for field in ['verify', 'cert', 'cert_key', 'validate', 'in_memory_verification'] {
		if !previous.contains('req.' + field) {
			return error('Unsupported HTTP TLS configuration: ${field}')
		}
	}
	if previous.count('ssl_conn.dial(host, port)') != 1 {
		return error('Unsupported TLS dial sequence')
	}
	failure := ' or { return t.h2_dial_failed(key, mut call, err) }'
	if http2 && !probe && previous.count(failure) != 2 {
		return error('Unsupported HTTP/2 TLS failure handling')
	}
	if !http2 && !previous.contains('alpn_protocols:         alpn') {
		return error('Unsupported HTTP/1 ALPN')
	}
	if probe && !previous.contains("alpn_protocols:         ['h2', 'http/1.1']") {
		return error('Unsupported HTTP/2 ALPN')
	}
	replacement := if http2 {
		"\tmut ssl_conn := vox_http_dial_tls(req, host, port, ['h2', 'http/1.1'])" + if probe {
			'!'
		} else {
			failure
		}
	} else {
		'\tmut ssl_conn := vox_http_dial_tls(req, host, port, alpn)!'
	}
	return source[..begin] + replacement + source[end..]
}

fn patch_transport(source string) !string {
	mut text := patch_tls(source, false)!
	start, end := function_span(text, 'fn transport_pool_key(')!
	body := replace_once(text[start..end], "|\${req.in_memory_verification}'", "|\${req.in_memory_verification}|\${pk_part(vox_transport_proxy_key(req))}'")!
	text = text[..start] + body + text[end..]
	first, last := function_span(text, 'fn (mut t Transport) dial_h1_tcp(')!
	dial := replace_once(text[first..last], "mut client := net.dial_tcp('\${host}:\${port}')!", 'mut client := vox_http_dial_tcp(req, host, port)!')!
	return text[..first] + dial + text[last..] + '\n' + read(join(root_dir(), 'tools/http_tls_dial.v.inc'))!
}

fn patch_h2_pooled(source string) !string {
	field := '\tio_mu  &sync.Mutex  = sync.new_mutex()'
	mut text := replace_once(source, field, field + '\n\tvox_admission_mu &sync.Mutex = sync.new_mutex()')!
	if text.count('t.io_mu.lock()') != 4 { return error('Unsupported HTTP/2 locking layout') }
	text = text.replace('t.io_mu.lock()', 't.vox_lock_io()') + snippet('h2_admission')
	text = replace_once(text, '\tclosed bool\n}', '\tvox_wake voidptr\n\tvox_wait_before_read bool\n\tclosed bool\n}')!
	text += snippet('h2_wake_declarations')
	text = replace_function(text, 'fn new_h2_pooled_transport(', snippet('h2_transport_new'))!
	text = replace_function(text, 'fn (mut t H2PooledTransport) read(', snippet('h2_transport_read'))!
	start, end := function_span(text, 'fn (mut t H2PooledTransport) write(')!
	mut write := text[start..end]
	old := 't.conn.set_read_timeout(h2_pooled_io_timeout)'
	if write.count(old) != 2 { return error('Unsupported HTTP/2 timeout restoration') }
	write = write.replace(old, 't.conn.set_read_timeout(t.vox_read_timeout())\n        C.vox_h2_wake_signal(t.vox_wake)')
	text = text[..start] + write + text[end..]
	return text.replace_once('t.closed = true\n\tt.conn.shutdown()', 't.closed = true\n\tC.vox_h2_wake_close(t.vox_wake)\n\tt.vox_wake = unsafe { nil }\n\tt.conn.shutdown()')
}

fn patch_h2_mux(source string) !string {
	stream := '\trecv_window i64 = i64(h2_default_initial_window)'
	connection := '\tconn_recv_window i64         = i64(h2_default_initial_window)'
	mut text := replace_once(source, stream, '\tvox_pending_recv_credit u32\n\tvox_force_recv_credit bool\n' + stream)!
	text = replace_once(text, connection, connection + '\n\tvox_pending_conn_credit u32')!
	padding := '\tif frame.data.len > 0 {\n\t\ts.chunks << frame.data.clone()'
	text = replace_once(text, padding, '\tif pad_overhead > 0 { s.vox_force_recv_credit = true }\n' + padding)!
	text = replace_function(text, 'fn (mut c H2MuxConn) send_window_updates(', snippet('h2_window_updates'))!
	text = text.replace_once('fn (mut c H2MuxConn) send_window_updates(', '\nfn (mut c H2MuxConn) send_window_updates(')
	start, end := function_span(text, 'fn (mut c H2MuxConn) send_conn_window_update(')!
	mut body := replace_once(text[start..end], '\tc.conn_recv_window += i64(n)', '\tincrement := n + c.vox_pending_conn_credit\n\tc.vox_pending_conn_credit = 0\n\tc.conn_recv_window += i64(increment)')!
	body = body.replace_once('window_size_increment: n', 'window_size_increment: increment')
	text = text[..start] + body + text[end..]
	field := '\tidle_since          time.Time\n'
	text = replace_once(text, field, field + '\tvox_read_chunk      []u8\n')!
	return replace_once(text, snippet('h2_read_chunk_old'), snippet('h2_read_chunk_new'))
}

fn clean_module(target string, original string, extra []string) ! {
	names := (listing(original)!).map(os.file_name(it))
	for entry in listing(target)! {
		if os.file_name(entry) !in names && os.file_name(entry) !in extra { remove(entry)! }
	}
}

fn prepare_http(selected string) !string {
	work := build_cache(platform(), 'httpcompat')
	mkdir(work)!
	vlib := compiler_vlib(selected, work)!
	modules := join(work, hash(real(vlib))[..16], 'modules')
	original := join(vlib, 'net/http')
	mut patched := map[string]string{}
	for file in ['header.v', 'response.v', 'request.v', 'http_proxy.v', 'transport.v', 'transport_h2.v',
		'h2_pooled_transport.v', 'h2_mux_conn.v'] {
		text := read(join(original, file))!
		patched[file] = match file {
			'header.v' { patch_header(text)! }
			'response.v' { patch_response(text)! }
			'request.v' { patch_request(text)! }
			'http_proxy.v' { patch_proxy(text)! }
			'transport.v' { patch_transport(text)! }
			'transport_h2.v' { patch_tls(text, true)! }
			'h2_pooled_transport.v' { patch_h2_pooled(text)! }
			else { patch_h2_mux(text)! }
		}
	}
	patched['vox_receive_buffer.v'] = snippet('receive_buffer_helper')
	for name, path in {
		'vox_h2_wake.h':        'tools/httpcompat/h2_wake.h'
		'vox_receive_buffer.h': 'tools/httpcompat/receive_buffer.h'
		'vox_tls_sessions.h':   'tools/httpcompat/tls_sessions.h'
		'vox_tls_sessions.v':   'tools/http_tls_sessions.v.inc'
		'vox_native_state.h':   'platform/native_state.h'
	} {
		patched[name] = read(join(root_dir(), path))!
	}
	target := join(modules, 'net/http')
	mkdir(target)!
	clean_module(target, original, patched.keys())!
	for entry in listing(original)! {
		name := os.file_name(entry)
		if name !in patched { link_to(join(target, name), entry)! }
	}
	mut manifest := map[string]json.Any{
		'vlib':    vlib
		'adapter': 'V build adapter: growable fields, verified TLS, pooled proxy, pure V Brotli'
	}
	for name, text in patched {
		write_changed(join(target, name), text)!
		manifest['staged_' + name + '_sha256'] = hash(text)
		if os.is_file(join(original, name)) {
			manifest['source_' + name + '_sha256'] = digest(join(original, name))!
		}
	}
	brotli := join(vlib, 'x/compress/brotli')
	staged := join(modules, 'x/compress/brotli')
	mkdir(staged)!
	clean_module(staged, brotli, []string{})!
	for entry in listing(brotli)! {
		name := os.file_name(entry)
		if name == 'compressor.v' {
			write_changed(join(staged, name), patch_brotli(read(entry)!)!)!
		} else {
			link_to(join(staged, name), entry)!
		}
	}
	write_json(join(os.dir(modules), 'manifest.json'), json.Any(manifest))!
	return modules
}
