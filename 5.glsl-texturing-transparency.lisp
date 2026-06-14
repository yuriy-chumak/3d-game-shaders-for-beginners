#!/usr/bin/env ol
(syscall 1014 (c-string "__NV_PRIME_RENDER_OFFLOAD") (c-string "1") #true)
(syscall 1014 (c-string "__GLX_VENDOR_LIBRARY_NAME") (c-string "nvidia") #true)

(import (lib gl 2))
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

(import (OpenGL glTF))
(define scene (compile scene))

; helper functions
(import (scene))
(import (scheme inexact))

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
(import (lib GLU))

(define time #i0)
(gl:set-calculator (lambda ()
   (vm:set! time (* #i3.0
      (/ (mod (time-ms) 62831) #i10000)))
))

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

   (define scale #i1)
   (define radius (* scale 25))
   (define dx #i-0.46)
   (define dy (* scale 8))

   (define location (list
      (+ dx (* radius (cos time)))
      (+ dy (* scale 4))
      (* radius (sin time))))
   (define target (list dx 0 0))
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
