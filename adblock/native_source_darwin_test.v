module adblock

import compress.gzip

fn C.JSStringIsEqual(voidptr, voidptr) bool
fn C.JSStringGetLength(voidptr) uint
fn C.JSStringGetCharactersPtr(voidptr) &u16

fn test_native_script_source_preserves_utf16_code_units() {
 sources := [
  '', 'ASCII script source', '日本語 Ελληνικά 😀 é', '\xef\xbb\xbfhi',
  [u8(97), 0, 98].bytestr(), [u8(0x80)].bytestr(),
  [u8(0xe2), 0x82].bytestr(), [u8(0xed), 0xa0, 0x80].bytestr(),
  [u8(0xf4), 0x90, 0x80, 0x80].bytestr(),
  '😀 café '.repeat(10000),
 ]
 for index, source in sources {
  text := script_string(source)
  assert text != unsafe { nil }
  expected := source_utf16(source)
  actual_length := int(C.JSStringGetLength(text))
  original := C.JSStringCreateWithCharacters(expected.data, uint(expected.len))
  assert C.JSStringIsEqual(text, original)
  C.JSStringRelease(original)
  assert actual_length == expected.len, 'source case ${index}'
  actual := C.JSStringGetCharactersPtr(text)
  for i, code in expected { assert unsafe { actual[i] } == code }
  C.JSStringRelease(text)
 }
}

fn test_native_gzip_preserves_bundled_source_and_rejects_bad_streams() {
 for source in ['', 'let x = 42;', '日本語 😀', [u8(97), 0, 98].bytestr()] {
  compressed := gzip.compress(source.bytes()) or { panic(err) }
  assert decompress_engine_source(compressed) or { panic(err) } == source
 }
 data := compressed_engine_source.to_bytes()
 expected := gzip.decompress(data) or { panic(err) }
 assert decompress_engine_source(data) or { panic(err) } == expected.bytestr()
 mut invalid := [][]u8{}
 invalid << []u8{}
 invalid << data[..10].clone()
 invalid << data[..data.len-1].clone()
 mut crc := data.clone()
 crc[crc.len-8] ^= 1
 invalid << crc
 mut size := data.clone()
 size[size.len-4] ^= 1
 invalid << size
 mut trailing := data.clone()
 trailing << u8(0)
 invalid << trailing
 for bad in invalid {
  if _ := decompress_engine_source(bad) { assert false, 'invalid gzip accepted' }
 }
}
