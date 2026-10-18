#ifndef VOX_MAIN_MEMORY_STATUS_TEST_H
#define VOX_MAIN_MEMORY_STATUS_TEST_H

// Selected only by main_memory_status_test.v. The native implementation is
// exercised separately by tools/native_memory_status_test.m.
static int memory_status_test_available_ = 1;
static int memory_status_test_uses_, memory_status_test_disables_;
static float memory_status_test_width_, memory_status_test_y_, memory_status_test_height_;
static void memory_status_test_reset(int available) {
    memory_status_test_available_ = available;
    memory_status_test_uses_ = memory_status_test_disables_ = 0;
}
int native_use_static_memory_label(float width, float y, float height) {
    memory_status_test_uses_++;
    memory_status_test_width_ = width;
    memory_status_test_y_ = y;
    memory_status_test_height_ = height;
    return memory_status_test_available_;
}
void native_disable_static_memory_label(void) { memory_status_test_disables_++; }
static int memory_status_test_uses(void) { return memory_status_test_uses_; }
static int memory_status_test_disables(void) { return memory_status_test_disables_; }
static float memory_status_test_width(void) { return memory_status_test_width_; }
static float memory_status_test_y(void) { return memory_status_test_y_; }
static float memory_status_test_height(void) { return memory_status_test_height_; }
#endif
