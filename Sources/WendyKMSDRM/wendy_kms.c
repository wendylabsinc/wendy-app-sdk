#include "wendy_kms.h"

#if defined(__linux__)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <stdint.h>
#include <drm/drm.h>
#include <drm/drm_mode.h>

typedef struct {
    uint32_t conn_id, crtc_id, fb_id, handle;
    uint64_t size;
    struct drm_mode_modeinfo mode;
    struct drm_mode_crtc saved;   // CRTC state before we touched it
} Priv;

static int fail(int fd, char *err, int errlen, const char *what) {
    int e = errno ? errno : EINVAL;
    snprintf(err, errlen, "%s: %s", what, strerror(e));
    if (fd >= 0) close(fd);
    return -e;
}

int wendy_kms_open(const char *path, WendyKMSDisplay *out, char *err, int errlen) {
    memset(out, 0, sizeof(*out));
    int fd = open(path, O_RDWR | O_CLOEXEC);
    if (fd < 0) return fail(-1, err, errlen, "open");

    // Become master (no-op/best effort if we are the sole DRM client).
    ioctl(fd, DRM_IOCTL_SET_MASTER, 0);

    // Pass 1: counts.
    struct drm_mode_card_res res; memset(&res, 0, sizeof res);
    if (ioctl(fd, DRM_IOCTL_MODE_GETRESOURCES, &res)) return fail(fd, err, errlen, "GETRESOURCES count");

    uint64_t conn_ids[32], crtc_ids[32], enc_ids[32], fb_ids[32];
    if (res.count_connectors > 32) res.count_connectors = 32;
    if (res.count_crtcs > 32) res.count_crtcs = 32;
    if (res.count_encoders > 32) res.count_encoders = 32;
    if (res.count_fbs > 32) res.count_fbs = 32;
    res.connector_id_ptr = (uint64_t)(uintptr_t)conn_ids;
    res.crtc_id_ptr      = (uint64_t)(uintptr_t)crtc_ids;
    res.encoder_id_ptr   = (uint64_t)(uintptr_t)enc_ids;
    res.fb_id_ptr        = (uint64_t)(uintptr_t)fb_ids;
    if (ioctl(fd, DRM_IOCTL_MODE_GETRESOURCES, &res)) return fail(fd, err, errlen, "GETRESOURCES");

    // Find a connected connector with at least one mode.
    uint32_t chosen_conn = 0, chosen_enc = 0;
    struct drm_mode_modeinfo chosen_mode; memset(&chosen_mode, 0, sizeof chosen_mode);
    int found = 0;
    for (uint32_t i = 0; i < res.count_connectors && !found; i++) {
        struct drm_mode_get_connector conn; memset(&conn, 0, sizeof conn);
        conn.connector_id = (uint32_t)conn_ids[i];
        if (ioctl(fd, DRM_IOCTL_MODE_GETCONNECTOR, &conn)) continue; // pass 1: counts
        if (conn.connection != 1 /* DRM_MODE_CONNECTED */ || conn.count_modes == 0) continue;

        struct drm_mode_modeinfo modes[64];
        uint64_t encs[32];
        uint32_t nmodes = conn.count_modes > 64 ? 64 : conn.count_modes;
        uint32_t nencs  = conn.count_encoders > 32 ? 32 : conn.count_encoders;
        conn.modes_ptr = (uint64_t)(uintptr_t)modes; conn.count_modes = nmodes;
        conn.encoders_ptr = (uint64_t)(uintptr_t)encs; conn.count_encoders = nencs;
        conn.props_ptr = 0; conn.prop_values_ptr = 0; conn.count_props = 0;
        if (ioctl(fd, DRM_IOCTL_MODE_GETCONNECTOR, &conn)) continue; // pass 2: data
        if (conn.count_modes == 0) continue;

        chosen_conn = conn.connector_id;
        chosen_enc  = conn.encoder_id;
        chosen_mode = modes[0]; // preferred/first mode
        found = 1;
    }
    if (!found) { snprintf(err, errlen, "no connected connector with a mode"); close(fd); return -ENODEV; }

    // CRTC: via the connector's encoder if set, else first CRTC.
    uint32_t crtc_id = 0;
    if (chosen_enc) {
        struct drm_mode_get_encoder enc; memset(&enc, 0, sizeof enc);
        enc.encoder_id = chosen_enc;
        if (!ioctl(fd, DRM_IOCTL_MODE_GETENCODER, &enc)) crtc_id = enc.crtc_id;
    }
    if (!crtc_id && res.count_crtcs > 0) crtc_id = (uint32_t)crtc_ids[0];
    if (!crtc_id) { snprintf(err, errlen, "no usable CRTC"); close(fd); return -ENODEV; }

    // Dumb buffer.
    struct drm_mode_create_dumb creq; memset(&creq, 0, sizeof creq);
    creq.width = chosen_mode.hdisplay; creq.height = chosen_mode.vdisplay; creq.bpp = 32;
    if (ioctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &creq)) return fail(fd, err, errlen, "CREATE_DUMB");

    struct drm_mode_fb_cmd fb; memset(&fb, 0, sizeof fb);
    fb.width = creq.width; fb.height = creq.height; fb.pitch = creq.pitch;
    fb.bpp = 32; fb.depth = 24; fb.handle = creq.handle;
    if (ioctl(fd, DRM_IOCTL_MODE_ADDFB, &fb)) return fail(fd, err, errlen, "ADDFB");

    struct drm_mode_map_dumb mreq; memset(&mreq, 0, sizeof mreq);
    mreq.handle = creq.handle;
    if (ioctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &mreq)) return fail(fd, err, errlen, "MAP_DUMB");

    void *map = mmap(0, creq.size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, mreq.offset);
    if (map == MAP_FAILED) return fail(fd, err, errlen, "mmap");
    memset(map, 0, creq.size);

    // Save current CRTC, then scan out our framebuffer.
    struct drm_mode_crtc saved; memset(&saved, 0, sizeof saved);
    saved.crtc_id = crtc_id;
    ioctl(fd, DRM_IOCTL_MODE_GETCRTC, &saved);

    struct drm_mode_crtc set; memset(&set, 0, sizeof set);
    set.crtc_id = crtc_id; set.fb_id = fb.fb_id; set.x = 0; set.y = 0;
    uint32_t cid = chosen_conn;
    set.set_connectors_ptr = (uint64_t)(uintptr_t)&cid; set.count_connectors = 1;
    set.mode = chosen_mode; set.mode_valid = 1;
    if (ioctl(fd, DRM_IOCTL_MODE_SETCRTC, &set)) return fail(fd, err, errlen, "SETCRTC");

    Priv *p = (Priv *)calloc(1, sizeof(Priv));
    p->conn_id = chosen_conn; p->crtc_id = crtc_id; p->fb_id = fb.fb_id;
    p->handle = creq.handle; p->size = creq.size; p->mode = chosen_mode; p->saved = saved;

    out->fd = fd; out->width = creq.width; out->height = creq.height;
    out->stride = creq.pitch; out->pixels = map; out->_priv = p;
    return 0;
}

