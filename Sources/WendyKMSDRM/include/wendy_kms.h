#ifndef WENDY_KMS_H
#define WENDY_KMS_H
#include <stdint.h>
// Deliberately includes NO kernel/DRM headers, so Swift (and macOS) can import
// this cleanly. All DRM uapi lives in wendy_kms.c.
#ifdef __cplusplus
extern "C" {
#endif

typedef struct WendyKMSDisplay {
    int fd;
    uint32_t width;
    uint32_t height;
    uint32_t stride;   // bytes per row
    void *pixels;      // mmap'd XRGB8888 scanout buffer (width*height), or NULL
    void *_priv;       // opaque internal state (ids, mode, saved CRTC)
} WendyKMSDisplay;

// Opens the DRM device, becomes master, sets a mode on the first connected
// connector, allocates+maps a dumb buffer, and scans it out. Returns 0 on
// success (fills *out), or a negative errno; on failure writes a message into
// err (up to errlen bytes).
int wendy_kms_open(const char *path, WendyKMSDisplay *out, char *err, int errlen);

// Restores the previously-active CRTC, drops master, unmaps, and closes.
void wendy_kms_close(WendyKMSDisplay *d);

#ifdef __cplusplus
}
#endif
#endif
