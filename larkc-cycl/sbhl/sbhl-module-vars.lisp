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

;; [Clyc] Using :constructor make-sbhl-module-struct so we can define
;; the SubL plist-walking make-sbhl-module wrapper separately.
(defstruct (sbhl-module (:conc-name "SBHL-MOD-")
                        (:constructor make-sbhl-module-struct))
  link-pred
  accessible-link-preds
  graph
  link-style
  index-arg
  module-type
  type-test
  path-terminating-mark-fn
  marking-fn
  unmarking-fn
  var-bindings
  misc-properties)

;; [Clyc] Replaces Java register_method on $print_object_method_table$
;; and the sbhl-module-print-function-trampoline mechanism.
;; Print format from $str45 "#<SBHL-MODULE: " and $str46 ">".
(defmethod print-object ((obj sbhl-module) stream)
  (format stream "#<SBHL-MODULE: ~A>" (sbhl-mod-link-pred obj)))

;; (defun sbhl-mod-var-bindings (object) ...) -- commented declareFunction, no body

(defun make-sbhl-module (&optional arglist)
  "[Cyc] SubL plist-walking constructor for sbhl-module."
  (let ((v-new (make-sbhl-module-struct)))
    (loop for (key value) on arglist by #'cddr do
      (case key
        (:link-pred (setf (sbhl-mod-link-pred v-new) value))
        (:accessible-link-preds (setf (sbhl-mod-accessible-link-preds v-new) value))
        (:graph (setf (sbhl-mod-graph v-new) value))
        (:link-style (setf (sbhl-mod-link-style v-new) value))
        (:index-arg (setf (sbhl-mod-index-arg v-new) value))
        (:module-type (setf (sbhl-mod-module-type v-new) value))
        (:type-test (setf (sbhl-mod-type-test v-new) value))
        (:path-terminating-mark-fn (setf (sbhl-mod-path-terminating-mark-fn v-new) value))
        (:marking-fn (setf (sbhl-mod-marking-fn v-new) value))
        (:unmarking-fn (setf (sbhl-mod-unmarking-fn v-new) value))
        (:var-bindings (missing-larkc 2753))
        (:misc-properties (setf (sbhl-mod-misc-properties v-new) value))
        (otherwise (error "Invalid slot ~S for construction function" key))))
    v-new))

;; (defun print-sbhl-module (object stream depth) ...) -- commented declareFunction, no body

