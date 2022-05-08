#!/usr/bin/env ol

(import (lib gl-2))
(gl:set-window-title "create-kernel-texture.lisp")
(import (lib soil))

(define WIDTH 64)
(define HEIGHT 1)
(define accuracy 10000)

(import (otus random!))
(define (sign)
   (if (zero? (rand! 2)) +1 -1))

; let's create kernel vector table [-1..1 -1..1 0..1]
; TODO:
;; for (int i=0; i<samples; i++) {
;; 	rndTable[i] = vec3(kernel(-1, 1), kernel(-1, 1), kernel(-1, -0)); //равномерное распределение в полукубе (рисунок слева)
;; 	rndTable[i].normalize(); // делаем полусферу
;; 	rndTable[i] *= (i+1.0f)/samples; //нормальное распределение (рисунок справа)
;; }
(define data (fold (lambda (f i)
      (cons*
         (rand! 256)
         (rand! 256)
         (rand! 256)
         f))
   #null
   (iota (* WIDTH HEIGHT))))

(print data)
(define texture (SOIL_create_OGL_texture (cons (fft* fft-char) (reverse data)) WIDTH HEIGHT 3 SOIL_CREATE_NEW_ID 0))
(SOIL_save_image "kernel.tga" SOIL_SAVE_TYPE_TGA WIDTH HEIGHT 3 (cons (fft* fft-char) data))

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
