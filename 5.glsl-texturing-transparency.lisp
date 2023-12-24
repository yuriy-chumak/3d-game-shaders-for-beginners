#!/usr/bin/env ol
(import (lib gl-2))
(gl:set-window-title "5. GLSL")

; global GL init
(glShadeModel GL_SMOOTH)
(glClearColor 0.11 0.11 0.11 1)
(glEnable GL_DEPTH_TEST)

(glEnable GL_BLEND)
(glBlendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA)
(glEnable GL_TEXTURE_2D)

; scene
(import (file glTF))
(define scene (read-glTF-file "scene.gltf"))

; helper functions
(import (scene))

; shader program
(define opaque (gl:create-program
"#version 110 // OpenGL 2.0
   void main() {
      gl_Position = ftransform();
      gl_TexCoord[0] = gl_MultiTexCoord0;
   }"
"#version 110 // OpenGL 2.0
   uniform sampler2D tex;
   void main() {
      gl_FragColor = texture2D(tex, gl_TexCoord[0].st);
   }"))
(define masked (gl:create-program
"#version 110 // OpenGL 2.0
   void main() {
      gl_Position = ftransform();
      gl_TexCoord[0] = gl_MultiTexCoord0;
   }"
"#version 110 // OpenGL 2.0
   uniform sampler2D tex;
   uniform float alphaCutoff;
   void main() {
      gl_FragColor = texture2D(tex, gl_TexCoord[0].st);
      if (gl_FragColor.a < alphaCutoff)
         discard;
   }"))

; draw
(import (owl math fp))
(import (lib GLU))

(gl:set-renderer (lambda ()
   (glClear GL_COLOR_BUFFER_BIT)
   (glClear GL_DEPTH_BUFFER_BIT)

   ; camera setup
   (glMatrixMode GL_PROJECTION)
   (glLoadIdentity)
   (gluPerspective
      45.0
      (/ (gl:get-window-width) (gl:get-window-height))
      0.1 1000) ; near - far

   ;; (define target '(0 0 0))
   ;; (define location '(0 6 30))
   ;; (define up '(0 4 0))

   (define time (/ (mod (time-ms) 62831) #i10000))
   (define radius 25)

   (define location (list
      (* radius (fcos time))
      8
      (* radius (fsin time))))
   (define target '(0 2 0))
   (define up '(0 1 0))

   (glMatrixMode GL_MODELVIEW)
   (glLoadIdentity)
   (apply gluLookAt (append location target up))

   ; draw the OPAQUE geometry details
   (glUseProgram opaque)
   (render-scene scene (lambda (material)
      (eq? (material 'alphaMode 'OPAQUE) 'OPAQUE)))
   ; additionally, draw MASKed elements
   (glUseProgram masked)
   (render-scene scene (lambda (material)
      (eq? (material 'alphaMode #f) 'MASK)))

   ; and now - transparent things
   (glUseProgram opaque)
   (render-scene scene (lambda (material)
      (eq? (material 'alphaMode #f) 'BLEND)))

))
