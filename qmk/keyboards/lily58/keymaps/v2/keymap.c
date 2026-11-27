// Lily58 v2 (QMK + VIA). The layers mirror ~/.dotfiles/lily58.v2.layout.json, which
// VIA loads at runtime; keep the two in sync when the layout changes.
// Left OLED: WPM graph + Luna (luna.c). Right OLED: layer, WPM, held modifiers.
#include QMK_KEYBOARD_H
#include <string.h>

enum layers { BASE, SYM, NUM, FUN };

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    [BASE] = LAYOUT(
        KC_GRV        , KC_1          , KC_2          , KC_3          , KC_4          , KC_5          , KC_6          , KC_7          , KC_8          , KC_9          , KC_0          , KC_DEL,
        KC_TAB        , KC_Q          , KC_W          , KC_E          , KC_R          , KC_T          , KC_Y          , KC_U          , KC_I          , KC_O          , KC_P          , KC_MINS,
        LCTL_T(KC_ESC), KC_A          , KC_S          , KC_D          , KC_F          , KC_G          , KC_H          , KC_J          , KC_K          , KC_L          , KC_SCLN       , KC_QUOT,
        KC_LSFT       , KC_Z          , KC_X          , KC_C          , KC_V          , KC_B          , KC_PSCR       , KC_EQL        , KC_N          , KC_M          , KC_COMM       , KC_DOT        , KC_SLSH       , KC_BSLS,
        KC_LALT       , MO(SYM)       , KC_LGUI       , KC_SPC        , KC_ENT        , KC_BSPC       , MO(NUM)       , XXXXXXX
    ),
    [SYM] = LAYOUT(
        QK_BOOT   , _______   , _______   , _______   , _______   , _______   , _______   , _______   , _______   , _______   , _______   , _______,
        _______   , S(KC_1)   , S(KC_2)   , S(KC_3)   , S(KC_4)   , S(KC_5)   , S(KC_6)   , S(KC_7)   , S(KC_8)   , KC_MINS   , KC_EQL    , S(KC_EQL),
        _______   , KC_GRV    , S(KC_LBRC), KC_LBRC   , S(KC_9)   , S(KC_COMM), S(KC_DOT) , S(KC_0)   , KC_RBRC   , S(KC_RBRC), S(KC_SCLN), S(KC_QUOT),
        _______   , S(KC_GRV) , KC_BSLS   , S(KC_BSLS), S(KC_MINS), S(KC_EQL) , _______   , _______   , _______   , _______   , _______   , _______   , _______   , _______,
        _______   , _______   , _______   , _______   , _______   , KC_DEL    , _______   , _______
    ),
    [NUM] = LAYOUT(
        _______   , _______   , _______   , _______   , _______   , _______   , _______   , _______   , _______   , _______   , _______   , _______,
        _______   , S(KC_8)   , KC_7      , KC_8      , KC_9      , KC_MINS   , KC_HOME   , KC_PGDN   , KC_PGUP   , KC_END    , XXXXXXX   , XXXXXXX,
        _______   , KC_SLSH   , KC_4      , KC_5      , KC_6      , S(KC_EQL) , KC_LEFT   , KC_DOWN   , KC_UP     , KC_RGHT   , S(KC_SCLN), XXXXXXX,
        _______   , KC_0      , KC_1      , KC_2      , KC_3      , KC_DOT    , _______   , _______   , _______   , _______   , _______   , _______   , _______   , XXXXXXX,
        _______   , _______   , _______   , _______   , _______   , _______   , _______   , _______
    ),
    [FUN] = LAYOUT(
        _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______,
        _______, KC_F12 , KC_F7  , KC_F8  , KC_F9  , XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, QK_BOOT,
        _______, KC_F11 , KC_F4  , KC_F5  , KC_F6  , XXXXXXX, KC_MUTE, KC_VOLD, KC_VOLU, KC_MPLY, XXXXXXX, XXXXXXX,
        _______, KC_F10 , KC_F1  , KC_F2  , KC_F3  , XXXXXXX, _______, _______, KC_PSCR, KC_BRID, KC_BRIU, XXXXXXX, XXXXXXX, XXXXXXX,
        _______, _______, _______, _______, _______, _______, _______, _______
    )
};

// Holding SYM + NUM opens FUN. The layout has no MO(FUN) key and relies on this.
layer_state_t layer_state_set_user(layer_state_t state) {
    return update_tri_layer_state(state, SYM, NUM, FUN);
}

#ifdef OLED_ENABLE
void luna_space(bool pressed);

// Luna runs on the USB (left) half, which processes every key, so Space goes straight to it.
bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    if (keycode == KC_SPC) luna_space(record->event.pressed);
    return true;
}

// Both OLEDs are portrait: 32 x 128 px. Pixel coordinates below are in that orientation.
void render_luna(uint8_t x, uint8_t y);
extern const unsigned char font[] PROGMEM;  // lib/glcdfont_lily.c, 6x8 glyphs

