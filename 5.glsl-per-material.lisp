#!/usr/bin/env ol

; initialize OpenGL
(import (lib gl-2))
(gl:set-window-title "glsl-per-material.lisp")

; gl global init
(glShadeModel GL_SMOOTH)
(glEnable GL_DEPTH_TEST)

(glEnable GL_CULL_FACE); GL_BACK

; scene
(import (scene))

; load (and create if no one) a models cache
(define models (prepare-models "cache.bin"))
(define geometry (compile-triangles models))

; load a scene
(import (file json))
(define scene (read-json-file "scene.json"))

; scene lights
(define Lights (vector->list (scene 'Lights)))
(print "Lights: " Lights)

; scene objects
(define Objects (vector->list (scene 'Objects)))
(print "Objects: " Objects)

; let's rotate ceilingFan
(attach-entity-handler "ceilingFan" (lambda (entity)
   (define-values (ss ms) (clock))
   (ff-replace entity {
      'rotation [0 0 (+ (mod (* ss 10) 360) (/ ms 100))]
   })))

; We are moving away from the fixed OpenGL pipeline, in which
; Model and View matrices are combined into one.
; As a Model matrix we will use gl_TextureMatrix[7].

; simple glsl shader program (greenify)
(define colorize (gl:create-program
"#version 120 // OpenGL 2.1
   #define gl_ModelMatrix gl_TextureMatrix[7]   // Model matrix
   #define gl_ViewProjectionMatrix gl_ModelViewProjectionMatrix

   void main() {
      gl_Position = gl_ViewProjectionMatrix * gl_ModelMatrix * gl_Vertex;
      gl_FrontColor = gl_Color;
   }"
"#version 120 // OpenGL 2.1
   void main() {
      gl_FragColor = gl_Color;
   }"))

(set-default-material-handler (lambda (material)
   (glUseProgram colorize)
))

(define greenify (gl:create-program
"#version 120 // OpenGL 2.1
   #define gl_ModelMatrix gl_TextureMatrix[7] // our model matrix
   #define gl_ViewProjectionMatrix gl_ModelViewProjectionMatrix

   void main() {
      gl_Position = gl_ViewProjectionMatrix * gl_ModelMatrix * gl_Vertex;
   }"
"#version 120 // OpenGL 2.1
   void main() {
      gl_FragColor = vec4(0,1,0,1);
   }"))

(attach-material-handler '("metalLight.009" "lamp.005" "wood.074")
   (lambda (material)
      (glUseProgram greenify)
))

(import (scheme inexact))
(import (otus random!))
(define blinker (gl:create-program
"#version 120 // OpenGL 2.1
   #define gl_ModelMatrix gl_TextureMatrix[7] // our model matrix
   #define gl_ViewProjectionMatrix gl_ModelViewProjectionMatrix

   void main() {
      gl_Position = gl_ViewProjectionMatrix * gl_ModelMatrix * gl_Vertex;
      gl_FrontColor = gl_Color;
   }"
"#version 120 // OpenGL 2.1
   uniform float brightness;
   void main() {
      gl_FragColor = gl_Color * vec4(brightness,brightness,brightness,1);
   }"))

(attach-material-handler '("metal.022")
   (lambda (material entity)
      (define ddx (if (string-eq? (entity 'name "") "laptop") 237 311))
      (define ddy (if (string-eq? (entity 'name "") "laptop") 111 556))

      (define-values (ss ms) (clock))
      (glUseProgram blinker)
      (glUniform1f (glGetUniformLocation blinker "brightness")
         (+ 0.6
            (* (sin (/ ms ddx)) (sin (/ ms ddx))
               (cos (/ ms ddy))
               0.2)))
))

; draw
(gl:set-renderer (lambda ()
   (glClearColor 0.1 0.1 0.1 1)
   (glClear (vm:ior GL_COLOR_BUFFER_BIT GL_DEPTH_BUFFER_BIT))

   ; camera setup
   (begin
      (define Camera (ref (scene 'Cameras) 1))

      (glMatrixMode GL_PROJECTION)
      (glLoadIdentity)
      (gluPerspective
         (Camera 'angle)
         (/ (gl:get-window-width) (gl:get-window-height))
         (Camera 'clip_start) (Camera 'clip_end))

      (define target (vector->list (Camera 'target)))
      (define location (vector->list (Camera 'location)))
      (define up (vector->list [0 0 1]))

      (glMatrixMode GL_MODELVIEW)
      (glLoadIdentity)
      (apply gluLookAt (append location target up)))

   ; draw the geometry with colors
   (render-scene Objects geometry)

   ; Draw a light bulbs
   (draw-lightbulbs Lights)
))
