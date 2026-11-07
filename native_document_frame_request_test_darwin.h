#pragma once
#include "native_layer_presentation_darwin.h"
// Exported by navigation/main_navigation_work.v.
int32_t vox_service_navigation_ui(void);

static uint64_t vox_test_document_preparation_begin(void) {
    [NSApplication sharedApplication];
    for (unsigned i = 0; i < 16; ++i) vox_service_navigation_ui();
    native_layer_presenting = YES;
    native_layer_document_work_active = YES;
    native_layer_paint_started = NO;
    return native_layer_redraw_generation;
}

static uint64_t vox_test_document_redraw_generation(void) {
    return native_layer_redraw_generation;
}

static uint64_t vox_test_document_preparation_pump(void) {
    for (unsigned i = 0; i < 16; ++i) vox_service_navigation_ui();
    return native_layer_redraw_generation;
}

static void vox_test_document_preparation_end(void) {
    native_layer_presenting = NO;
    native_layer_document_work_active = NO;
    native_layer_paint_started = NO;
}
