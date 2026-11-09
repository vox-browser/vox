module main

import crypto.sha256
import json2
import os

// The HTTP adapters deliberately recognize the supported upstream source
// layouts. A changed layout fails before publishing replacement modules.
fn http_index(source string, needle string, start int) !int {
	return source.index_after(needle, start) or {
		return error('Unsupported V HTTP source: missing ${needle}')
	}
}

fn http_replace_once(source string, old string, replacement string, diagnostic string) !string {
	if source.count(old) != 1 {
		return error(diagnostic)
	}
	return source.replace_once(old, replacement)
}

fn http_function_bounds(source string, signature string) !(int, int) {
	start := http_index(source, signature, 0)!
	end := http_index(source, '\n}', start)! + 2
	return start, end
}

fn http_exact_function_bounds(source string, signature string) !(int, int) {
	mut cursor := 0
	for cursor < source.len {
		start := source.index_after(signature, cursor) or { break }
		cursor = start + signature.len
		for cursor < source.len && source[cursor].is_space() {
			cursor++
		}
		if cursor < source.len && source[cursor] == `{` {
			end := source.index_after('\n}', cursor) or { break }
			return start, end + 2
		}
	}
	return error('Unsupported HTTP receive-buffer implementation')
}

fn replace_function(source string, signature string, replacement string) !string {
	mut count := 0
	mut cursor := 0
	mut result := ''
	for cursor < source.len {
		start := source.index_after(signature, cursor) or { break }
		mut body := start + signature.len
		for body < source.len && source[body].is_space() {
			body++
		}
		if body >= source.len || source[body] != `{` {
			result += source[cursor..start + signature.len]
			cursor = start + signature.len
			continue
		}
		end := source.index_after('\n}', body) or { break }
		result += source[cursor..start] + replacement.trim_space()
		cursor = end + 2
		count++
	}
	result += source[cursor..]
	if count != 1 {
		return error('Unsupported V HTTP header source: expected one ${signature}, found ${count}')
	}
	return result
}

fn http_identifier_byte(value u8) bool {
	return value.is_letter() || value.is_digit() || value == `_`
}

fn http_contains_identifier(source string, name string) bool {
	mut cursor := 0
	for cursor < source.len {
		start := source.index_after(name, cursor) or { return false }
		end := start + name.len
		if (start == 0 || !http_identifier_byte(source[start - 1]))
			&& (end == source.len || !http_identifier_byte(source[end])) {
			return true
		}
		cursor = end
	}
	return false
}

fn http_without_line_comments(source string) string {
	return source.split('\n').map(it.all_before('//')).join('\n')
}

fn http_private_helper_start(source string, function_start int) int {
	mut start := function_start
	for start > 0 {
		previous_end := start - 1
		previous_start := source[..previous_end].last_index('\n') or { -1 } + 1
		line := source[previous_start..previous_end]
		if line.starts_with('@[') && line.ends_with(']') {
			start = previous_start
			continue
		}
		if !line.trim_left(' \t\r').starts_with('//') {
			break
		}
		start = previous_start
		// Python's original comment prefix accepts blank lines before a comment.
		for start > 0 {
			blank_end := start - 1
			blank_start := source[..blank_end].last_index('\n') or { -1 } + 1
			if source[blank_start..blank_end].trim_space() != '' {
				break
			}
			start = blank_start
		}
	}
	return start
}

fn remove_unused_private_helper(source string, name string) !string {
	needle := 'fn ${name}('
	mut remaining := source
	mut cursor := 0
	mut count := 0
	for cursor < remaining.len {
		start := remaining.index_after(needle, cursor) or { break }
		cursor = start + needle.len
		if start > 0 && remaining[start - 1] != `\n` {
			continue
		}
		line_end := remaining.index_after('\n', cursor) or { remaining.len }
		if !remaining[cursor..line_end].contains('{') {
			continue
		}
		close := remaining.index_after('\n}', cursor) or { continue }
		mut end := close + 2
		if end < remaining.len && remaining[end] == `\n` {
			end++
		}
		begin := http_private_helper_start(remaining, start)
		remaining = remaining[..begin] + remaining[end..]
		cursor = begin
		count++
	}
	if count > 1 {
		return error('Multiple private HTTP helpers named ${name}')
	}
	if count == 1 && !http_contains_identifier(http_without_line_comments(remaining), name) {
		return remaining
	}
	return source
}

