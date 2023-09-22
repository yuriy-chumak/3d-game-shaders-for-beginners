#!/usr/bin/env ol

; initialize OpenGL
(import (lib gl-1))
(gl:set-window-title "reference-frames.lisp")

(import (scheme inexact))
(import (lib GLU))

; global GL init
(glEnable GL_DEPTH_TEST)
(glEnable GL_CULL_FACE)
(glShadeModel GL_SMOOTH)

; scene
(import (scene))

; load (and create if no one) a models cache
(define models (prepare-models "cache.bin"))
(define geometry (compile-triangles models))

; ------------------------------------------
; load a scene
(import (file json))
(define scene (read-json-file "scene.json"))

; scene lights
(define Lights (vector->list (scene 'Lights)))
(print "Lights:")
(for-each (lambda (x) (print "   " x)) Lights)

; scene objects
(define Objects
   (vector->list (scene 'Objects)))

; lights init
(glEnable GL_COLOR_MATERIAL)
(glLightModelfv GL_LIGHT_MODEL_AMBIENT '(0.1 0.1 0.1 1))

(glPolygonMode GL_FRONT_AND_BACK GL_FILL)
(define quadric (gluNewQuadric))

; draw
(gl:set-renderer (lambda ()
   (glClearColor 0.1 0.1 0.1 1)
   (glClear (vm:ior GL_COLOR_BUFFER_BIT GL_DEPTH_BUFFER_BIT))

   ; let's add one dynamic light
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

   ; lights
   (glEnable GL_LIGHTING)
   (for-each (lambda (light i)
         (glEnable (+ GL_LIGHT0 i))
         (glLightfv (+ GL_LIGHT0 i) GL_POSITION (light 'position)))
      lights
      (iota (length lights)))

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
   ; (glEnable GL_TEXTURE_2D) ; no textures in our scene (yet)
   (define models (ref geometry 2))
   (for-each (lambda (object)
         (define model (object 'model))

         (define location (object 'location))
         ; let's rotate ceilingFan
         (define rotation (if (string-eq? (object 'name "") "ceilingFan")
            (let*((ss ms (clock)))
               [0 0 (+ (mod (* ss 10) 360) (/ ms 100))])
            (object 'rotation)))

         (glMatrixMode GL_MODELVIEW)
         (glPushMatrix)
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
            (map car (models (string->symbol model))))
         (glPopMatrix))
      Objects)

   ; Draw a light bulbs
   (glMatrixMode GL_MODELVIEW)
   (glDisable GL_LIGHTING)
   (for-each (lambda (light i)
         ; show only "point" light sources
         (when (eq? (ref (light 'position) 4) 1)
            (glColor3fv (light 'color))
            (glPushMatrix)
            (glTranslatef (ref (light 'position) 1)
                          (ref (light 'position) 2)
                          (ref (light 'position) 3))
            (gluSphere quadric 0.2 32 10)
            (glPopMatrix)))
      lights
      (iota (length lights)))
))
