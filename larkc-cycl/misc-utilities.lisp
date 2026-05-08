#|
  Copyright (c) 2019 White Flame

  This file is part of Clyc
 
  Clyc is free software: you can redistribute it and/or modify
  it under the terms of the GNU Affero General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
 
  Clyc is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU Affero General Public License for more details.
 
  You should have received a copy of the GNU Affero General Public License
  along with Clyc.  If not, see <https://www.gnu.org/licenses/>.
 
This file derives from work covered by the following copyright
and permission notice:

  Copyright (c) 1995-2009 Cycorp Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
  
  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
|#





(in-package :clyc)


;; TODO DESIGN - it makes more sense for loaded code to register its initializers, than to have to bake in all these calls here.



;; Apparently this is a reference boilerplate notice that Cycorp
;; might apply to various KBs it distributes. It is not referenced
;; anywhere in the LarKC source code or KB files, and is not applied
;; as a notice to anything in LarKC. Even if it were, LarKC does
;; have a "specific license agreement" with Cycorp to distribute
;; this version of Cyc under the Apache License 2.0, which has been
;; publicly distributed.

;; (defun copyright-notice () ...) -- active declareFunction, no body
;; (defun kb-content-copyright-notice () ...) -- active declareFunction, no body
;; (defun write-kb-content-copyright-notice (stream) ...) -- active declareFunction, no body

