(define-library (scene)
   (license MIT/LGPL3)
   (keywords (otus ol
      3d-game-shaders-for-beginners OpenGL))

   (export
      render-scene
   )

   (import
      (scheme base)
      (OpenGL 3.0))

(begin
   (setq vref vector-ref)

   (define render-scene
      (define (render-scene scene test)
         ; model shortcuts
         (define nodes (scene 'nodes))
         (define meshes (scene 'meshes))
         (define bufferViews (scene 'bufferViews))
         (define accessors (scene 'accessors))
         (define materials (scene 'materials))
         (define images (scene 'images))

         ; current shader program
         (define program (let ((id '(0)))
            (glGetIntegerv GL_CURRENT_PROGRAM id)
            (car id)))

         ; render scene tree
         (let walk ((i 0))
            (define node (vref nodes i))
            (glPushMatrix)
            (when (node 'matrix #f)
               (glMultMatrixf (node 'matrix)))

            (when (node 'mesh #f)
               (define mesh (vref meshes (node 'mesh)))
               (vector-for-each (lambda (primitive)
                     (glBindVertexArray (primitive 'vao))

                     (define indices (primitive 'indices #f))
                     (when indices
                        (define accessor (vref accessors indices))
                        (define bufferView (vref bufferViews (accessor 'bufferView)))

                        (define materialId (primitive 'material #f))
                        (when materialId
                           (define material (vref materials materialId))

                           ; let's pass material filter
                           (when (test material)
                              (define pbr (material 'pbrMetallicRoughness #f))
                              (when pbr
                                 ; ok, we will draw this primitive
                                 (define color (pbr 'baseColorFactor #f))
                                 (when color
                                    (glColor4fv color))

                                 (define colorTexture (pbr 'baseColorTexture #f))
                                 (when colorTexture
                                    (define index (colorTexture 'index))
                                    (define image (vref images index))
                                    (when image
                                       (glBindTexture GL_TEXTURE_2D (image 'texture)))) )

                              (define alphaCutoff (material 'alphaCutoff #f))
                              (when alphaCutoff
                                 (glUniform1f (glGetUniformLocation program "alphaCutoff") alphaCutoff))

                              ; finally, render!
                              (glBindBuffer GL_ELEMENT_ARRAY_BUFFER (bufferView 'vbo))
                              (glDrawElements
                                 (case (mesh 'mode 4)
                                    (0 GL_POINTS)
                                    (1 GL_LINES)
                                    (2 GL_LINE_LOOP)
                                    (3 GL_LINE_STRIP)
                                    (4 GL_TRIANGLES)
                                    (5 GL_TRIANGLE_STRIP)
                                    (6 GL_TRIANGLE_FAN))
                                 (accessor 'count)
                                 (accessor 'componentType)
                                 (accessor 'byteOffset 0)) )))

                     (glBindVertexArray 0))
                  (mesh 'primitives [])))
            ; visit children
            (vector-for-each walk (node 'children []))
            (glPopMatrix)))
      (case-lambda
         ((scene) (render-scene scene idf))
         ((scene test) (render-scene scene test))))

))