fn http_patch_header(source string) !string {
	mut patched := http_replace_once(source, 'data [max_headers]HeaderKV', 'data []HeaderKV',
		'Unsupported V HTTP header source: fixed Header storage was not found')!
	patched = patched.replace_once('pub const max_headers = 50',
		'// Retained for source compatibility; Header storage grows beyond this value.\npub const max_headers = 50')
	replacements := {
		'pub fn new_header(kvs ...HeaderConfig) Header':                                      $embed_file('@VMODROOT/httpassets/header_new.v.inc').to_string()
		'pub fn (mut h Header) add(key CommonHeader, value string)':                          $embed_file('@VMODROOT/httpassets/header_add.v.inc').to_string()
		'pub fn (mut h Header) add_custom(key string, value string) !':                       $embed_file('@VMODROOT/httpassets/header_add_custom.v.inc').to_string()
		'pub fn (mut h Header) set(key CommonHeader, value string)':                          $embed_file('@VMODROOT/httpassets/header_set.v.inc').to_string()
		'pub fn (mut h Header) set_custom(key string, value string) !':                       $embed_file('@VMODROOT/httpassets/header_set_custom.v.inc').to_string()
		'pub fn (mut h Header) delete_custom(key string)':                                    $embed_file('@VMODROOT/httpassets/header_delete_custom.v.inc').to_string()
		'pub fn (h Header) custom_values(key string, flags HeaderQueryConfig) []string':      $embed_file('@VMODROOT/httpassets/header_custom_values.v.inc').to_string()
		'pub fn (h Header) keys() []string':                                                  $embed_file('@VMODROOT/httpassets/header_keys.v.inc').to_string()
		'pub fn (h Header) render_into_sb(mut sb strings.Builder, flags HeaderRenderConfig)': $embed_file('@VMODROOT/httpassets/header_render.v.inc').to_string()
	}
	for signature, replacement in replacements {
		patched = replace_function(patched, signature, replacement)!
	}
	patched += $embed_file('@VMODROOT/httpassets/header_replace.v.inc').to_string()
	return remove_unused_private_helper(patched, 'header_value_without_ows')
}

fn http_patch_response(source string) !string {
	lines := source.split('\n')
	native := lines.filter(it == 'import compress.brotli').len
	pure := lines.filter(it == 'import x.compress.brotli').len
	if native == 0 && pure == 1 {
		return source
	}
	if native != 1 || pure != 0 {
		return error('Unsupported HTTP Brotli import')
	}
	return lines.map(if it == 'import compress.brotli' { 'import x.compress.brotli' } else { it }).join('\n')
}

fn http_patch_brotli_compressor(source string) !string {
	native_import := 'import compress.brotli as native_brotli\n'
	if !source.contains(native_import) {
		if source.contains('native_brotli.') {
			return error('Unsupported native Brotli encoder reference')
		}
		return source
	}
	mut patched := source.replace_once(native_import, '')
	mut cursor := 0
	mut count := 0
	for cursor < patched.len {
		start := patched.index_after('\n\tif ', cursor) or { break }
		line_end := patched.index_after('\n', start + 1) or { break }
		cursor = line_end
		if !patched[start + 1..line_end].ends_with('{')
			|| !patched[line_end..].starts_with('\n\t\tif compressed := native_brotli.compress(data,') {
			continue
		}
		end := patched.index_after('\n\t\t}\n\t}\n', line_end) or { break }
		patched = patched[..start] + '\n' + patched[end + '\n\t\t}\n\t}\n'.len..]
		cursor = start + 1
		count++
	}
	if count != 1 || patched.contains('native_brotli') {
		return error('Unsupported optional native Brotli encoder')
	}
	return patched.replace('// Large inputs without metadata, custom dictionaries, or large windows may use\n' +
		'// the system encoder when available; other inputs use the V encoder.\n',
		'// Vox always uses the V encoder, including large inputs.\n')
}

fn http_patch_pointer_casts(source string) string {
	mut patched := ''
	mut cursor := 0
	for cursor < source.len {
		start := source.index_after('u64(usize(', cursor) or { break }
		body := start + 'u64(usize('.len
		end := source.index_after(')', body) or { break }
		if source[body..end].contains('(') || end + 1 >= source.len || source[end + 1] != `)` {
			patched += source[cursor..body]
			cursor = body
			continue
		}
		patched += source[cursor..start] + 'u64(voidptr(' + source[body..end] + '))'
		cursor = end + 2
	}
	return patched + source[cursor..]
}

