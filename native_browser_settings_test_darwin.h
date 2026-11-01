#pragma once
#include "native_address_bar_test_darwin.h"
static int native_test_settings_address_state(void *control, int editable) {
    NSTextField *field = (__bridge NSTextField *)control;
    return field.isEditable == (editable != 0) && field.isSelectable;
}
