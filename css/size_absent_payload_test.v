module css

$if gcboehm ? {
 fn C.GC_get_total_bytes() usize
 fn C.GC_gcollect()
}

fn test_default_sizes_retain_no_unused_length_percentage_allocation() {
 mut sizes := []Size{cap: 512}
 mut before := usize(0)
 $if gcboehm ? { before = C.GC_get_total_bytes() }
 for _ in 0 .. 512 { sizes << Size{} }
 mut allocated := usize(0)
 $if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
 assert allocated == 0
 assert sizes.len == 512
 for size in sizes {
  assert size.is_auto()
  assert size.length_percentage_ == none
  assert size.serialize(.normal) == 'auto'
  assert size.to_px(LengthResolutionContext{}, CSSPixels.new(200)).raw_value() == 0
 }
}

fn test_keyword_size_defaults_and_explicit_constructors_keep_absence() {
 for size in [Size{}, Size.make_auto(), Size.make_min_content(), Size.make_max_content(),
  Size.make_fit_content_without_available_space(), Size.make_none(), Size{type_: .min_content},
  Size{type_: .max_content}, Size{type_: .fit_content}, Size{type_: .none_}] {
  assert size.length_percentage_ == none
  assert !size.is_length_percentage()
  assert !size.contains_percentage()
  assert size.to_px(LengthResolutionContext{}, CSSPixels.new(200)).raw_value() == 0
  if size.is_fit_content() { assert size.fit_content_available_space() == none }
 }
 assert Size{}.serialize(.normal) == 'auto'
 assert Size{type_: .min_content}.serialize(.normal) == 'min-content'
 assert Size{type_: .max_content}.serialize(.normal) == 'max-content'
 assert Size{type_: .fit_content}.serialize(.normal) == 'fit-content'
 assert Size{type_: .none_}.serialize(.normal) == 'none'
}

fn test_present_size_payloads_and_zero_fit_limit_survive_copy_clear_and_collection() {
 mut source := [Size.make_length(Length.make_px(17.5)), Size.make_percentage(Percentage.new(25)),
  Size.make_calculated(CalculatedStyleValue{serialization: 'calc(2px + 3%)'}),
  Size.make_fit_content(LengthPercentage.from_length(Length.make_px(0))),
  Size.make_fit_content(LengthPercentage.from_percentage(Percentage.new(0)))]
 retained := source.clone()
 for index in 0 .. source.len { source[index] = Size{} }
 for _ in 0 .. 3 {
  $if gcboehm ? { C.GC_gcollect() }
  assert retained[0].is_length()
  assert retained[0].length() == Length.make_px(17.5)
  assert retained[0].to_px(LengthResolutionContext{}, CSSPixels.new(200)).to_double() == 17.5
  assert retained[1].is_percentage()
  assert retained[1].percentage() == Percentage.new(25)
  assert retained[1].to_px(LengthResolutionContext{}, CSSPixels.new(200)).to_double() == 50
  assert retained[2].is_calculated()
  assert retained[2].serialize(.normal) == 'calc(2px + 3%)'
  assert retained[3].is_fit_content()
  assert (retained[3].fit_content_available_space() or { panic('missing zero length') }).is_length()
  assert retained[3].serialize(.normal) == 'fit-content(0px)'
  assert (retained[4].fit_content_available_space() or { panic('missing zero percentage') }).is_percentage()
  assert retained[4].serialize(.normal) == 'fit-content(0%)'
  for cleared in source { assert cleared.length_percentage_ == none }
 }
}
