module layout

// Compare the fast-path extension with the same full UAX #29 segmenter used
// by the general path, retaining UTF-16 offsets rather than byte offsets.
fn cyrillic_reference_boundaries(text string) []int {
 mut result := [0]
 mut offset := 0
 for cluster in text.graphemes() {
  offset += utf16_length_for_line_box(cluster)
  result << offset
 }
 return result
}

fn cyrillic_simple_scalars() []rune {
 mut result := []rune{}
 for cp in 0x400 .. 0x483 { result << rune(cp) }
 for cp in 0x48a .. 0x530 { result << rune(cp) }
 return result
}

fn test_simple_cyrillic_pairs_match_general_grapheme_segmenter() {
 scalars := cyrillic_simple_scalars()
 assert scalars.len == 297
 for first in scalars {
  for second in scalars {
   text := [first, second].string()
   assert text_grapheme_boundaries(text) == [0, 1, 2]
   assert text_grapheme_boundaries(text) == cyrillic_reference_boundaries(text)
  }
 }
}

fn test_simple_cyrillic_mixes_keep_crlf_and_utf16_boundaries() {
 for scalar in cyrillic_simple_scalars() {
  for text in ['a${scalar} –’z', '${scalar}\r\nЯ', '\r${scalar}\n', '${scalar}\r\n'] {
   assert text_grapheme_boundaries(text) == cyrillic_reference_boundaries(text)
  }
 }
 assert text_grapheme_boundaries('Привет, мир!') == [0,1,2,3,4,5,6,7,8,9,10,11,12]
 assert text_grapheme_boundaries('Ёж\r\nя') == [0,1,2,4,5]
}

fn test_cyrillic_combining_marks_keep_the_general_path() {
 for mark in 0x483 .. 0x48a {
  for text in [[rune(0x430), rune(mark), rune(0x431)].string(), [rune(mark), rune(0x430)].string(), [rune(0x52f), rune(mark), rune(mark)].string()] {
   assert text_grapheme_boundaries(text) == cyrillic_reference_boundaries(text)
  }
 }
 assert text_grapheme_boundaries('а҃б') == [0,2,3]
 assert text_grapheme_boundaries('а҈б') == [0,2,3]
 assert text_grapheme_boundaries('а҉б') == [0,2,3]
}

fn test_cyrillic_complex_neighbors_keep_general_segmenter_results() {
 for text in ['а́б', 'а👩‍👩‍👧‍👦б', 'а🇷🇺🇺🇦б', 'аक्‍षबб', 'а\r\n😀б', 'а‍б', 'а؀بб', 'аाб', 'а각б', 'а꙯б', 'аⷠб', 'а️б', '', 'ASCII\r\ntext', 'Latin –’text'] {
  assert text_grapheme_boundaries(text) == cyrillic_reference_boundaries(text)
 }
}
