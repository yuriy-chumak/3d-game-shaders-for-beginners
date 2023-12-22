all: scene.gltf

$(shell [ -s stylized_mangrove_greenhouse.zip ] || rm -rf stylized_mangrove_greenhouse.zip)

# https://sketchfab.com/3d-models/stylized-mangrove-greenhouse-4ad533f838f44fa583683ab7939c6aa1
stylized_mangrove_greenhouse.zip:
	curl -LOk "https://github.com/yuriy-chumak/3d-game-shaders-for-beginners/releases/download/1.0/stylized_mangrove_greenhouse.zip"

scene.gltf: stylized_mangrove_greenhouse.zip
	unzip -d . $^