(defun new-sbhl-module (pred)
  (declare (type (satisfies fort-p) pred))
  (let ((module (make-sbhl-module)))
    (setf (sbhl-mod-link-pred module) pred)
    (setf (sbhl-mod-misc-properties module) (make-hash-table :test #'eq))
    module))

(defun set-sbhl-module-property (module property value)
  (sbhl-check-type property sbhl-module-property-p)
  (sbhl-check-type module sbhl-module-p)
  (case property
    (:link-pred (setf (sbhl-mod-link-pred module) value))
    (:accessible-link-preds (setf (sbhl-mod-accessible-link-preds module) value))
    (:graph (setf (sbhl-mod-graph module) value))
    (:link-style (setf (sbhl-mod-link-style module) value))
    (:index-arg (setf (sbhl-mod-index-arg module) value))
    (:module-type (setf (sbhl-mod-module-type module) value))
    (:type-test (setf (sbhl-mod-type-test module) value))
    (:path-terminating-mark?-fn (setf (sbhl-mod-path-terminating-mark-fn module) value))
    (:marking-fn (setf (sbhl-mod-marking-fn module) value))
    (:unmarking-fn (setf (sbhl-mod-unmarking-fn module) value))
    (otherwise (setf (gethash property (sbhl-mod-misc-properties module)) value)))
  module)

(defun get-sbhl-module-property (module property)
  (sbhl-check-type module sbhl-module-p)
  (case property
    (:link-pred (sbhl-mod-link-pred module))
    (:accessible-link-preds (sbhl-mod-accessible-link-preds module))
    (:graph (sbhl-mod-graph module))
    (:link-style (sbhl-mod-link-style module))
    (:index-arg (sbhl-mod-index-arg module))
    (:module-type (sbhl-mod-module-type module))
    (:type-test (sbhl-mod-type-test module))
    (:path-terminating-mark?-fn (sbhl-mod-path-terminating-mark-fn module))
    (:marking-fn (sbhl-mod-marking-fn module))
    (:unmarking-fn (sbhl-mod-unmarking-fn module))
    (otherwise (gethash property (sbhl-mod-misc-properties module)))))

(defun get-sbhl-module-link-pred (module)
  "[Cyc] Accessor."
  (declare (type sbhl-module module))
  (sbhl-mod-link-pred module))

(defun get-sbhl-module-accessible-link-preds (module)
  "[Cyc] Accessor."
  (declare (type sbhl-module module))
  (sbhl-mod-accessible-link-preds module))

(defun get-sbhl-module-graph (module)
  "[Cyc] Accessor."
  (declare (type sbhl-module module))
  (sbhl-mod-graph module))

(defun get-sbhl-module-link-style (module)
  "[Cyc] Accessor."
  (declare (type sbhl-module module))
  (sbhl-mod-link-style module))

(defun get-sbhl-module-index-arg (module)
  "[Cyc] Accessor."
  (declare (type sbhl-module module))
  (sbhl-mod-index-arg module))

(defun get-sbhl-module-module-type (module)
  "[Cyc] Accessor."
  (declare (type sbhl-module module))
  (sbhl-mod-module-type module))

(defun get-sbhl-module-type-test (module)
  "[Cyc] Accessor."
  (declare (type sbhl-module module))
  (sbhl-mod-type-test module))

(defun get-sbhl-module-path-terminating-mark (module)
  "[Cyc] Accessor."
  (declare (type sbhl-module module))
  (sbhl-mod-path-terminating-mark-fn module))

(defun get-sbhl-module-marking-fn (module)
  "[Cyc] Accessor."
  (declare (type sbhl-module module))
  (sbhl-mod-marking-fn module))

(defun get-sbhl-module-unmarking-fn (module)
  "[Cyc] Accessor."
  (declare (type sbhl-module module))
  (sbhl-mod-unmarking-fn module))

(defun sbhl-module-object-p (object)
  "[Cyc] Whether OBJECT is a dictionary-p."
  (sbhl-module-p object))

(deflexical *sbhl-module-key-test* #'eq)

(defglobal *sbhl-modules* (make-hash-table :test *sbhl-module-key-test*)
  "[Cyc] Dictionary of SBHL modules, built up by module declaration.")

(defun reset-sbhl-modules ()
  (setf *sbhl-modules* (make-hash-table :test *sbhl-module-key-test*))
  nil)

;; (defun rebuild-sbhl-modules () ...) -- commented declareFunction, no body

(defun get-sbhl-modules ()
  "[Cyc] Return a hashtable of the defined SBHL modules, which each correspond directly to a link table."
  *sbhl-modules*)

(defun add-sbhl-module (predicate module)
  "[Cyc] Enters MODULE into *SBHL-MODULES*. Assumes *SBHL-MODULES* is a hashtable. Checks that MODULE-KEY is a fort-p, and MODULE_DATA is a hashtable-p."
  (sbhl-check-type predicate sbhl-predicate-object-p)
  (sbhl-check-type module sbhl-module-object-p)
  (setf (gethash predicate *sbhl-modules*) module)
  (clear-get-sbhl-predicates)
  nil)

;; (defun remove-sbhl-module (predicate) ...) -- commented declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list59 = ((MODULE-VAR &OPTIONAL DONE-VAR) &BODY BODY)
;; $sym60$KEY = gensym "KEY"
;; $sym61$DO-DICTIONARY → dohash (dictionaries elided to hash tables)
;; $list62 = (GET-SBHL-MODULES)
;; $sym63$IGNORE
(defmacro do-sbhl-modules ((module-var &optional done-var) &body body)
  (declare (ignore done-var))
  (with-temp-vars (key)
    `(dohash (,key ,module-var (get-sbhl-modules))
       (declare (ignore ,key))
       ,@body)))

(defun get-sbhl-predicates-int ()
  "[Cyc] Returns a list of the defined sbhl predicates."
  (hash-table-keys (get-sbhl-modules)))

(defun get-sbhl-module-list ()
  "[Cyc] Return what the SBHL module structures that the predicates point to."
  (hash-table-values (get-sbhl-modules)))

(defun sbhl-predicate-object-p (object)
  "[Cyc] Type test for candidate sbhl-predicates."
  (fort-p object))

(deflexical *sbhl-module-types* '(:simple-reflexive
                                  :simple-non-reflexive
                                  :transfers-through
                                  :disjoins
                                  :time)
  "[Cyc] Roles that SBHL modules play in the grand SBHL scheme.")

(defun sbhl-simple-reflexive-module-type-p (module-type)
  "[Cyc] Returns whether MODULE-TYPE is of the simple transitive and reflexive variety."
  (eq module-type :simple-reflexive))

(defun sbhl-simple-non-reflexive-module-type-p (module-type)
  "[Cyc] Returns whether MODULE-TYPE is of the simple transitive but irreflexive variety."
  (eq module-type :simple-non-reflexive))

(defun sbhl-transfers-through-module-type-p (module-type)
  "[Cyc] Returns whether MODULE-TYPE is the keyword for transfers-through sbhl modules."
  (eq module-type :transfers-through))

(defun sbhl-disjoins-module-type-p (module-type)
  "[Cyc] Returns whether MODULE-TYPE is the keyword for disjoins sbhl modules."
  (eq module-type :disjoins))

(defun sbhl-time-module-type-p (module-type)
  "[Cyc] Returns whether MODULE-TYPE is the keyword for sbhl time modules."
  (eq module-type :time))

(defun sbhl-transitive-module-type-p (module-type)
  "[Cyc] Returns whether MODULE-TYPE is the keyword for simple sbhl modules, or for sbhl time modules."
  (case module-type
    ((:simple-reflexive :simple-non-reflexive :time) t)))

;; (defun sbhl-module-type-p (module-type) ...) -- commented declareFunction, no body

;; Reconstructed from Internal Constants:
;; $sym70$MODULE = gensym "MODULE"
;; $sym71$DO-SBHL-MODULES, $sym72$PWHEN → when
;; $sym73$SBHL-SIMPLE-MODULE-P
;; $sym74$CLET → let, $sym75$GET-SBHL-LINK-PRED
(defmacro do-sbhl-simple-modules ((pred-var &optional done-var) &body body)
  (with-temp-vars (module)
    `(do-sbhl-modules (,module ,done-var)
       (when (sbhl-simple-module-p ,module)
         (let ((,pred-var (get-sbhl-link-pred ,module)))
           ,@body)))))

;; Reconstructed from Internal Constants:
;; $sym76$MODULE = gensym "MODULE"
;; $sym77$SBHL-TIME-MODULE-P
;; Reuses DO-SBHL-MODULES, PWHEN → when from above
(defmacro do-sbhl-time-modules ((module-var &optional done-var) &body body)
  (with-temp-vars (module)
    `(do-sbhl-modules (,module ,done-var)
       (when (sbhl-time-module-p ,module)
         (let ((,module-var ,module))
           ,@body)))))

;; Reconstructed from Internal Constants:
;; $list78 = ((PRED-VAR &OPTIONAL DONE-VAR) &BODY BODY)
;; $sym79$MODULE = gensym "MODULE"
;; $sym77$SBHL-TIME-MODULE-P
;; Reuses DO-SBHL-MODULES, PWHEN → when, CLET → let, GET-SBHL-LINK-PRED
(defmacro do-sbhl-time-predicates ((pred-var &optional done-var) &body body)
  (with-temp-vars (module)
    `(do-sbhl-modules (,module ,done-var)
       (when (sbhl-time-module-p ,module)
         (let ((,pred-var (get-sbhl-link-pred ,module)))
           ,@body)))))

(defglobal *sbhl-module-properties* (make-hash-table :test #'eq)
  "[Cyc] The list of properties available for each of the *SBHL-MODULES*. Each key is a keyword. Each value field should be a functionp, corresponding for the test function for the sbhl module property associated with the key.")

(defun init-sbhl-module-properties (property-list)
  "[Cyc] Modifier. Used to store initial values for the *SBHL-MODULE-PROPERTIES*."
  (dolist (property-test-pair property-list)
    (setf (gethash (first property-test-pair) *sbhl-module-properties*)
          (second property-test-pair)))
  nil)

;; (defun get-sbhl-module-properties () ...) -- commented declareFunction, no body
;; (defun add-sbhl-module-property (property test) ...) -- commented declareFunction, no body

(defun sbhl-module-property-p (property)
  "[Cyc] Returns whether PROPERTY is a member of *SBHL-MODULE-PROPERTIES*."
  (gethash property *sbhl-module-properties*))

;; TODO - do-sbhl-module-properties: commented declareMacro
;; Evidence: $list105 = ((PROPERTY-VAR TEST-VAR &OPTIONAL DONE-VAR) &BODY BODY)
;; $list106 = (GET-SBHL-MODULE-PROPERTIES) — references commented-out function
;; Would iterate *sbhl-module-properties* via do-dictionary → dohash

(deflexical *sbhl-module-required-properties* (list :link-pred
                                                    :link-style
                                                    :module-type
                                                    :path-terminating-mark?-fn
                                                    :marking-fn
                                                    :unmarking-fn
                                                    :index-arg
                                                    :graph)
  "[Cyc] The list of required properties for each of the *SBHL-MODULES*.")

;; (defun get-sbhl-module-required-properties () ...) -- commented declareFunction, no body
;; (defun sbhl-module-required-property-p (property) ...) -- commented declareFunction, no body

;; TODO - do-sbhl-module-required-properties: commented declareMacro
;; Evidence: $list108 = ((PROPERTY-VAR &OPTIONAL DONE-VAR) &BODY BODY)
;; $sym109$SMART-CSOME, $list110 = (GET-SBHL-MODULE-REQUIRED-PROPERTIES)
;; References commented-out function and undefined smart-csome

(defparameter *sbhl-module* nil
  "[Cyc] The current sbhl-module in use for link traversal.")

(defvar *sbhl-module-vars* nil
  "[Cyc] The parameters bound with each SBHL module.")

(defun get-sbhl-module (&optional predicate)
  "[Cyc] Return the SBHL module for PREDICATE. Defaults to *SBHL-MODULE*."
  (cond
    ((not predicate) *sbhl-module*)
    ((and (sbhl-module-p *sbhl-module*)
          (eq predicate (get-sbhl-link-pred *sbhl-module*)))
     *sbhl-module*)
    (t (let ((module (gethash predicate (get-sbhl-modules))))
         (or module
             (sbhl-warn 0 "~A is not a valid sbhl-predicate-p" predicate))))))

;; Reconstructed from Internal Constants:
;; $list112 = (MODULE &BODY BODY)
;; $sym113$*SBHL-MODULE*
(defmacro with-sbhl-module ((module) &body body)
  `(let ((*sbhl-module* ,module))
     ,@body))

;; Reconstructed from Internal Constants:
;; $sym114$FIF, $list115 = (*SBHL-MODULE*)
;; If module is non-nil use it, otherwise keep current *sbhl-module*
(defmacro possibly-with-sbhl-module ((module) &body body)
  `(let ((*sbhl-module* (fif ,module ,module *sbhl-module*)))
     ,@body))

(deflexical *fort-denoting-sbhl-directed-graph* #$DirectedMultigraph
  "[Cyc] The fort which is used to determine whether a predicate has directed links.")
(deflexical *fort-denoting-sbhl-undirected-graph* #$Multigraph
  "[Cyc] The fort which is used to determine whether a predicate has undirected links.")

(defun fort-denotes-sbhl-directed-graph-p (fort)
  "[Cyc] Whether FORT indicates a directed or undirected graph."
  (cond
    ((eq fort *fort-denoting-sbhl-directed-graph*) t)
    ((eq fort *fort-denoting-sbhl-undirected-graph*) nil)
    (t (sbhl-error 1 "Term, ~a, is not used to specify directed nor undirected graphs." fort)
       nil)))

;; (defun sbhl-link-style-specifier-p (object) ...) -- commented declareFunction, no body

(defparameter *assume-sbhl-extensions-nonempty* t
  "[Cyc] Assumption made for a collection, predicate, etc. that has no known extent.
The two possible values are T (assume nonempty) and NIL (assume nothing).")

(defun clean-sbhl-modules ()
  (dohash (key module (get-sbhl-modules))
    (declare (ignore key))
    (let ((predicate (get-sbhl-link-pred module)))
      (unless (valid-fort? predicate)
        (missing-larkc 2755))))
  (optimize-sbhl-modules)
  nil)

(defparameter *sbhl-module-link-pred-preference-order* nil)

(defun optimize-sbhl-modules ()
  "[Cyc] Optimize SBHL modules for access."
  ;; [Clyc] Java calls dictionary-optimize which sorts alist-backed dictionaries
  ;; by a predicate. Since dictionaries are elided to hash tables, and hash table
  ;; optimization was missing-larkc, this binding is the only effect.
  (let ((*sbhl-module-link-pred-preference-order* (sbhl-module-link-pred-preference-order)))
    (declare (ignorable *sbhl-module-link-pred-preference-order*))
    nil))

(defun sbhl-modules-link-pred-< (pred1 pred2)
  (position-< pred1 pred2 *sbhl-module-link-pred-preference-order* #'eq))

(defun sbhl-module-link-pred-preference-order ()
  (let ((tuples nil))
    (dohash (key module (get-sbhl-modules))
      (declare (ignore key))
      (let* ((link-pred (get-sbhl-link-pred module))
             (graph (get-sbhl-module-graph module))
             (graph-size (hash-table-size graph)))
        (push (list link-pred graph-size) tuples)))
    (setf tuples (stable-sort tuples #'> :key #'second))
    (let ((link-preds (nmapcar #'first tuples)))
      (setf link-preds (cons #$genls (delete #$genls link-preds)))
      link-preds)))

;;; Toplevel setup forms

(toplevel (declare-defglobal '*sbhl-modules*))
(toplevel (declare-defglobal '*sbhl-module-properties*))

(toplevel
 (init-sbhl-module-properties
  (list (list :link-pred 'sbhl-predicate-object-p)
        (list :link-style 'sbhl-link-style-specifier-p)
        (list :naut-forward-true-generators 'function-symbol-list-p)
        (list :module-type 'sbhl-module-type-p)
        (list :type-test 'function-symbol-p)
        (list :module-inverts-arguments 'sbhl-module-or-predicate-p)
        (list :inverts-arguments-of-module 'sbhl-module-or-predicate-p)
        (list :disjoins-module 'sbhl-module-or-predicate-p)
        (list :path-terminating-mark?-fn 'function-symbol-p)
        (list :marking-fn 'function-symbol-p)
        (list :unmarking-fn 'function-symbol-p)
        (list :marking-increment 'integerp)
        (list :accessible-link-preds 'listp)
        (list :transfers-through-module 'sbhl-module-or-predicate-p)
        (list :transfers-via-arg 'integerp)
        (list :add-node-to-result-test 'function-symbol-p)
        (list :add-unmarked-node-to-result-test 'function-symbol-p)
        (list :predicate-search-p 'booleanp)
        (list :module-tag 'keywordp)
        (list :index-arg 'integerp)
        (list :root 'sbhl-node-object-p)
        (list :graph 'hash-table-p)
        (list :sbhl-marking-parameters 'listp))))

(toplevel (note-funcall-helper-function 'sbhl-modules-link-pred-<))
