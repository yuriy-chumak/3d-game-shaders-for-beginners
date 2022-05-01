# sanity check
$(shell [ -s scene.json ] || rm -f scene.json)

all: scene.json

# https://opengameart.org/content/nature-kit
# https://opengameart.org/content/furniture-kit
#	https://opengameart.org/sites/default/files/kenney_furniturePack.zip

# https://opengameart.org/content/castle-kit
#	https://opengameart.org/sites/default/files/Castle%20Kit%20%281.0%29.zip

# https://opengameart.org/content/retro-medieval-kit
#	https://opengameart.org/sites/default/files/retro_medieval_kit_1.0.zip

# https://opengameart.org/content/city-kit-commercial
#	https://opengameart.org/sites/default/files/kenney_citykitcommercial_1.2.zip

# https://opengameart.org/content/pirate-kit
#	https://opengameart.org/sites/default/files/kenney_pirateKit.zip

# https://opengameart.org/content/retro-urban-kit
#	https://opengameart.org/sites/default/files/retro_urban_kit_1.0.zip

# # https://opengameart.org/content/lowpoly-modular-sci-fi-environments
# resources/ultimate_modular_sci-fi_-_feb_2021.zip:
# 	wget -c "https://opengameart.org/sites/default/files/ultimate_modular_sci-fi_-_feb_2021.zip" -O "$@"
#
# resources/Ultimate\ Modular\ Sci-Fi\ -\ Feb\ 2021: resources/ultimate_modular_sci-fi_-_feb_2021.zip
# 	unzip -d resources $^ "Ultimate Modular Sci-Fi - Feb 2021/OBJ/*" "Ultimate Modular Sci-Fi - Feb 2021/License.txt"
# 	cd resources; blender -b -P re-export.py; cd ..
# 	# remove smoothing groups
# 	find . -name "*.obj" -exec sed -i '/^s /d' {} +
# 	# cleanup the models cache
# 	rm -f cache.bin
#
# resources/Models.blend: resources/Ultimate\ Modular\ Sci-Fi\ -\ Feb\ 2021
# 	cd resources; blender -b -P build-all.py; cd ..
#
# scene_.blend: resources/Models.blend
# 	blender -b -P scene_.py
# 	@echo "Done."
# 	@echo "Now you can copy scene_blend as any filename [I used scene1.blend]"
# 	@echo "And start modelling via 'Add/Collection Instance...'"
# 	@echo "After modelling call 'make scene1.json'"

scene.json: scene.blend export.py
	blender -b scene.blend -P export.py
	cat scene.json |json_pp |tee scene.json

clean:
	#rm -rf "resources/Ultimate Modular Sci-Fi - Feb 2021"
	rm -f cache.bin

