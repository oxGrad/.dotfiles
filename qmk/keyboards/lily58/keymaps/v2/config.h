#pragma once

// No EE_HANDS: the half with the USB cable acts as the left half. That mirrors the
// layout when the cable is in the right half, which is only done for flashing, and it
// makes "thumb 2 + outer top corner" (SYM + QK_BOOT) a bootloader gesture on either half.

// Home-row Ctrl/Esc: tap shorter than 175 ms = Esc; a key pressed and released
// while it is held = Ctrl + key, even inside 175 ms (Permissive Hold).
#define TAPPING_TERM 175
#define PERMISSIVE_HOLD
#define QUICK_TAP_TERM 0

// The right OLED shows layer, mods and WPM, which live on the left (USB) half.
#define SPLIT_LAYER_STATE_ENABLE
#define SPLIT_MODS_ENABLE
#define SPLIT_WPM_ENABLE

// Screens sleep 30 s after typing stops (wear on the always-lit parts of the right screen).
#define OLED_TIMEOUT 30000
