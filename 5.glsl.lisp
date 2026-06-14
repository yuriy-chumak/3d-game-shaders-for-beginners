#!/usr/bin/env ol
(syscall 1014 (c-string "__NV_PRIME_RENDER_OFFLOAD") (c-string "1") #true)
(syscall 1014 (c-string "__GLX_VENDOR_LIBRARY_NAME") (c-string "nvidia") #true)

; scene
(import (file glTF))
(define scene (read-glTF-file "scene.gltf"))

; opengl
(import (lib gl 2))
(gl:set-window-title "5. GLSL")

; global GL init
(glShadeModel GL_SMOOTH)
(glClearColor 0.11 0.11 0.11 1)
(glEnable GL_DEPTH_TEST)

(import (OpenGL glTF))
(define scene (compile scene))

; render function
(import (scene))

; shader program
(define colorize (gl:create-program
"#version 110 // OpenGL 2.0
   void main() {
      gl_Position = ftransform();
      gl_FrontColor = vec4(0, 1, 0, 1);
   }"
"#version 110 // OpenGL 2.0
   void main() {
      gl_FragColor = gl_Color;
   }"))

; draw
(import (lib GLU))
(import (scheme inexact))

(define time #i0)
(gl:set-calculator (lambda ()
   (vm:set! time (* #i3.0
      (/ (mod (time-ms) 62831) #i10000)))
))

(gl:set-renderer (lambda (mouse vr)
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

   ; draw the model with colors
   (glUseProgram colorize)
   (render-scene scene) ))