fn http_patch_request(source string) !string {
	mut patched := http_patch_pointer_casts(source)
	if patched.contains('fn (req &Request) method_and_url_to_response(') {
		old := "p := url.escaped_path().trim_left('/')\n\tpath := if url.query().len > 0 { '/\${p}?\${url.query().encode()}' } else { '/\${p}' }"
		if patched.count(old) == 1 {
			patched = patched.replace_once(old, 'path := url.request_uri()')
		} else if patched.count('path := url.request_uri()') != 1 {
			return error('Unsupported HTTP request-target source')
		}
	}
	if patched.contains('cookie_header_value_with_header(header)') {
		return patched
	}
	start, end := http_function_bounds(patched, 'fn (req &Request) build_request_cookies_header_with_header(header Header) string')!
	function := http_replace_once(patched[start..end], "if req.cookies.len < 1 {\n\t\treturn ''\n\t}",
		"if req.cookies.len < 1 {\n\t\tvalues := header.values(.cookie)\n\t\treturn if values.len == 0 { '' } else { 'Cookie: ' + values.join('; ') + '\\r\\n' }\n\t}",
		'Unsupported HTTP cookie serialization source')!
	return patched[..start] + function + patched[end..]
}

fn http_patch_proxy(source string) !string {
	mut patched := source.replace_once('struct HttpProxy {', 'pub struct HttpProxy {')
	patched = http_replace_once(patched, "pr.ssl_dial('\${host_name}:\${port}')",
		"pr.ssl_dial('\${host_name}:\${port}', req)", 'Unsupported HTTP proxy TLS call')!
	old := "'\${host.scheme}://\${host_name}\${port_part}\${path}', data, header)"
	if patched.count(old) == 1 {
		patched = patched.replace_once(old, 'path, data, header)')
		start := http_index(patched, '\tport_part :=', 0)!
		end := http_index(patched, '\n\ts :=', start)!
		patched = patched[..start] + patched[end..]
	} else if !patched.contains('req.build_request_headers_with(method, host_name, port, default_port, path, data') {
		return error('Unsupported HTTP proxy request target')
	}
	patched = replace_function(patched, 'fn (pr &HttpProxy) ssl_dial(host string) !&ssl.SSLConn',
		$embed_file('@VMODROOT/httpassets/proxy_ssl_dial.v.inc').to_string())!
	return remove_unused_private_helper(patched, 'proxy_request_target')
}

fn http_patch_transport_tls(source string, http2 bool) !string {
	probe := http2 && source.contains('fn h2_dial_probe_ssl(')
	name := if http2 { 'h2_dial_and_do' } else { 'tls_fresh_round_trip' }
	signature := if probe { 'fn h2_dial_probe_ssl(' } else { 'fn (mut t Transport) ${name}(' }
	start := http_index(source, signature, 0)!
	begin := http_index(source, '\tmut ssl_conn := ssl.new_ssl_conn(', start)!
	end := if probe {
		http_index(source, '\tssl_conn.dial(host, port)!', begin)! + '\tssl_conn.dial(host, port)!'.len
	} else {
		http_index(source, '\n\tif req.read_timeout > 0 {', begin)!
	}
	previous := source[begin..end]
	for field in ['verify', 'cert', 'cert_key', 'validate', 'in_memory_verification'] {
		if !previous.contains('req.' + field) {
			if probe {
				return error('Unsupported V HTTP/2 TLS configuration: ${field}')
			}
			return error('Unsupported V HTTP TLS configuration: ${field}')
		}
	}
	mut replacement := ''
	if probe {
		if !previous.contains("alpn_protocols:         ['h2', 'http/1.1']") {
			return error('Unsupported V HTTP/2 TLS ALPN configuration')
		}
		replacement = "\tmut ssl_conn := vox_http_dial_tls(req, host, port, ['h2', 'http/1.1'])!"
	} else {
		if previous.count('ssl_conn.dial(host, port)') != 1 {
			return error('Unsupported V HTTP TLS connection sequence')
		}
		if http2 {
			failure := ' or { return t.h2_dial_failed(key, mut call, err) }'
			if previous.count(failure) != 2 {
				return error('Unsupported V HTTP/2 TLS failure handling')
			}
			replacement = "\tmut ssl_conn := vox_http_dial_tls(req, host, port, ['h2', 'http/1.1'])" + failure
		} else {
			if !previous.contains('alpn_protocols:         alpn') {
				return error('Unsupported V HTTP/1 TLS ALPN configuration')
			}
			replacement = '\tmut ssl_conn := vox_http_dial_tls(req, host, port, alpn)!'
		}
	}
	return source[..begin] + replacement + source[end..]
}

