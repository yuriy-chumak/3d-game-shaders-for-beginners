#!/usr/bin/env ol

; initialize OpenGL
(import (lib gl-2))
(gl:set-window-title "lighting")
(import (scheme dynamic-bindings))

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

;; shaders
(define po (gl:create-program
"#version 120 // OpenGL 2.1
   #define gl_WorldMatrix gl_TextureMatrix[7]
   void main() {
      gl_Position = gl_ModelViewProjectionMatrix * gl_WorldMatrix * gl_Vertex;
   }"
"#version 120 // OpenGL 2.1
   void main() {
      // nothing to do
   }"))

;; -----------------------
; https://learnopengl.com/Getting-started/Coordinate-Systems
; модели освещения: http://steps3d.narod.ru/tutorials/lighting-tutorial.html

(define lighting (gl:create-program ; todo: add "#define" to the shaders aas part of language
   (file->string "shaders/8.lighting.vs")
   (file->string "shaders/8.lighting.fs")))

;; draw
(import (lib math))
(import (owl math fp))

; настройки
(glShadeModel GL_SMOOTH)
(glClearColor 0.2 0.2 0.2 1)

(glEnable GL_DEPTH_TEST)

;; освещение сцены
(glEnable GL_LIGHTING)

(glLightModelfv GL_LIGHT_MODEL_AMBIENT '(0.1 0.1 0.1 1))
; set lights specular colors
(for-each (lambda (i)
      (glEnable (+ GL_LIGHT0 i))
      (glLightfv (+ GL_LIGHT0 i) GL_AMBIENT '(1.0 1.0 1.0 1))
      (glLightfv (+ GL_LIGHT0 i) GL_DIFFUSE '(1.0 1.0 1.0 1))
      (glLightfv (+ GL_LIGHT0 i) GL_SPECULAR '(1.0 1.0 1.0 1))
      ; GL_EMISSION
      ; GL_SHININESS
      ; 
      )
   (iota (length Lights)))

(glPolygonMode GL_FRONT_AND_BACK GL_FILL)
(define quadric (gluNewQuadric))

; draw
(gl:set-renderer (lambda (mouse)
   (glClearColor 0 0 0 1)
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

   ; let's add dynamic light (i want to see dynamic changes of lighting)
   (define-values (ss ms) (clock))
   (define ticks (/ (+ ss (/ ms 1000)) 0.1))

   (define lights (append Lights (list
      {
         'type "POINT"
         'color [1 1 1]
         'position [
            (* 5 (sin (/ ticks 20)))
            (* 5 (cos (/ ticks 20)))
            4
            1]
      })))

   ; draw a scene
   (glUseProgram lighting)
   (glUniform1i (glGetUniformLocation lighting "lightsCount") (length lights))

   ; define light positions
   ;(glEnable GL_LIGHTING)
   (for-each (lambda (light i)
      (vector-apply (light 'position)
         (lambda (x y z w)
            (glLightfv (+ GL_LIGHT0 i) GL_POSITION (list x y z w)))))
      lights
      (iota (length lights)))

   ; draw the geometry with colors
   (render-scene Objects geometry)

   ; Draw a light bulbs
   (draw-lightbulbs lights)

))
