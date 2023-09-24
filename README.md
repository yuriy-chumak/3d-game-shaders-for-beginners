3D Game Shaders For Beginners
=============================

This is a try to translate and extend an [lettier/3d-game-shaders-for-beginners](https://github.com/lettier/3d-game-shaders-for-beginners) articles to the Ol (Otus Lisp).

*"Interested in adding
~~textures~~,
lighting,
shadows,
normal maps,
glowing objects,
ambient occlusion,
reflections,
refractions,
and more to your 3D game?
Great!
Below is a collection of shading techniques that will take your game visuals to new heights.
I've explained each technique in such a way that you can take what you learn here and apply/port it to
whatever stack you use be it Godot, Unity, Unreal, or something else.
For the glue in between the shaders,
I've chosen the fabulous ~~Panda3D game engine~~ Otus Lisp, OpenGL and the OpenGL Shading Language (GLSL).
So if that is your stack, then you'll also get the benefit of learning how to use these
shading techniques with ~~Panda3D~~ Ol and OpenGL specifically."*

![](https://i.imgur.com/Ck7qf3D.png)

## Table Of Contents

- :heavy_check_mark: [Setup](sections/1.setup.md)
    ([Original topic](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/setup.md))
- :heavy_check_mark: [Dependencies](sections/2.dependencies.md)
    ([Original topic](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/building-the-demo.md))
- :heavy_check_mark: [Running The Demo](sections/3.running-the-demo.md)
    ([Original topic](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/running-the-demo.md))

- :heavy_check_mark: [Reference Frames](sections/4.reference-frames.md)
    ([Original topic](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/reference-frames.md))
- :heavy_check_mark: [GLSL](sections/5.glsl.md)
    ([Original topic](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/glsl.md))
- :heavy_check_mark: [Texturing](sections/5.glsl-texturing.md)
    ([Original topic](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/texturing.md))
- :heavy_check_mark: [Render To Texture](sections/6.render-to-texture.md)
    ([Original topic](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/render-to-texture.md))

- :heavy_check_mark: [Lighting](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/lighting.md)

- :heavy_multiplication_x: [Blinn-Phong](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/blinn-phong.md)
- :heavy_multiplication_x: [Fresnel Factor](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/fresnel-factor.md)
- :heavy_multiplication_x: [Rim Lighting](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/rim-lighting.md)
- :heavy_multiplication_x: [Cel Shading](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/cel-shading.md)
- :heavy_multiplication_x: [Normal Mapping](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/normal-mapping.md)
- :heavy_multiplication_x: [Deferred Rendering](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/deferred-rendering.md)
- :heavy_multiplication_x: [Fog](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/fog.md)
- :heavy_multiplication_x: [Blur](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/blur.md)
- :heavy_multiplication_x: [Bloom](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/bloom.md)
- :heavy_multiplication_x: [SSAO](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/ssao.md)
- :heavy_multiplication_x: [Motion Blur](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/motion-blur.md)
- :heavy_multiplication_x: [Chromatic Aberration](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/chromatic-aberration.md)
- :heavy_multiplication_x: [Screen Space Reflection](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/screen-space-reflection.md)
- :heavy_multiplication_x: [Screen Space Refraction](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/screen-space-refraction.md)
- :heavy_multiplication_x: [Foam](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/foam.md)
- :heavy_multiplication_x: [Flow Mapping](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/flow-mapping.md)
- :heavy_multiplication_x: [Outlining](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/outlining.md)
- :heavy_multiplication_x: [Depth Of Field](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/depth-of-field.md)
- :heavy_multiplication_x: [Posterization](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/posterization.md)
- :heavy_multiplication_x: [Pixelization](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/pixelization.md)
- :heavy_multiplication_x: [Sharpen](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/sharpen.md)
- :heavy_multiplication_x: [Dilation](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/dilation.md)
- :heavy_multiplication_x: [Film Grain](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/film-grain.md)
- :heavy_multiplication_x: [Lookup Table (LUT)](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/lookup-table.md)
- :heavy_multiplication_x: [Gamma Correction](https://github.com/lettier/3d-game-shaders-for-beginners/blob/master/sections/gamma-correction.md)

## Copyright

* Original articles "3D Game Shaders For Beginners" is (C) 2019 [David Lettier](https://github.com/lettier/3d-game-shaders-for-beginners).
  No any part of these articles is included.
* "LowPoly Modular Sci-Fi Environments" 3d-models (c) [quaternius, OpenGameArt](https://opengameart.org/content/lowpoly-modular-sci-fi-environments), CC0 Public Domain.
  Models are not included, but can be automatically downloaded and processed using the 'make' tool.
* These articles and source codes are (c) of me - Y.C., [GPLv3](https://www.gnu.org/licenses/gpl-3.0.html).
