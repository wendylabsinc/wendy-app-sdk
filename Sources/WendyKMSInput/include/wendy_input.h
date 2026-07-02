#ifndef WENDY_INPUT_H
#define WENDY_INPUT_H
#include <stdint.h>
// Deliberately includes NO kernel headers so Swift (and macOS) can import this
// cleanly. All evdev uapi lives in wendy_input.c. Mirrors wendy_kms.h.
#ifdef __cplusplus
extern "C" {
#endif

typedef enum WendyTouchKind {
    WENDY_TOUCH_DOWN = 0,
    WENDY_TOUCH_MOVE = 1,
    WENDY_TOUCH_UP   = 2,
} WendyTouchKind;

typedef struct WendyTouchEvent {
    int32_t kind;   // WendyTouchKind
    float x;        // 0..1, normalized via the device's ABS_MT_POSITION_X range
    float y;        // 0..1
} WendyTouchEvent;

typedef struct WendyInputDevice {
    int fd;                       // -1 when closed/unopened
    int32_t min_x, max_x;         // ABS_MT_POSITION_X range
    int32_t min_y, max_y;         // ABS_MT_POSITION_Y range
    // Internal protocol-B decoding state (slot 0 only):
    int32_t cur_slot;
    int32_t slot0_active;         // tracking id >= 0 on slot 0
    int32_t touching;             // state as of the last emitted SYN_REPORT
    int32_t cur_x, cur_y;
    int32_t last_x, last_y;
    char name[80];                // EVIOCGNAME, for diagnostics
    char path[32];                // /dev/input/eventN
} WendyInputDevice;

// Scans /dev/input/event0..31 for the first device advertising
// ABS_MT_POSITION_X, reads the X/Y axis ranges, opens it O_RDONLY|O_NONBLOCK.
// Returns 0 on success (fills *out), else negative; on failure writes a
// diagnostic into err (every scanned device and why it was rejected).
int wendy_input_open(WendyInputDevice *out, char *err, int errlen);

// The pollable fd (for a dispatch read source), or -1.
int wendy_input_fd(const WendyInputDevice *d);

// Drains all readable input_events, emitting at most `cap` simplified touch
// events (down/move/up, coordinates normalized to 0..1) on SYN_REPORT
// boundaries. Returns the number emitted (0 when nothing pending), or a
// negative value when the device is gone (caller should stop polling).
int wendy_input_poll(WendyInputDevice *d, WendyTouchEvent *out, int cap);

void wendy_input_close(WendyInputDevice *d);

#ifdef __cplusplus
}
#endif
#endif
