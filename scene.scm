(define-library (scene)
(import
   (otus lisp)
   (owl parse)
   (file wavefront obj)
   (file wavefront mtl)
   (otus blobs)
   (otus case-apply)
   (OpenGL version-2-1)
   (lib soil) (lib GLU))

(export
   prepare-models
   compile-triangles

   ;load-texures

   draw-geometry ; draw just a geometry
   draw-lightbulbs
   ; render scene with binded textures
   render-scene

   set-default-material-handler
   attach-material-handler
   material-handlers

   attach-entity-handler)
   
   ;; rotate)
(begin

   (define resources '(
      "resources/Ultimate Modular Sci-Fi - Feb 2021/OBJ"))

   (import (srfi 170)) ; folder functions
   (define filenames ; a list of used models from resources folder
      (fold (lambda (names resource)
               (define dir (open-directory resource))
               (let loop ((names names))
                  (define filename (read-directory dir))
                  (if filename
                     (loop (if (m/\.obj$/ filename) (cons (string-append resource "/" filename) names) names))
                  else
                     (close-directory dir)
                     names)))
         '()
         resources))

   (import (scheme dynamic-bindings))
   (define material-handlers (make-parameter {}))
   (define entity-handlers (make-parameter {}))

   ; загрузить нужные модели
   (define (prepare-models filename)
      (or ;load a precompiled models file or compile new one
         (fasl-load filename #false)
         (let ((models (fold (lambda (models filename)
                  (define obj-filename filename)
                  (print "Loading object file " obj-filename "...")
                  (define obj (parse wavefront-obj-parser (file->bytestream obj-filename) obj-filename #t #empty))
                  ; Load a materials
                  (define mtl-filename (s/\.obj/\.mtl/ filename)) ;; (obj 'mtllib "")
                  (print "Loading materials file " mtl-filename "...")
                  (define mtl (parse wavefront-mtl-parser (file->bytestream mtl-filename) mtl-filename #t #empty))

                  ; precompile
                  (define vertices (list->vector (obj 'v #null)))
                  (define normals (list->vector (obj 'vn #null)))
                  (define texcoords (list->vector (obj 'vt #null)))

                  (cons [
                        (map (lambda (material) ; materials
                              (vector
                                 (material 'name)
                                 (material 'kd)
                                 (material 'map_kd)))
                           mtl)
                        ; objects
                        (map (lambda (object)
                              (vector
                                 (object 'name)
                                 (object 'facegroups)))
                           (obj 'o))
                        vertices
                        normals
                        texcoords ]
                     models))
               '()
               filenames)))
            (fasl-save models filename)
            models)))

   ; generate default texture
   (define white '(0))
   (glGenTextures (length white) white)
   ;; (SOIL_load_OGL_texture "resources/Textures/white.png" SOIL_LOAD_RGBA (car white) 0)
   (glBindTexture GL_TEXTURE_2D (car white))
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S GL_REPEAT)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T GL_REPEAT)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER GL_NEAREST)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER GL_NEAREST)
   (glTexImage2D GL_TEXTURE_2D 0 GL_RGBA 1 1 0 GL_RGBA GL_FLOAT
      (cons
         (fft* fft-float)
         (list 1 1 1 1))) ; RGBA
   (glBindTexture GL_TEXTURE_2D 0)

   ; create materials ff
   ; name -> [name Kd map_Kd]
   (define (compile-materials models)
      (fold (lambda (materials model)
         (vector-apply model
            (lambda (mtl objects vertices normals texcoords)
               ; materials list -> materials ff
               (fold (lambda (ff material)
                        (put ff (ref material 1) material))
                  materials
                  (map (lambda (material)
                           (define map_kd (ref material 3))
                           (vector
                              (string->symbol (ref material 1))
                              (ref material 2)
                              (if map_kd
                                 (SOIL_load_OGL_texture map_kd SOIL_LOAD_RGBA SOIL_CREATE_NEW_ID 0) )))
                              ;else
                              ;   (car white))))
                     mtl)))))
         {}
         models))

   ; compile only geometry, without textures etc.
   (define (compile-triangles models)
      ; name -> [name Kd map_Kd]
      (define materials (compile-materials models))
      ; list of model-name -> compiled-geometry-ids in form [gl-list program-id]
      (define triangles
      (fold (lambda (models model)
               (vector-apply model
                  (lambda (mtl objects vertices normals texcoords)
                     (glActiveTexture GL_TEXTURE0) ; reset texture unit

                     ; compile and put all objects into dictionary
                     (fold (lambda (ff o)
                              (define name (ref o 1))
                              (define facegroups (ref o 2))
                              (define index (glGenLists (length facegroups)))

                              (print "compiling model " name "...")

                              (put ff (string->symbol name)
                                 (reverse
                                 (fold (lambda (o group i)
                                          (let*((mtl (car group))
                                                (material (materials (string->symbol mtl)))
                                                (texture (ref material 3)))
                                             (glNewList i GL_COMPILE)

                                             ; https://compgraphics.info/OpenGL/lighting/materials.php
                                             ;(glMaterialfv GL_FRONT_AND_BACK GL_AMBIENT_AND_DIFFUSE (ref material 2)) ; diffuse
                                             (glColor4fv (ref material 2))
                                             (if texture
                                                (glBindTexture GL_TEXTURE_2D texture))

                                             (glBegin GL_TRIANGLES)
                                             (for-each (lambda (faces)
                                                   (for-each (lambda (face)
                                                         (vector-apply face (lambda (xyz uv n)
                                                            (if uv
                                                               ; wavefront obj uv is [-1..+1], opengl uv - [0 .. +1]
                                                               (glTexCoord2fv (vector-map (lambda (x) (/ (+ x 1) 2))
                                                                                 (ref texcoords uv))))
                                                            (glNormal3fv (ref normals n))
                                                            (glVertex3fv (ref vertices xyz)) )))
                                                      faces))
                                                (cdr group))
                                             (glEnd)
                                             (glEndList)
                                             (cons (cons i material) o)))
                                       #null
                                       facegroups
                                       (iota (length facegroups) index)))))
                        models objects))))
         {}
         models))
      [materials triangles])

   ; ----------------------------
   (define quadric (gluNewQuadric))

   (define (draw-geometry objects geometry)
      (define models (ref geometry 2))

      (for-each (lambda (entity)
            (define name (entity 'name ""))
            (define object (((entity-handlers) (string->symbol name) idf) entity))

            (glActiveTexture GL_TEXTURE7) ; temporary buffer for matrix math
            (glMatrixMode GL_TEXTURE)
            (glLoadIdentity) ; let's prepare my_WorldMatrix
            ; transformations
            (let ((xyz (object 'location)))
               (glTranslatef (ref xyz 1) (ref xyz 2) (ref xyz 3)))
            ; blender rotation mode is "YPR": yaw, pitch, roll
            (let ((ypr (object 'rotation)))
               (glRotatef (ref ypr 3) 0 0 1)
               (glRotatef (ref ypr 2) 0 1 0)
               (glRotatef (ref ypr 1) 1 0 0))
            ; use program?
            ; reset texture unit to use with
            (glActiveTexture GL_TEXTURE0)
            ; draw compiled geometry
            (define model (object 'model))
            (for-each glCallList
               (map car (models (string->symbol model)))))
         objects))

   (define (render-scene objects geometry)
      (define models (ref geometry 2))
      (define handlers (material-handlers))

      (for-each (lambda (entity)
            (define name (entity 'name ""))
            (define object (((entity-handlers) (string->symbol name) idf) entity))

            (glActiveTexture GL_TEXTURE7) ; temporary buffer for matrix math
            (glMatrixMode GL_TEXTURE)
            (glLoadIdentity) ; let's prepare my_WorldMatrix
            ; transformations
            (let ((xyz (object 'location)))
               (glTranslatef (ref xyz 1) (ref xyz 2) (ref xyz 3)))
            ; blender rotation mode is "YPR": yaw, pitch, roll
            (let ((ypr (object 'rotation)))
               (glRotatef (ref ypr 3) 0 0 1)
               (glRotatef (ref ypr 2) 0 1 0)
               (glRotatef (ref ypr 1) 1 0 0))
            ; use program?
            ; reset texture unit to use with
            (glActiveTexture GL_TEXTURE0)
            (define model (object 'model))
            ; draw compiled geometry
            (for-each (lambda (item)
                  (define material (cdr item))
                  ; do material handler
                  (define handler
                     (handlers (ref material 1) (handlers #false (lambda (material)
                        #false)))) ; do nothing
                  (case-apply handler
                     (list 0)
                     (list 1 material)
                     (list 2 material object))

                  ; draw compiled geometry
                  (glCallList (car item)))
               (models (string->symbol model))))
         objects))

   ; Draw a light bulbs
   (define (draw-lightbulbs Lights)
      (glUseProgram 0)

      (glMatrixMode GL_MODELVIEW)
      (for-each (lambda (light i)
            ; show only "point" light sources
            (when (eq? (ref (light 'position) 4) 1)
               (glColor3fv (light 'color))
               (glPushMatrix)
               (glTranslatef (ref (light 'position) 1)
                             (ref (light 'position) 2)
                             (ref (light 'position) 3))
               (gluSphere quadric 0.2 8 8)
               (glPopMatrix)))
         Lights
         (iota (length Lights))))

   ;; (define (rotate model delta)
   ;;    ;; rotate ceilingFan
   ;;    (define rotation ((model) 'rotation))
   ;;    (model
   ;;       (put (model) 'rotation
   ;;          (let ((z (ref rotation 3)))
   ;;             (set-ref rotation 3 (+ z delta))))))

   ; materials
   (define (set-default-material-handler handler)
      (material-handlers (put (material-handlers) #false handler)))

   (define (attach-material-handler materials handler)
      (for-each (lambda (material)
            (define handlers (material-handlers))
            (material-handlers (put handlers (string->symbol material) handler)))
         (if (list? materials) materials (list materials))))

   (define (attach-entity-handler entity handler)
      (define handlers (entity-handlers))
      (entity-handlers (put handlers (string->symbol entity) handler)))
))