fn http_patch_pooled_proxy_request(source string) !string {
	return http_replace_once(source, 'if req.proxy == unsafe { nil } && !req.disable_connection_reuse',
		'if (req.proxy == unsafe { nil } || vox_transport_tunnels_proxy()) && !req.disable_connection_reuse',
		'Unsupported V HTTP pooled-transport selection')
}

fn http_patch_pooled_proxy_transport(source string) !string {
	start, end := http_function_bounds(source, 'fn transport_pool_key(')!
	key := http_replace_once(source[start..end], "|\${req.in_memory_verification}'",
		"|\${req.in_memory_verification}|\${pk_part(vox_transport_proxy_key(req))}'",
		'Unsupported V HTTP transport pool key')!
	patched := source[..start] + key + source[end..]
	dial_start, dial_end := http_function_bounds(patched, 'fn (mut t Transport) dial_h1_tcp(')!
	dial := http_replace_once(patched[dial_start..dial_end], "mut client := net.dial_tcp('\${host}:\${port}')!",
		'mut client := vox_http_dial_tcp(req, host, port)!', 'Unsupported V HTTP/1 transport dial')!
	return patched[..dial_start] + dial + patched[dial_end..]
}

fn http_patch_h2_pooled_transport(source string) !string {
	field := '\tio_mu  &sync.Mutex  = sync.new_mutex()'
	if source.count(field) != 1 || source.count('t.io_mu.lock()') != 4 {
		return error('Unsupported V HTTP/2 pooled transport locking layout')
	}
	return source.replace_once(field, field + '\n\tvox_admission_mu &sync.Mutex = sync.new_mutex()')
		.replace('t.io_mu.lock()', 't.vox_lock_io()') + $embed_file('@VMODROOT/httpassets/h2_lock_io.v.inc').to_string()
}

fn http_patch_h2_wakeup(source string) !string {
	mut patched := http_replace_once(source, '\tclosed bool\n}',
		'\tvox_wake voidptr\n\tvox_wait_before_read bool\n\tclosed bool\n}',
		'Unsupported HTTP/2 transport state layout')!
	patched += $embed_file('@VMODROOT/httpassets/h2_wake_helper.v.inc').to_string()
	start, end := http_function_bounds(patched, 'fn new_h2_pooled_transport(')!
	patched = patched[..start] + $embed_file('@VMODROOT/httpassets/h2_new_transport.v.inc').to_string() + patched[end..]
	read_start, read_end := http_function_bounds(patched, 'fn (mut t H2PooledTransport) read(')!
	patched = patched[..read_start] + $embed_file('@VMODROOT/httpassets/h2_read.v.inc').to_string() + patched[read_end..]
	write_start, write_end := http_function_bounds(patched, 'fn (mut t H2PooledTransport) write(')!
	mut function := patched[write_start..write_end]
	if function.count('t.conn.set_read_timeout(h2_pooled_io_timeout)') != 2 {
		return error('Unsupported HTTP/2 TLS timeout restoration')
	}
	function = function.replace('t.conn.set_read_timeout(h2_pooled_io_timeout)',
		't.conn.set_read_timeout(t.vox_read_timeout())\n        C.vox_h2_wake_signal(t.vox_wake)')
	patched = patched[..write_start] + function + patched[write_end..]
	return patched.replace_once('t.closed = true\n\tt.conn.shutdown()',
		't.closed = true\n\tC.vox_h2_wake_close(t.vox_wake)\n\tt.vox_wake = unsafe { nil }\n\tt.conn.shutdown()')
}

