VIA_ENABLE = yes
OLED_ENABLE = yes
WPM_ENABLE = yes
EXTRAKEY_ENABLE = yes    # volume, play, brightness on FUN
MOUSEKEY_ENABLE = no     # unused; frees flash on the Pro Micro
LTO_ENABLE = yes         # link-time optimisation: smaller firmware
MAGIC_ENABLE = no
SPACE_CADET_ENABLE = no
GRAVE_ESC_ENABLE = no

SRC += luna.c
