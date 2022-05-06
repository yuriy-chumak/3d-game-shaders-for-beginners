#!/usr/bin/env ol

; initialize OpenGL
(import (lib gl-2))
(gl:set-window-title "glsl.lisp")

; gl global init
(glShadeModel GL_SMOOTH)
(glEnable GL_DEPTH_TEST)

(glEnable GL_CULL_FACE)

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
   (glUseProgram colorize)

   (define models (ref geometry 2))
   (for-each (lambda (object)
         (define model (object 'model))

         (define location (object 'location))
         ; let's rotate ceilingFan
         (define rotation (if (string-eq? (object 'name "") "ceilingFan")
            (let*((ss ms (clock)))
               [0 0 (+ (mod (* ss 10) 360) (/ ms 100))])
            (object 'rotation)))

         (glActiveTexture GL_TEXTURE7)  ; my_ModelMatrix
         (glMatrixMode GL_TEXTURE)
         (glLoadIdentity) ; let's prepare my_ModelMatrix
         ; transformations
         (let ((xyz location))
            (glTranslatef (ref xyz 1) (ref xyz 2) (ref xyz 3)))
         ; blender rotation mode is "YPR": yaw, pitch, roll
         (let ((ypr rotation))
            (glRotatef (ref ypr 3) 0 0 1)
            (glRotatef (ref ypr 2) 0 1 0)
            (glRotatef (ref ypr 1) 1 0 0))
         ; precompiled geometry
         (for-each glCallList
            (map car (models (string->symbol model)))))
      Objects)

   ; Draw a light bulbs
   (draw-lightbulbs Lights)
))
