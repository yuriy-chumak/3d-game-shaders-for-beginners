#!/usr/bin/env ol

; initialize OpenGL
(import (lib gl-2))
(gl:set-window-title "lighting")
(import (lib x11))

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

; найдем код текстуры дисплея
(define computer-screen-texture (ref ((ref geometry 1) '|metal.024|) 3))
; сконфигурируем
(define dpy (XOpenDisplay #f))
(define root (XDefaultRootWindow dpy))
(define SCREENW 1920)
(define SCREENH 1080)

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

(define lighting (gl:create-program
   (file->string "shaders/8.lighting.vs")
   (file->string "shaders/8.lighting.fs")))

;; draw
(import (lib math))
(import (owl math fp))

; настройки
(glShadeModel GL_SMOOTH)
(glClearColor 0.2 0.2 0.2 1)

(glEnable GL_DEPTH_TEST)

; ambient RGBA intensity of the entire scene
(glLightModelfv GL_LIGHT_MODEL_AMBIENT '(0.1 0.1 0.1 1))

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
         'color [1 0 0]
         'position [
            (* 5 (sin (/ ticks 20)))
            (* 5 (cos (/ ticks 20)))
            4
            1]
      })))

   ; обновим текстурку 
   (define image (XGetImage dpy root SCREENW 0 SCREENW SCREENH (XAllPlanes) ZPixmap))
   (define data (bytevector->void* (vptr->bytevector image 100) 16))

   (glBindTexture GL_TEXTURE_2D computer-screen-texture)
   (glTexImage2D GL_TEXTURE_2D 0 GL_RGB SCREENW SCREENH 0 GL_BGRA GL_UNSIGNED_BYTE data)
   (XDestroyImage image)

   ; draw a scene
   (glUseProgram lighting)
   (glUniform1i (glGetUniformLocation lighting "lightsCount") (length lights))
   (glUniform1i (glGetUniformLocation lighting "tex") 0)

   ; define light positions
   ;(glEnable GL_LIGHTING)
   (for-each (lambda (light i)
         (glEnable i)
         ; GL_AMBIENT источника света не учавствует в освещении сцены
         (glLightfv i GL_DIFFUSE  (light 'color))
         (glLightfv i GL_SPECULAR (light 'color))
      ; GL_EMISSION
      ; GL_SHININESS
         (glLightfv i GL_POSITION (light 'position)))
      lights
      (iota (length lights) GL_LIGHT0))

   ; draw the geometry with colors
   (render-scene Objects geometry)

   ; Draw a light bulbs
   (draw-lightbulbs lights)

))
