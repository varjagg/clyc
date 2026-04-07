#|
  Copyright (c) 2019-2026 White Flame

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

;; GTM = GT Method, top-level dispatch that looks up and calls a GT implementation function.
;; GTI = GT Internal, lower-level dispatch handling predicate vs accessor invocation modes.

;; TODO: with-new-gt-space — commented declareMacro, depends on unported
;; instantiate-sbhl-marking-space-for (sbhl_marking_vars.java).
;; Internal Constants evidence: $sym0$INSTANTIATE-SBHL-MARKING-SPACE-FOR, $sym1$*GT-MARKING-TABLE*
;; Likely expands to: (instantiate-sbhl-marking-space-for *gt-marking-table* &body body)
;; (defmacro with-new-gt-space (&body body) ...) -- commented declareMacro

;; Functions — following declare_transitivity_file() ordering

(defun gtm (predicate method &optional
            (arg1 *unprovided*) (arg2 *unprovided*) (arg3 *unprovided*)
            (arg4 *unprovided*) (arg5 *unprovided*))
  "[Cyc] Performs transitivity method METHOD using binary transitive predicate PREDICATE for designated args (see *gt-methods* for legal transitivity methods)."
  (let ((result nil)
        (mt-var (gt-mt-arg-value method arg1 arg2 arg3 arg4 arg5)))
    (let ((*mt* (update-inference-mt-relevance-mt mt-var))
          (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
          (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
      (if (or (transitive-predicate? predicate)
              *gt-handle-non-transitive-predicate?*)
          (let ((gti-function (gt-method-function method)))
            (when (function-spec-p gti-function)
              (let ((*gt-pred* predicate)
                    (*gt-index-arg* (ggt-index-arg predicate))
                    (*gt-gather-arg* (ggt-gather-arg predicate)))
                (if *gt-marking-table*
                    (setf result (apply-gti-function gti-function arg1 arg2 arg3 arg4 arg5))
                    (let ((*gt-marking-table* (get-sbhl-marking-space)))
                      (setf result (apply-gti-function gti-function arg1 arg2 arg3 arg4 arg5))
                      (free-sbhl-marking-space *gt-marking-table*))))))
          ;; missing-larkc 4004 — likely cerror about predicate not being transitive
          (missing-larkc 4004)))
    result))

;; (defun gtm-in-mt (predicate method mt &optional arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun gtm-in-all-mts (predicate method &optional arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun gti (predicate method &optional arg1 arg2 arg3 arg4 arg5) ...) -- no body, commented declareFunction
;; (defun gti-predicate (predicate index-arg gather-arg method arg1 arg2 arg3 arg4 arg5) ...) -- no body, commented declareFunction
;; (defun gti-accessors (accessors method arg1 arg2 arg3 arg4 arg5) ...) -- no body, commented declareFunction

;; TODO - all this stuff needs proper &optional handling
(defun apply-gti-function (gti-function arg1 arg2 arg3 arg4 arg5)
  (cond
    ((unprovided-argument? arg1) (funcall gti-function))
    ((unprovided-argument? arg2) (funcall gti-function arg1))
    ((unprovided-argument? arg3) (funcall gti-function arg1 arg2))
    ((unprovided-argument? arg4) (funcall gti-function arg1 arg2 arg3))
    ((unprovided-argument? arg5) (funcall gti-function arg1 arg2 arg3 arg4))
    (t (funcall gti-function arg1 arg2 arg3 arg4 arg5))))

;; (defun reset-gti-state () ...) -- no body, commented declareFunction

(defun gt-method-function (method)
  (let ((function (second (assoc method *gt-dispatch-table*))))
    (cond
      ((function-spec-p function) function)
      (function
       ;; missing-larkc 4005 — likely cerror about invalid module
       (missing-larkc 4005)
       nil)
      (t
       ;; missing-larkc 4006 — likely cerror about invalid method
       (missing-larkc 4006)
       nil))))

;; (defun gt-method-arg-list (method) ...) -- no body, commented declareFunction
;; (defun add-mt-default (method mt) ...) -- no body, commented declareFunction

(defun gt-mt-arg (method)
  (position 'mt (remove '&optional (third (assoc method *gt-dispatch-table*)))))

(defun gt-mt-arg-value (method &optional arg1 arg2 arg3 arg4 arg5)
  (let* ((mt nil)
         (pos (gt-mt-arg method)))
    (cond
      ((eql pos 0) (setf mt arg1))
      ((eql pos 1) (setf mt arg2))
      ((eql pos 2) (setf mt arg3))
      ((eql pos 3) (setf mt arg4))
      ((eql pos 4) (setf mt arg5)))
    (if (hlmt-p mt)
        mt
        nil)))

;; (defun gt-method? (method) ...) -- no body, commented declareFunction
;; (defun gt-module? (module) ...) -- no body, commented declareFunction
;; (defun gt-predicate (module) ...) -- no body, commented declareFunction
;; (defun gt-mt (module) ...) -- no body, commented declareFunction
;; (defun gt-index-arg (module) ...) -- no body, commented declareFunction
;; (defun gt-gather-arg (module) ...) -- no body, commented declareFunction

(defun ggt-index-arg (predicate)
  (let ((fan-out-arg (fan-out-arg predicate)))
    (or fan-out-arg *gt-index-arg*)))

(defun ggt-gather-arg (predicate)
  (if (= (ggt-index-arg predicate) 2) 1 2))

;; (defun gt-accessors (module) ...) -- no body, commented declareFunction
;; (defun setup-transitivity-module (predicate plist) ...) -- no body, commented declareFunction
