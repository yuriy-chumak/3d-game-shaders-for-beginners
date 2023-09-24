#!/usr/bin/env ol

; initialize OpenGL
(import (lib gl-2))
(gl:set-window-title "ssao.lisp")
(import (lib soil))
(import (lib GLU))

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

; scene objects
(define Objects (vector->list (scene 'Objects)))
(print "Objects: " Objects)

; let's rotate ceilingFan
(attach-entity-handler "ceilingFan" (lambda (entity)
   (define-values (ss ms) (clock))
   (ff-replace entity {
      'rotation [0 0 (+ (mod (* ss 10) 360) (/ ms 100))]
   })))

;; render buffer
(import (OpenGL EXT framebuffer_object))

; texture buffer sizes
(define TEXW 1024)
(define TEXH 1024)

; depth texture2d
(define texture '(0))
(glGenTextures (length texture) texture)
(glBindTexture GL_TEXTURE_2D (car texture))
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S GL_REPEAT)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T GL_REPEAT)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER GL_NEAREST)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER GL_NEAREST)
   (glTexImage2D GL_TEXTURE_2D 0 GL_DEPTH_COMPONENT 1024 1024 0 GL_DEPTH_COMPONENT GL_FLOAT 0)
(glBindTexture GL_TEXTURE_2D 0)

; depthbuffer
(import (OpenGL EXT geometry_shader4))

(define depthbuffer '(0))
(glGenFramebuffers (length depthbuffer) depthbuffer)
(print "depthbuffer: " depthbuffer)
(glBindFramebuffer GL_FRAMEBUFFER (car depthbuffer))
   (glFramebufferTexture GL_FRAMEBUFFER GL_DEPTH_ATTACHMENT (car texture) 0)

   (glDrawBuffer GL_NONE)
   (glReadBuffer GL_NONE)
(glBindFramebuffer GL_FRAMEBUFFER 0)

; depths producer
(define depths (gl:create-program
"#version 120 // OpenGL 2.1
   #define gl_ModelMatrix gl_TextureMatrix[7]   // Model matrix
   #define gl_ViewMatrix gl_ModelViewMatrix
   #define gl_ViewProjectionMatrix gl_ModelViewProjectionMatrix

   uniform float clip_end;

   varying float depth;
   void main() {
      gl_Position = gl_ViewProjectionMatrix * gl_ModelMatrix * gl_Vertex;
      depth = gl_Position.z / clip_end;
   }"
"#version 120 // OpenGL 2.1
   varying float depth;
   void main() {
      gl_FragDepth = depth;
   }"))

(define ssao (gl:create-program
"#version 120 // OpenGL 2.1
   #define gl_ModelMatrix gl_TextureMatrix[7]   // Model matrix
   #define gl_ViewMatrix gl_ModelViewMatrix
   #define gl_ViewProjectionMatrix gl_ModelViewProjectionMatrix

   uniform float clip_end;

   varying float depth;
   varying vec3 normal;
   varying vec3 position;
   void main() {
      gl_Position = gl_ViewProjectionMatrix * gl_ModelMatrix * gl_Vertex;
      depth = gl_Position.z / clip_end;
      normal = mat3(gl_ModelMatrix) * gl_Normal; // или (gl_ViewMatrix * gl_ModelMatrix * vec4(gl_Normal, 0.0)).xyz ?
      position = (gl_ModelMatrix * gl_Vertex).xyz; // координата вертекса в мире

      gl_FrontColor = gl_Color;
   }"
"#version 120 // OpenGL 2.1
   #define gl_ViewProjectionMatrix gl_ModelViewProjectionMatrix
   // https://habr.com/ru/post/421385/
   uniform sampler2D depthMap;

   uniform sampler2D kernelMap; // ядро выборки, у нас 16 векторов
   uniform sampler2D rotateMap; // рандомные повороты
   uniform vec2 screen;
   uniform float clip_end;

   varying float depth;
   varying vec3 normal;
   varying vec3 position;
   void main() {
      // настройки
      float radius = 0.1; // переменные, контролирующие эффект
      float bias = 0.002;

      // текстурные координаты на пререндере глубины
      vec2 st = vec2(gl_FragCoord.x / screen.x, gl_FragCoord.y / screen.y);
      vec2 noiseScale = vec2(screen.x / 4, screen.y / 4); // 4x4 - размер текстуры поворота

      // 'рандомный' вектор плоскости отражения ядра выборки, использовать через reflect
      // можно и не использовать для начала, но сильно улучшает качество
      vec3 noise = normalize(texture2D(rotateMap, st * noiseScale).xyz * 2 - 1);

      float occlusion = 0.0;
      // мы будем отсекать примерно половину рандомных векторов (тех, которые разнонаправлены с нормалью)
      for (int i = 0; i < 64; i++) { // 64 is a kernel size
         vec3 kernel = texture2D(kernelMap, vec2(i/64.0, 0)).xyz * 2 - 1; // вектор на тестируемую точку

         // если рандомный вектор не противоположен нормали (не проваливает точку под поверхность)
         //if (dot(kernel, normal) >= 0) {
            vec3 sample = position + kernel * radius; // координаты тестируемой точки

            vec4 offset = vec4(sample, 1.0);
            offset      = gl_ViewProjectionMatrix * offset;
            offset.xy  /= offset.w;
            offset.xy   = offset.xy * 0.5 + 0.5;
            offset.z   /= clip_end;

            float sampleDepth = texture2D(depthMap, offset.xy).z;
            float rangeCheck = 0.1; //1.0 - smoothstep(0.0, 1.0, radius / abs(depth - sampleDepth));
            occlusion += (sampleDepth > offset.z - bias ? 1.0 : rangeCheck);
         //}
      }
      occlusion = (occlusion / 64); // 8 - половина от 16, так как приблизительно половину мы отсеем

      gl_FragColor = gl_Color * vec4(occlusion);
   }"))

(define rotate-array
   (SOIL_load_OGL_texture "media/rotate.tga" SOIL_LOAD_RGB SOIL_CREATE_NEW_ID 0))
(print "rotate-array: " rotate-array)
(glBindTexture GL_TEXTURE_2D rotate-array)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER GL_NEAREST)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER GL_NEAREST)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S GL_REPEAT)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T GL_REPEAT)
(glBindTexture GL_TEXTURE_2D 0)


(define kernel-array
   (SOIL_load_OGL_texture "media/kernel.tga" SOIL_LOAD_RGB SOIL_CREATE_NEW_ID 0))
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER GL_NEAREST)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER GL_NEAREST)
   ;; (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S GL_REPEAT)
   ;; (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T GL_REPEAT)