oled_rotation_t oled_init_user(oled_rotation_t rotation) {
    return OLED_ROTATION_270;
}

static void fill_rect(uint8_t x, uint8_t y, uint8_t w, uint8_t h, bool on) {
    for (uint8_t i = 0; i < w; i++) {
        for (uint8_t j = 0; j < h; j++) {
            oled_write_pixel(x + i, y + j, on);
        }
    }
}

// Font drawn 2x: glyph ink is 5x7 -> 10x14 px on an 11 px pitch, so three characters
// fill the 32 px width exactly. Redraws a full 32x16 band at y; inverted = white band.
static void draw_big(uint8_t y, const char *s, bool invert) {
    uint8_t x = (32 - (strlen(s) * 11 - 1)) / 2;
    fill_rect(0, y, 32, 16, invert);
    for (; *s; s++, x += 11) {
        for (uint8_t c = 0; c < 5; c++) {
            uint8_t bits = pgm_read_byte(&font[(uint8_t)*s * OLED_FONT_WIDTH + c]);
            for (uint8_t r = 0; r < 7; r++) {
                if (bits & (1 << r)) fill_rect(x + 2 * c, y + 1 + 2 * r, 2, 2, !invert);
            }
        }
    }
}

// Right: layer, WPM, held modifiers (synced from the left). Redraws only what changed.
static void render_status(void) {
    static const char names[4][4] = {"ABC", "SYM", "NUM", "FUN"};
    static uint8_t    last_layer = 255, last_mods = 255, last_wpm = 255;

    uint8_t layer = get_highest_layer(layer_state) & 3;
    uint8_t wpm   = get_current_wpm();
    uint8_t mods  = get_mods() | get_oneshot_mods();

    if (last_layer == 255) {  // static parts, once
        fill_rect(0, 18, 32, 1, true);
        oled_set_cursor(1, 5);
        oled_write_P(PSTR("wpm"), false);
        fill_rect(0, 51, 32, 1, true);
    }
    if (layer != last_layer) {
        last_layer = layer;
        draw_big(0, names[layer], false);
    }
    if (wpm != last_wpm) {
        last_wpm      = wpm;
        const char *n = get_u8_str(wpm, ' ');
        while (*n == ' ') n++;
        draw_big(22, n, false);
    }
    if (mods != last_mods) {
        last_mods = mods;
        draw_big(56, "CTL", mods & MOD_MASK_CTRL);
        draw_big(74, "SFT", mods & MOD_MASK_SHIFT);
        draw_big(92, "ALT", mods & MOD_MASK_ALT);
        draw_big(110, "SUP", mods & MOD_MASK_GUI);
    }
}

// Left: typing speed over the last 32 s (one bar per second) above Luna.
#define GRAPH_Y 4
#define GRAPH_H 92  // ends at y 95: Luna jumps into y 96-103. Height = wpm * 2/3 (138 wpm = top)
static void render_graph(void) {
    static uint8_t  hist[32];
    static uint32_t sample_timer = 0;
    if (timer_elapsed32(sample_timer) < 1000) return;
    sample_timer = timer_read32();
    memmove(hist, hist + 1, sizeof(hist) - 1);
    hist[31] = get_current_wpm();
    fill_rect(0, GRAPH_Y, 32, GRAPH_H, false);
    // 1 px line, one point per second. Each column joins its point to the previous one so
    // steep changes stay connected. Zero speed draws nothing: the graph is blank when idle.
    uint8_t prev = 0;  // y of the previous point, 0 = none (points are always at y >= GRAPH_Y)
    for (uint8_t x = 0; x < 32; x++) {
        if (!hist[x]) {
            prev = 0;
            continue;
        }
        uint8_t y    = GRAPH_Y + GRAPH_H - 1 - MIN((uint16_t)hist[x] * 2 / 3, GRAPH_H - 1);
        uint8_t from = prev ? MIN(y, prev) : y, to = prev ? MAX(y, prev) : y;
        for (uint8_t yy = from; yy <= to; yy++) oled_write_pixel(x, yy, true);
        prev = y;
    }
}

bool oled_task_user(void) {
    // The USB half acts as the left half (no EE_HANDS), so this follows the cable.
    if (is_keyboard_left()) {
        // Drawing turns the OLED back on (oled_driver.c), so stop drawing to let it sleep.
        static uint32_t idle_timer = 0;
        if (get_current_wpm() > 0 || get_mods()) idle_timer = timer_read32();
        if (timer_elapsed32(idle_timer) > OLED_TIMEOUT) {
            oled_off();
            return false;
        }
        render_graph();
        render_luna(0, 13);  // bottom of the screen: 32x22 px sprite at y 104
    } else {
        render_status();  // redraws only on change, so the driver's timeout puts it to sleep
    }
    return false;
}
#endif