(defconstant *kb-content-copyright-notice* ";; Copyright (c) 1998-2009 Cycorp, Inc., All Rights Reserved
;; This file and its contents are products of Cycorp, Inc.  They are
;; released only under specific license agreement with Cycorp, and
;; must be treated as Cycorp Confidential Information, as per that
;; license agreement, including translation into another langauge
;; (including but not limited to Conceptual Graphs, KIF, Ontolingua,
;; GFP, LOOM, PowerLOOM, CycL, C, C++, IDL, predicate logic, and
;; English) and any logically equivalent rearrangement or renaming of
;; assertion components, terms, or variables.  This paragraph shall
;; not be altered or removed. This file is provided \"AS IS\", without
;; any warranty; the cumulative liability of Cycorp for all claims
;; relating to this file shall not exceed the amount of one dollar.
;; Cycorp, 7718 Wood Hollow Drive, Suite 250, Austin, TX 78731, USA
;; Website: www.cyc.com, Tel: (512) 342-4000.")

(defglobal *system-code-initializations-marker* (get-process-id))

(defun system-code-initializations (&optional (perform-app-specific-initializations? t))
  "[Cyc] Initializations which should be run every time the system code is initialized."
  (initialize-cyc-product)
  (system-code-image-initializations)
  (system-code-hl-initializations)
  (system-code-inference-initializations)
  (system-code-api-initializations)
  (when perform-app-specific-initializations?
    (system-code-application-initializations))
  (if (positive-integer-p (kb-loaded))
      (system-kb-initializations)
      ;; [Clyc] Uncommented from original — was commented out in Java, but seems sensible
      (warn "No KB is loaded.  System KB initializations will not be run."))
  (setf *system-code-initializations-marker* (get-process-id))
  t)

;; (defun system-code-initializations-run-p () ...) -- active declareFunction, no body
;; (defun redo-system-code-initializations () ...) -- active declareFunction, no body

(defun system-code-image-initializations ()
  "[Cyc] System code initializations that have to do with distinguishing the current image from the image that saved out the world being used."
  (seed-random)
  (reset-cycl-start-time)
  (set-cyc-image-id)
  (clear-machine-bogomips)
  (validate-all-tcp-servers)
  (clear-active-os-processes)
  t)

(defun system-code-hl-initializations ()
  "[Cyc] System code initializations that have to do with HL level reasoning."
  (disable-hlmts)
  (initialize-sbhl-modules)
  t)

(defun system-code-inference-initializations ()
  "[Cyc] System code initializations that have to do with inference."
  (reclassify-removal-modules)
  (reclassify-hl-storage-modules)
  (destroy-all-problem-stores)
  (initialize-pad-table "hack!")
  t)

(defun system-code-api-initializations ()
  "[Cyc] System code initializations that have to do with the Cyc API."
  ;; TODO - pretty sure we don't have a Java API here in Clyc
  (reset-java-api-kernel)
  t)

(defun system-code-application-initializations ()
  "[Cyc] System code initializations for application code built into Cyc.
To be called only by SYSTEM-CODE-INITIALIZATIONS."
  (clear-asked-query-queue)
  t)

(defun system-kb-initializations ()
  "[Cyc] Initializations which should be run every time the system is initialized, if there is a KB present."
  (initialize-hl-store-caches)
  (set-the-cyclist *default-cyclist-name*)
  (initialize-transcript-handling)
  (initialize-agenda)
  (initialize-global-locks)
  (perform-cyc-testing-initializations)
  (initialize-kct)
  (bt:make-thread #'initialize-all-file-backed-caches :name "file-backed cache initializer")
  (sleep 0.5)
  t)

;; (defun initialize-file-backed-nl-datastructures () ...) -- active declareFunction, no body

(defglobal *hl-store-caches-directory* nil
    "[Cyc] @HACK Currently, dump directory from which this KB was built; soon a published KB product subdirectory.")
(defglobal *hl-store-caches-shared-symbols* nil
    "[Cyc] The symbols all KB products share.")

(defun get-hl-store-caches-shared-symbols ()
  *hl-store-caches-shared-symbols*)

(defun initialize-hl-store-caches ()
  (unless (hl-store-content-completely-cached?)
    (initialize-hl-store-caches-from-directory (hl-store-caches-directory))))

(defun initialize-hl-store-caches-from-directory (dirname &optional symbols)
  (if (initialize-hl-store-cache-directory-and-shared-symbols dirname symbols)
      (progn
        (initialize-deduction-hl-store-cache)
        (initialize-assertion-hl-store-cache)
        (initialize-constant-index-hl-store-cache)
        (initialize-nart-index-hl-store-cache)
        (initialize-nart-hl-formula-hl-store-cache)
        (initialize-unrepresented-term-index-hl-store-cache)
        (initialize-kb-hl-support-hl-store-cache)
        (initialize-sbhl-graph-caches)
        (reconnect-tva-cache-registry dirname (get-hl-store-caches-shared-symbols)))
      (warn "Cannot initialize HL KB object caches."))
  t)

(defun initialize-hl-store-cache-directory-and-shared-symbols (dirname &optional symbols)
  (if (directory-p dirname)
      (set-hl-store-caches-directory dirname)
      (warn "Do not have a valid location for the HL store caches; ~a is not accessible" dirname))
  (if (directory-p (hl-store-caches-directory))
      (progn
        (initialize-hl-store-cache-shared-symbols symbols)
        t)
      (warn "Could not initialize HL store caches from ~a." dirname)))

(defun initialize-hl-store-cache-shared-symbols (symbols)
  (unless symbols
    (on-error (setf symbols (load-kb-product-shared-symbols (hl-store-caches-directory)))
      (warn "Could not initialize shared symbols from ~a." (hl-store-caches-directory))))
  (when symbols
    (setf *hl-store-caches-shared-symbols* symbols)))

(defun hl-store-content-completely-cached? ()
  (and (deduction-content-completely-cached?)
       (missing-larkc 32188)
       (missing-larkc 32199)
       (missing-larkc 32148)
       (missing-larkc 32198)
       (missing-larkc 2251)))

(defun get-hl-store-cache-filename (filename extension)
  (concatenate 'string *hl-store-caches-directory* filename "." extension))

(defun set-hl-store-caches-directory (directory)
  (when (absolute-path? directory)
    (warn "HL Store directory being set to absolute directory ~a.  Saved worlds will depend on this directory and may have problems running on other machines." directory))
  (setf *hl-store-caches-directory* directory)
  nil)

;; (defun generic-caches-directory () ...) -- active declareFunction, no body

(defun hl-store-caches-directory ()
  (or (and (stringp *hl-store-caches-directory*) *hl-store-caches-directory*)
      (progn
        (unless (force-monolithic-kb-assumption?)
          (set-hl-store-caches-directory (missing-larkc 30777)))
        *hl-store-caches-directory*)))

;; (defun compute-hl-store-caches-directory () ...) -- active declareFunction, no body

;; (defun cdr-eql? (x y) ...) -- active declareFunction, no body
;; (defun not-member-equal (item list) ...) -- active declareFunction, no body
;; (defun get-indexed-obj (index obj &optional default) ...) -- active declareFunction, no body
;; (defun update-vector-indexed-val (vector index value old-value new-value &optional test key default not-found) ...) -- active declareFunction, no body
;; (defun get-vector-indexed-val (vector index value key &optional test default) ...) -- active declareFunction, no body
;; (defun clear-indexed-vectors (vectors) ...) -- active declareFunction, no body
;; (defun make-indexed-vector (size &optional initial-element) ...) -- active declareFunction, no body
;; (defun vector-cells-filled (vector) ...) -- active declareFunction, no body
;; (defun extract-until (string char &optional start) ...) -- active declareFunction, no body
;; (defun extract-until-any (string chars &optional start) ...) -- active declareFunction, no body
;; (defun number-list (list) ...) -- active declareFunction, no body
;; (defun aconsnew (key datum alist &optional test key-fn) ...) -- active declareFunction, no body
;; (defun print-n-per-line (list n &optional stream) ...) -- active declareFunction, no body

(defun other-binary-arg (arg)
  ;; TODO - can be really optimized to just (logxor arg 3), but not sure this is used in any inner loops, and that would skip most error checking
  (case arg
    (1 2)
    (2 1)))

;; (defun number-of-non-null-args (&optional a b c d e) ...) -- active declareFunction, no body
;; (defun boolean-to-keyword (bool) ...) -- active declareFunction, no body
;; (defun keyword-to-boolean (keyword) ...) -- active declareFunction, no body
;; (defun get-unqualified-machine-name () ...) -- active declareFunction, no body

(deflexical *hostname-caching-state* nil)

;; (defun clear-hostname () ...) -- active declareFunction, no body
;; (defun remove-hostname () ...) -- active declareFunction, no body
;; (defun hostname-internal () ...) -- active declareFunction, no body
;; (defun hostname () ...) -- active declareFunction, no body; note-globally-cached-function in setup
;; (defun machine-name () ...) -- active declareFunction, no body
;; (defun function-spec-function (spec) ...) -- active declareFunction, no body

(deflexical *machine-bogomips* :uninitialized)

(defun machine-bogomips ()
  "[Cyc] Return the processor speed of this machine in bogomips, or NIL if this can't be determined."
  (when (eq :uninitialized *machine-bogomips*)
    (setf *machine-bogomips* (compute-machine-bogomips)))
  *machine-bogomips*)

(defun clear-machine-bogomips ()
  (setf *machine-bogomips* :uninitialized))

(defun compute-machine-bogomips ()
  (ignore-errors
    (with-open-file (stream "/proc/cpuinfo" :direction :input)
      ;; TODO - infinite loop if "bogomips" not found
      (loop for line = (read-line stream)
         when (search "bogomips" line)
         return (read-from-string (subseq line (1+ (search ":" line))))))))

(defun scale-by-bogomips (numbers bogomips)
  "[Cyc] Multiplies each number in NUMBERS by BOGOMIPS/(machine-bogomips).
If this machine is faster than BOGOMIPS, NUMBERS will get smaller.
If this machine is slower than BOGOMIPS, NUMBERS will get bigger.
If (machine-bogomips) is unknown, returns NUMBERS unscaled."
  (let ((local-bogomips (machine-bogomips)))
    (if (or (null local-bogomips)
            (= local-bogomips bogomips))
        numbers
        (let ((scaling-factor (/ bogomips local-bogomips)))
          (mapcar (lambda (number) (* scaling-factor number)) numbers)))))

(defun* uninitialized () (:inline t)
  :uninitialized)

(defun* uninitialized-p (object) (:inline t)
  (eq object (uninitialized)))

(defun* initialized-p (object) (:inline t)
  (not (uninitialized-p object)))

;; Reconstructed from Internal Constants:
;; $list55 = (FORM FORMAT-STRING &REST ARGUMENTS)
;; $sym56$PUNLESS, $sym57$WARN
(defmacro warn-unless (form format-string &rest arguments)
  `(unless ,form (warn ,format-string ,@arguments)))

;; TODO - active declareMacro, no Internal Constants evidence found for reconstruction
;; (defmacro would-be-nice-if (...) ...)

;; (defun force-room (&optional verbose) ...) -- active declareFunction, no body
;; (defun subl-variable-binding-list-p (object) ...) -- active declareFunction, no body
;; (defun subl-variable-binding-p (object) ...) -- active declareFunction, no body
;; (defun subl-variable-binding-list-variables (list) ...) -- active declareFunction, no body
;; (defun subl-variable-binding-list-values (list) ...) -- active declareFunction, no body

(toplevel
  (declare-defglobal '*system-code-initializations-marker*)
  (register-external-symbol 'system-code-initializations-run-p)
  (declare-defglobal '*hl-store-caches-directory*)
  (declare-defglobal '*hl-store-caches-shared-symbols*)
  (note-globally-cached-function 'hostname))
