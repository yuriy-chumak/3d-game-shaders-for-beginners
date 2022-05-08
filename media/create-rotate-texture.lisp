#!/usr/bin/env ol

(import (lib gl-2))
(gl:set-window-title "create-rotate-texture.lisp")
(import (lib soil))

(define WIDTH 4)
(define HEIGHT 4)
(define accuracy 10000)

(import (otus random!))
(define (sign)
   (if (zero? (rand! 2)) +1 -1))

(define (byte x)
   (floor (exact (* 255 (/ (+ x 1) 2)))))

(define data (fold (lambda (f i)
      (define x (/ (inexact (rand! accuracy)) accuracy)) ; 0..1
      (define x2 (* (sign) x x)) ; -1 .. 1
      (define y (/ (inexact (rand! accuracy)) accuracy)) ; 0..1
      (define y2 (* (sign) y y)) ; -1 .. 1
      (define z (/ (inexact (rand! accuracy)) accuracy)) ; 0..1
      (define z2 (*        z z))
      (cons*
         (byte x2)
         (byte y2)
         0
         f))
   #null
   (iota (* WIDTH HEIGHT))))
(print data)
(define texture (SOIL_create_OGL_texture (cons (fft* fft-char) data) WIDTH HEIGHT 3 SOIL_CREATE_NEW_ID 0))
(SOIL_save_image "rotate.tga" SOIL_SAVE_TYPE_TGA WIDTH HEIGHT 3 (cons (fft* fft-char) data))

(gl:set-renderer (lambda ()
   (glClearColor 0 0 0 1)
   (glClear (vm:ior GL_COLOR_BUFFER_BIT GL_DEPTH_BUFFER_BIT))

   (glMatrixMode GL_PROJECTION)
   (glLoadIdentity)
   (glMatrixMode GL_MODELVIEW)
   (glLoadIdentity)
   (glOrtho 0 1 0 1 0 1)

   (glEnable GL_TEXTURE_2D)
   (glActiveTexture GL_TEXTURE0)
   (glBindTexture GL_TEXTURE_2D texture)

   (glBegin GL_QUADS)
      (glColor3f 1 1 1)

      (glTexCoord2f 0 0)
      (glVertex2f 0 0)
      (glTexCoord2f 1 0)
      (glVertex2f 1 0)
      (glTexCoord2f 1 1)
      (glVertex2f 1 1)
      (glTexCoord2f 0 1)
      (glVertex2f 0 1)
   (glEnd)
))
