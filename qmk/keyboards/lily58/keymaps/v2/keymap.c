// Lily58 v2 (QMK + VIA). The layers mirror ~/.dotfiles/lily58.v2.layout.json, which
// VIA loads at runtime; keep the two in sync when the layout changes.
// Left OLED: layer, WPM, held modifiers. Right OLED: Luna (luna.c).
#include QMK_KEYBOARD_H

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
void render_luna(uint8_t x, uint8_t y);

// The OLEDs are mounted portrait (32x128 -> 5 chars x 16 lines). The right half is
// mounted 180 degrees from the left. If both read upside down, swap 270 and 90.
oled_rotation_t oled_init_user(oled_rotation_t rotation) {
    return is_keyboard_left() ? OLED_ROTATION_270 : OLED_ROTATION_90;
}

static void render_mod(uint8_t mods, uint8_t mask, const char *on, const char *off) {
    oled_write_P((mods & mask) ? on : off, mods & mask);  // held = inverted
}

static void render_status(void) {
    static const char PROGMEM names[][6] = {"BASE ", " SYM ", " NUM ", " FUN "};
    oled_write_P(names[get_highest_layer(layer_state) & 3], false);
    oled_write_P(PSTR("\n\nwpm  "), false);
    oled_write(get_u8_str(get_current_wpm(), ' '), false);
    oled_write_P(PSTR("\n\n"), false);
    uint8_t mods = get_mods() | get_oneshot_mods();
    render_mod(mods, MOD_MASK_CTRL, PSTR(" CTL "), PSTR(" ctl "));
    render_mod(mods, MOD_MASK_SHIFT, PSTR(" SFT "), PSTR(" sft "));
    render_mod(mods, MOD_MASK_ALT, PSTR(" ALT "), PSTR(" alt "));
    render_mod(mods, MOD_MASK_GUI, PSTR(" SUP "), PSTR(" sup "));
}

bool oled_task_user(void) {
    // Content follows the physical half (EE_HANDS), not which half has the USB cable.
    // With the cable in the right half (only for flashing), the left shows stale state.
    if (is_keyboard_left()) {
        render_status();
    } else {
        render_luna(0, 13);  // bottom of the screen: 32x22 px sprite
    }
    return false;
}
#endif
