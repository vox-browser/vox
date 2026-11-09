module css

// LibWeb Rust color_resolution.rs: make_powerless_hue_missing. HSL/HWB
// components in this port use fractions rather than native percentages.
fn relative_make_powerless_hue_missing(type_ ConcreteColorType, mut components InterpolationColorComponents, mut missing MissingColorComponents) {
 if type_ == .hwb {
  sum := components.component(1)+components.component(2)
  if f32(sum*100) >= f32(99.999) {
   missing.components[0] = true
   if f32(sum*100) < 100 {
    if !missing.components[1] && !missing.components[2] { components.set_component(2,1-components.component(1)) }
    else if !missing.components[1] { components.set_component(1,1) }
    else if !missing.components[2] { components.set_component(2,1) }
   }
  }
  return
 }
 hue_index := match type_ { .hsl { 0 } .lch,.oklch { 2 } else { return } }
 epsilon := match type_ { .hsl { 0.00001 } .lch { 0.0015 } else { 0.000004 } }
 if f32(components.component(1)) <= f32(epsilon) {
  missing.components[hue_index] = true
  if components.component(1) > 0 { components.set_component(1,0) }
 }
}

fn preserve_missing_polar_color(value StyleValue, context ComputationContext) ?StyleValue {
 missing := extract_missing_components(value)
 if !missing.components.any(it) && !missing.alpha { return none }
 return match value {
  HSLColorStyleValue {
   StyleValue(HSLColorStyleValue{...HSLColorStyleValue.create(value.h_.value.absolutized(context),value.s_.value.absolutized(context),value.l_.value.absolutized(context),value.alpha_.value.absolutized(context),.modern),missing_component_form_:true})
  }
  HWBColorStyleValue {
   StyleValue(HWBColorStyleValue{...HWBColorStyleValue.create(value.h_.value.absolutized(context),value.w_.value.absolutized(context),value.b_.value.absolutized(context),value.alpha_.value.absolutized(context),.modern),missing_component_form_:true})
  }
  else { none }
 }
}
