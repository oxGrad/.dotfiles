#pragma once

// No EE_HANDS: the half with the USB cable acts as the left half. That mirrors the
// layout when the cable is in the right half, which is only done for flashing, and it
// makes "thumb 2 + outer top corner" (SYM + QK_BOOT) a bootloader gesture on either half.

// Home-row Ctrl/Esc: tap shorter than 175 ms = Esc; a key pressed and released
// while it is held = Ctrl + key, even inside 175 ms (Permissive Hold).
#define TAPPING_TERM 175
#define PERMISSIVE_HOLD
#define QUICK_TAP_TERM 0

// The right half's Luna follows typing speed and Shift/Ctrl from the left half.
#define SPLIT_WPM_ENABLE
#define SPLIT_MODS_ENABLE
