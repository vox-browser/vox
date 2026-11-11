module adblock

import compress.deflate
import os

// The bundled engine source and snapshot metadata are single gzip members that
// V inflates; their CRC-32, declared size and exact extent are all checked.
fn test_gunzip_single_member_checks_crc_size_and_extent() {
	text := 'adblock engine source '.repeat(500).bytes()
	member := deflate.compress_gzip(text)!
	assert gunzip_single_member(member)! == text
	mut corrupt := member.clone()
	corrupt[corrupt.len - 8] ^= 1
	if _ := gunzip_single_member(corrupt) { assert false } else { assert err.msg().contains('crc32') }
	corrupt = member.clone()
	corrupt[corrupt.len - 4] ^= 1
	if _ := gunzip_single_member(corrupt) { assert false } else { assert err.msg().contains('size') }
	mut doubled := member.clone()
	doubled << member
	if _ := gunzip_single_member(doubled) { assert false }
	if _ := gunzip_single_member(member[..12]) { assert false }
}

fn test_bundled_gzip_assets_inflate_in_v() {
	source := decompress_engine_source(os.read_bytes(os.join_path(@DIR, 'engine.js.gz'))!)!
	assert source.len > 100_000
	metadata := gunzip_single_member(os.read_bytes(os.join_path(@DIR, 'engine.snapshot.json.gz'))!)!
	assert metadata.len > 0 && metadata[0] == `{`
}