void wendy_kms_close(WendyKMSDisplay *d) {
    if (!d || d->fd < 0) return;
    Priv *p = (Priv *)d->_priv;
    if (p) {
        if (p->saved.mode_valid) {
            // Restore prior scanout.
            uint32_t cid = p->conn_id;
            p->saved.set_connectors_ptr = (uint64_t)(uintptr_t)&cid;
            p->saved.count_connectors = 1;
            ioctl(d->fd, DRM_IOCTL_MODE_SETCRTC, &p->saved);
        }
        if (d->pixels && d->pixels != MAP_FAILED) munmap(d->pixels, p->size);
        if (p->fb_id) { uint32_t fbid = p->fb_id; ioctl(d->fd, DRM_IOCTL_MODE_RMFB, &fbid); }
        if (p->handle) {
            struct drm_mode_destroy_dumb dreq; memset(&dreq, 0, sizeof dreq);
            dreq.handle = p->handle;
            ioctl(d->fd, DRM_IOCTL_MODE_DESTROY_DUMB, &dreq);
        }
        free(p);
    }
    ioctl(d->fd, DRM_IOCTL_DROP_MASTER, 0);
    close(d->fd);
    d->fd = -1; d->pixels = NULL; d->_priv = NULL;
}

#else  // non-Linux: empty stubs so the package builds on macOS.

#include <string.h>
#include <stdio.h>
int wendy_kms_open(const char *path, WendyKMSDisplay *out, char *err, int errlen) {
    (void)path; if (out) memset(out, 0, sizeof(*out));
    snprintf(err, errlen, "WendyKMSDRM is Linux-only");
    return -1;
}
void wendy_kms_close(WendyKMSDisplay *d) { (void)d; }

#endif
