# Makefile

clean-nvim:
	rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim

install-fonts:
	sudo mkdir -p /usr/local/share/fonts/
	sudo cp -r ./assets/fonts/* /usr/local/share/fonts/
	sudo fc-cache -v

swaylist:
	swaymsg -t get_tree | jq -c '.nodes[].nodes[].nodes[] | {id, app_id, name}'