fn http_patch_h2_mux_receive_credit(source string) !string {
	stream := '\trecv_window i64 = i64(h2_default_initial_window)'
	connection := '\tconn_recv_window i64         = i64(h2_default_initial_window)'
	mut patched := http_replace_once(source, stream,
		'\tvox_pending_recv_credit u32\n\tvox_force_recv_credit bool\n' + stream,
		'Unsupported V HTTP/2 receive-window layout')!
	patched = http_replace_once(patched, connection, connection + '\n\tvox_pending_conn_credit u32',
		'Unsupported V HTTP/2 receive-window layout')!
	padding := '\tif frame.data.len > 0 {\n\t\ts.chunks << frame.data.clone()'
	patched = http_replace_once(patched, padding, '\tif pad_overhead > 0 { s.vox_force_recv_credit = true }\n' + padding,
		'Unsupported V HTTP/2 DATA delivery layout')!
	start := http_index(patched, 'fn (mut c H2MuxConn) send_window_updates(', 0)!
	end := http_index(patched, '\n}\n', start)! + 2
	patched = patched[..start] + $embed_file('@VMODROOT/httpassets/h2_window_updates.v.inc').to_string() + patched[end..]
	conn_start := http_index(patched, 'fn (mut c H2MuxConn) send_conn_window_update(', 0)!
	conn_end := http_index(patched, '\n}\n', conn_start)! + 2
	mut function := http_replace_once(patched[conn_start..conn_end], '\tc.conn_recv_window += i64(n)',
		'\tincrement := n + c.vox_pending_conn_credit\n\tc.vox_pending_conn_credit = 0\n\tc.conn_recv_window += i64(increment)',
		'Unsupported V HTTP/2 cancellation credit')!
	function = function.replace_once('window_size_increment: n', 'window_size_increment: increment')
	return patched[..conn_start] + function + patched[conn_end..]
}

fn http_patch_h2_mux_read_chunk(source string) !string {
	field := '\tidle_since          time.Time\n'
	patched := http_replace_once(source, field, field + '\tvox_read_chunk      []u8\n',
		'Unsupported V HTTP/2 connection layout')!
	return http_replace_once(patched, $embed_file('@VMODROOT/httpassets/h2_read_chunk_old.v.inc').to_string(),
		$embed_file('@VMODROOT/httpassets/h2_read_chunk_new.v.inc').to_string(),
		'Unsupported V HTTP/2 frame reader')
}

fn http_patch_receive_buffer(source string) !string {
	if source.contains('mut received := VoxHTTPReceiveBuffer{}') {
		return source
	}
	signature := 'fn (req &Request) receive_all_data_from_cb_in_builder(mut content strings.Builder, con voidptr, receive_chunk_cb FnReceiveChunk) !ReceivedResponseInfo'
	start, end := http_exact_function_bounds(source, signature)!
	mut function := source[start..end]
	for old, expected in {
		'content.write_ptr(': 2
		'content.write(':     1
		'content.len':        1
	} {
		if function.count(old) != expected {
			return error('Unsupported HTTP receive-buffer write: ${old}')
		}
		function = function.replace(old, old.replace_once('content.', 'received.'))
	}
	entry := http_index(function, '{', 0)! + 1
	body := function[entry..]
	mut cursor := 0
	for cursor < body.len {
		position := body.index_after('content', cursor) or { break }
		cursor = position + 'content'.len
		if position > 0 && http_identifier_byte(body[position - 1]) {
			continue
		}
		for cursor < body.len && body[cursor].is_space() {
			cursor++
		}
		if cursor < body.len && body[cursor] == `.` {
			return error('Unsupported HTTP receive-buffer access')
		}
	}
	function = function[..entry] + $embed_file('@VMODROOT/httpassets/receive_buffer_entry.v.inc').to_string() + function[entry..]
	return source[..start] + function + source[end..]
}

fn http_read(path string) !string {
	return (os.read_file(path)!).replace('\r\n', '\n').replace('\r', '\n')
}

fn http_remove_obsolete_entries(target string, original string) ! {
	mut names := os.ls(original)!
	names << ['vox_h2_wake.h', 'vox_receive_buffer.h', 'vox_receive_buffer.v',
		'vox_receive_buffer_test.v', 'vox_tls_sessions.h', 'vox_tls_sessions.v', 'vox_native_state.h']
	for name in os.ls(target)! {
		if name in names {
			continue
		}
		entry := os.join_path(target, name)
		if os.is_link(entry) || os.is_file(entry) {
			os.rm(entry)!
		} else {
			os.rmdir_all(entry)!
		}
	}
}

fn http_link(original string, target string) ! {
	if os.is_link(target) && os.real_path(target) == os.real_path(original) {
		return
	}
	if os.is_link(target) || os.is_file(target) {
		os.rm(target)!
	}
	os.symlink(original, target)!
}

fn http_stage_brotli(vlib string, modules string) !map[string]string {
	original := os.join_path(vlib, 'x/compress/brotli')
	source := http_read(os.join_path(original, 'compressor.v'))!
	patched := http_patch_brotli_compressor(source)!
	target := os.join_path(modules, 'x/compress/brotli')
	make_directory(target)!
	http_remove_obsolete_entries(target, original)!
	for name in os.ls(original)! {
		output := os.join_path(target, name)
		if name == 'compressor.v' {
			write_if_changed(output, patched)!
		} else {
			http_link(os.join_path(original, name), output)!
		}
	}
	return {
		'source_brotli_compressor_sha256': sha256.hexhash(source)
		'staged_brotli_compressor_sha256': sha256.hexhash(patched)
	}
}