(print "kernel-array: " kernel-array)

; draw
(gl:set-renderer (lambda ()
   (glViewport 0 0 TEXW TEXH)
   (glBindFramebuffer GL_FRAMEBUFFER (car depthbuffer))

   (glClearColor 0 0 0 1)
   (glClear (vm:ior GL_COLOR_BUFFER_BIT GL_DEPTH_BUFFER_BIT))

   (glUseProgram depths)

   ; camera setup
   (begin
      (define Camera (ref (scene 'Cameras) 1))

      (glMatrixMode GL_PROJECTION)
      (glLoadIdentity)
      (gluPerspective
         (Camera 'angle)
         (/ (gl:get-window-width) (gl:get-window-height))
         (Camera 'clip_start) (Camera 'clip_end))

      (glUniform1f (glGetUniformLocation depths "clip_end") (Camera 'clip_end))

      (define target (vector->list (Camera 'target)))
      (define location (vector->list (Camera 'location)))
      (define up (vector->list [0 0 1]))

      (glMatrixMode GL_MODELVIEW)
      (glLoadIdentity)
      (apply gluLookAt (append location target up)))

   ; draw just a geometry
   (draw-geometry Objects geometry)

   ; -------------------------------------
   ; -- ssao -----------------------------
   ; --
   (glViewport 0 0 (gl:get-window-width) (gl:get-window-height))
   (glClearColor 0 0 0 1)

   (glBindFramebuffer GL_FRAMEBUFFER 0)
   (glClear (vm:ior GL_COLOR_BUFFER_BIT GL_DEPTH_BUFFER_BIT))

   (glUseProgram ssao)
   (glUniform2f (glGetUniformLocation ssao "screen") (gl:get-window-width)(gl:get-window-height))

   (glActiveTexture GL_TEXTURE2)
      (glUniform1i (glGetUniformLocation ssao "depthMap") 2)
      (glBindTexture GL_TEXTURE_2D (unbox texture))
   (glActiveTexture GL_TEXTURE3)
      (glUniform1i (glGetUniformLocation ssao "kernelMap") 3)
      (glBindTexture GL_TEXTURE_2D kernel-array)
   (glActiveTexture GL_TEXTURE4)
      (glUniform1i (glGetUniformLocation ssao "rotateMap") 4)
      (glBindTexture GL_TEXTURE_2D rotate-array)
   (glActiveTexture GL_TEXTURE0)

   ; camera setup
   (begin
      (define Camera (ref (scene 'Cameras) 1))

      (glMatrixMode GL_PROJECTION)
      (glLoadIdentity)
      (gluPerspective
         (Camera 'angle)
         (/ (gl:get-window-width) (gl:get-window-height))
         (Camera 'clip_start) (Camera 'clip_end))

      (glUniform1f (glGetUniformLocation depths "clip_end") (Camera 'clip_end))

      (define target (vector->list (Camera 'target)))
      (define location (vector->list (Camera 'location)))
      (define up (vector->list [0 0 1]))

      (glMatrixMode GL_MODELVIEW)
      (glLoadIdentity)
      (apply gluLookAt (append location target up)))

   ; draw just a geometry
   (render-scene Objects geometry)

   ;; ; ----------------------------------
   ;; ; Draw a result texture (normals)
   ;; (glBindFramebuffer GL_FRAMEBUFFER 0)
   ;; (glUseProgram 0)

   ;; (glViewport 0 0 (gl:get-window-width) (gl:get-window-height))
   ;; (glClearColor 0 0 0 1)
   ;; (glClear (vm:ior GL_COLOR_BUFFER_BIT GL_DEPTH_BUFFER_BIT))

   ;; (glMatrixMode GL_PROJECTION)
   ;; (glLoadIdentity)
   ;; (glMatrixMode GL_MODELVIEW)
   ;; (glLoadIdentity)
   ;; (glOrtho 0 1 0 1 0 1)

   ;; (glEnable GL_TEXTURE_2D)
   ;; (glActiveTexture GL_TEXTURE0)
   ;; (glBindTexture GL_TEXTURE_2D (car texture))

   ;; (glBegin GL_QUADS)
   ;;    (glColor3f 1 1 1)

   ;;    (glTexCoord2f 0 0)
   ;;    (glVertex2f 0 0)
   ;;    (glTexCoord2f 1 0)
   ;;    (glVertex2f 1 0)
   ;;    (glTexCoord2f 1 1)
   ;;    (glVertex2f 1 1)
   ;;    (glTexCoord2f 0 1)
   ;;    (glVertex2f 0 1)
   ;; (glEnd)

))
