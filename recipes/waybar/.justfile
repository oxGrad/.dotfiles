kill:
  pkill waybar

restart: kill
  just start

start:
  waybar &

