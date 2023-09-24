all: scene.json

resources/Models.blend:
	$(MAKE) -C resources
	# cleanup the models cache
	$(MAKE) clean

scene_.blend: resources/Models.blend
	blender -b -P scene_.py -- "$^"

scene.blend: scene_.blend
	@if [ ! -f $^ ]; then cp $^ $@; fi

scene.json: scene.blend export.py
	blender -b scene.blend -P export.py

clean:
	rm -f cache.bin
