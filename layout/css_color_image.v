module layout

import css

// The color-only form of image() has no intrinsic dimensions and fills its
// image tile uniformly. Reuse the generated gradient painter and mask groups.
fn css_color_image_as_gradient(value css.StyleValue) css.StyleValue {
 if value is css.FunctionStyleValue {
  if value.name() == 'image' {
   color := value.value()
   if color.has_color() {
    stop := css.ColorStopListElement{color_stop:css.ColorStop{color:color}}
    return css.StyleValue(css.LinearGradientStyleValue.create(css.LinearGradientDirection(css.LinearGradientSideOrCorner.bottom),[stop,stop],.standard,.no,none))
   }
  }
 }
 return value
}