fn prepare_http(repo string, compiler string) !string {
	work := os.join_path(repo, 'Build/v/httpcompat')
	make_directory(work)!
	vlib := compiler_vlib(compiler, work)!
	original := os.join_path(vlib, 'net/http')
	mut sources := map[string]string{}
	mut patched := map[string]string{}
	for name in ['header', 'response', 'request', 'http_proxy', 'transport', 'transport_h2',
		'h2_pooled_transport', 'h2_mux_conn'] {
		sources[name] = http_read(os.join_path(original, name + '.v'))!
	}
	patched['header'] = http_patch_header(sources['header'])!
	patched['response'] = http_patch_response(sources['response'])!
	patched['request'] = http_patch_pooled_proxy_request(http_patch_receive_buffer(http_patch_request(sources['request'])!)!)!
	patched['http_proxy'] = http_patch_proxy(sources['http_proxy'])!
	patched['transport'] = http_patch_pooled_proxy_transport(http_patch_transport_tls(sources['transport'], false)!)! +
		'\n' + http_read(os.join_path(repo, 'tools/http_tls_dial.v.inc'))!
	patched['transport_h2'] = http_patch_transport_tls(sources['transport_h2'], true)!
	patched['h2_pooled_transport'] = http_patch_h2_wakeup(http_patch_h2_pooled_transport(sources['h2_pooled_transport'])!)!
	patched['h2_mux_conn'] = http_patch_h2_mux_read_chunk(http_patch_h2_mux_receive_credit(sources['h2_mux_conn'])!)!
	identity := sha256.hexhash(os.real_path(vlib))[..16]
	modules := os.join_path(work, identity, 'modules')
	mut manifest := http_stage_brotli(vlib, modules)!
	manifest['vlib'] = vlib
	target := os.join_path(modules, 'net/http')
	make_directory(target)!
	http_remove_obsolete_entries(target, original)!
	write_if_changed(os.join_path(target, 'vox_h2_wake.h'), http_read(os.join_path(repo, 'tools/httpcompat/h2_wake.h'))!)!
	assets := {
		'receive_buffer_header': ['vox_receive_buffer.h',
			http_read(os.join_path(repo, 'tools/httpcompat/receive_buffer.h'))!]
		'receive_buffer_helper': ['vox_receive_buffer.v',
			$embed_file('@VMODROOT/httpassets/receive_buffer.v.inc').to_string()]
		'tls_sessions_header':   ['vox_tls_sessions.h',
			http_read(os.join_path(repo, 'tools/httpcompat/tls_sessions.h'))!]
		'tls_sessions_helper':   ['vox_tls_sessions.v',
			http_read(os.join_path(repo, 'tools/http_tls_sessions.v.inc'))!]
		'native_state_header':   ['vox_native_state.h',
			http_read(os.join_path(repo, 'platform/native_state.h'))!]
	}
	for key, asset in assets {
		write_if_changed(os.join_path(target, asset[0]), asset[1])!
		manifest[key + '_sha256'] = sha256.hexhash(asset[1])
	}
	for name in os.ls(original)! {
		output := os.join_path(target, name)
		key := name.trim_string_right('.v')
		if name.ends_with('.v') && key in patched {
			write_if_changed(output, patched[key])!
		} else {
			http_link(os.join_path(original, name), output)!
		}
	}
	keys := {
		'header':              'header'
		'response':            'response'
		'request':             'request'
		'http_proxy':          'proxy'
		'transport':           'transport'
		'transport_h2':        'h2'
		'h2_pooled_transport': 'h2_pooled'
		'h2_mux_conn':         'h2_mux'
	}
	for name, key in keys {
		manifest['source_' + key + '_sha256'] = sha256.hexhash(sources[name])
		manifest['staged_' + key + '_sha256'] = sha256.hexhash(patched[name])
	}
	manifest['adapter'] = 'growable fields; copy-on-write; preserve empty/repeated fields; verified proxy TLS; TCP before TLS setup; pooled proxy tunnels; pure V Brotli'
	write_if_changed(os.join_path(os.dir(modules), 'manifest.json'), json2.encode(manifest,
		prettify:      true
		indent_string: '  '
	) + '\n')!
	return modules
}
