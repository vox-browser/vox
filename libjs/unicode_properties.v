module libjs

import vunicode

fn unicode_id_start(point u32) bool { return vunicode.property_named(point, 'ID_Start') }

fn unicode_id_continue(point u32) bool { return vunicode.property_named(point, 'ID_Continue') }
