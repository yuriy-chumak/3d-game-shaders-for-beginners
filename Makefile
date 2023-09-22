all: scene_.blend

# https://opengameart.org/content/lowpoly-modular-sci-fi-environments
resources/ultimate_modular_sci-fi_-_feb_2021.zip:
	wget -c "https://opengameart.org/sites/default/files/ultimate_modular_sci-fi_-_feb_2021.zip" -O "$@"

resources/Ultimate\ Modular\ Sci-Fi\ -\ Feb\ 2021: resources/ultimate_modular_sci-fi_-_feb_2021.zip
	unzip -d resources $^ "Ultimate Modular Sci-Fi - Feb 2021/OBJ/*" "Ultimate Modular Sci-Fi - Feb 2021/License.txt"
	blender -b -P resources/re-export.py -- "$@"
	# remove smoothing groups
	find "$@" -name *.obj -exec sed -i '/^s /d' {} +
	# cleanup the models cache
	rm -f cache.bin

resources/Models.blend: resources/Ultimate\ Modular\ Sci-Fi\ -\ Feb\ 2021
	blender -b -P resources/build-all.py -- "$^" "$@"

scene_.blend: resources/Models.blend
	blender -b -P scene_.py
	@echo "Done."
	@echo "Now you can copy scene_blend as any filename [I used scene1.blend]"
	@echo "And start modelling via 'Add/Collection Instance...'"
	@echo "After modelling call 'make scene1.json'"

scene.json: scene.blend export.py
	blender -b scene.blend -P export.py
	#cat scene.json |json_pp |tee scene.json

clean:
	rm -rf "resources/Ultimate Modular Sci-Fi - Feb 2021"
