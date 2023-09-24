# https://opengameart.org/content/lowpoly-modular-sci-fi-environments
ultimate_modular_sci-fi_-_feb_2021.zip:
	wget -c "https://opengameart.org/sites/default/files/ultimate_modular_sci-fi_-_feb_2021.zip" -O "$@"

Ultimate\ Modular\ Sci-Fi\ -\ Feb\ 2021: ultimate_modular_sci-fi_-_feb_2021.zip
	unzip -d resources $^ "Ultimate Modular Sci-Fi - Feb 2021/OBJ/*" "Ultimate Modular Sci-Fi - Feb 2021/License.txt"
	blender -b -P re-export.py -- "$@"
	# remove smoothing groups
	find "$@" -name *.obj -exec sed -i '/^s /d' {} +

Models.blend: Ultimate\ Modular\ Sci-Fi\ -\ Feb\ 2021
	blender -b -P build-all.py -- "$^" "$@"
