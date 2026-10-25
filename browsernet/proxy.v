module browsernet

import browsersettings
import net.http
import net.urllib
import os

fn proxy_environment_value(environment map[string]string, lower string, upper string) string {
	if lower in environment { return environment[lower] }
	return environment[upper]
}

fn proxy_bypasses(address urllib.URL, exclusions string) bool {
	host := address.hostname().to_lower()
	port := if address.port() != '' { address.port() } else if address.scheme == 'https' { '443' } else { '80' }
	for entry in exclusions.split(',') {
		mut pattern := entry.trim_space().to_lower()
		if pattern == '*' { return true }
		if pattern == '' { continue }
		// Brackets distinguish an IPv6 literal from an optional port suffix.
		if pattern.count(':') == 1 || pattern.contains(']:') {
			if pattern.all_after_last(':') != port { continue }
			pattern = pattern.all_before_last(':')
		}
		pattern = pattern.trim('[]').trim_left('.')
		if host == pattern || host.ends_with('.' + pattern) { return true }
	}
	return false
}

fn configured_proxy(resource_url string, environment map[string]string) !string {
	address := urllib.parse(resource_url)!
	if proxy_bypasses(address, proxy_environment_value(environment, 'no_proxy', 'NO_PROXY')) {
		return ''
	}
	mut proxy := ''
	if 'VOX_PROXY' in environment {
		// An explicitly empty override disables ambient proxy configuration.
		proxy = environment['VOX_PROXY']
	} else {
		proxy = if address.scheme == 'https' {
			proxy_environment_value(environment, 'https_proxy', 'HTTPS_PROXY')
		} else {
			proxy_environment_value(environment, 'http_proxy', 'HTTP_PROXY')
		}
		if proxy == '' { proxy = proxy_environment_value(environment, 'all_proxy', 'ALL_PROXY') }
	}
	if proxy == '' { return '' }
	// V's SOCKS5 dialer sends the destination hostname to the proxy. Accept
	// curl's explicit remote-DNS spelling as the same protocol.
	if proxy.starts_with('socks5h://') { proxy = 'socks5://' + proxy['socks5h://'.len..] }
	parsed := urllib.parse(proxy) or { return error('Invalid browser proxy configuration') }
	if parsed.scheme !in ['http', 'socks5'] || parsed.hostname() == ''
		|| (parsed.path != '' && parsed.path != '/') || parsed.raw_query != '' || parsed.fragment != '' {
		return error('Invalid browser proxy configuration (expected http:// or socks5://)')
	}
	// Never fall back to a direct connection when an explicit proxy is invalid.
	checked := http.new_http_proxy(proxy) or { return error('Invalid browser proxy configuration') }
	return checked.str()
}

fn request_proxy(resource_url string) !string {
	if proxy := browsersettings.proxy_override(resource_url) {
		return configured_proxy(resource_url, { 'VOX_PROXY': proxy })
	}
	mut environment := map[string]string{}
	for key in ['VOX_PROXY', 'http_proxy', 'HTTP_PROXY', 'https_proxy', 'HTTPS_PROXY',
		'all_proxy', 'ALL_PROXY', 'no_proxy', 'NO_PROXY'] {
		if value := os.getenv_opt(key) { environment[key] = value }
	}
	return configured_proxy(resource_url, environment)
}
