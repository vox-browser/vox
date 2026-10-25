module browsersettings

import net

fn C.inet_pton(family i32, address &char, output voidptr) i32

fn valid_ipv6_host(host string) bool {
	mut bytes := [16]u8{}
	return C.inet_pton(i32(net.AddrFamily.ip6), &char(host.str), &bytes[0]) == 1
}
