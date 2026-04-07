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

(defun compute-supports-tv (supports &optional (truth :true))
  (destructuring-bind (first-support &rest rest-supports) supports
    (let ((strength (support-strength first-support)))
      (cdolist (rest-support rest-supports)
        (setf strength (strength-combine strength (support-strength rest-support))))
      (tv-from-truth-strength truth strength))))

;; (defun compute-deduction-tv (deduction) ...) -- active declareFunction, no body
;; Orphan constants suggest it used DEDUCTION-P checkType and error string
;; "~s attempted to change its truth from ~s to ~s"

(defun compute-assertion-tv (assertion)
  (declare (type (satisfies assertion-p) assertion))
  (let* ((v-arguments (assertion-arguments assertion))
         (old-tv (cyc-assertion-tv assertion))
         (new-tv (perform-argumentation v-arguments)))
    (when (not (eq old-tv new-tv))
      (kb-set-assertion-truth assertion (tv-truth new-tv))
      (kb-set-assertion-strength assertion (tv-strength new-tv))
      (possibly-update-sbhl-links-tv assertion old-tv))
    new-tv))

(defun strength-combine (strength1 strength2)
  (cond ((or (eq strength1 :unknown)
             (eq strength2 :unknown))
         :unknown)
        ((or (eq strength1 :default)
             (eq strength2 :default))
         :default)
        (t :monotonic)))

(defun perform-argumentation (v-arguments)
  "[Cyc] @return tv-p"
  (declare (type (satisfies non-dotted-list-p) v-arguments))
  (cdolist (elem v-arguments)
    (check-type elem (satisfies argument-p)))
  (cond ((null v-arguments)
         :unknown)
        ((= (length v-arguments) 1)
         (argument-tv (first v-arguments)))
        (t
         (let ((tv (argument-tv (first v-arguments)))
               (done nil))
           (when (null done)
             (csome (argument (rest v-arguments) done)
               (setf done (not (eq tv (argument-tv argument))))))
           (when (null done)
             (return-from perform-argumentation tv)))
         (cond ((and (member? :true-mon v-arguments #'eql #'argument-tv)
                     (member :false-mon v-arguments :test #'eql :key #'argument-tv))
                ;; Likely resolves monotonic contradiction — both TRUE-MON and FALSE-MON present
                (missing-larkc 35548))
               ((member? :true-mon v-arguments #'eql #'argument-tv)
                :true-mon)
               ((member? :false-mon v-arguments #'eql #'argument-tv)
                :false-mon)
               (t
                (let ((asserted-argument (find-if #'asserted-argument-p v-arguments)))
                  (when asserted-argument
                    (return-from perform-argumentation (argument-tv asserted-argument))))
                (cond ((and (member? :true-def v-arguments #'eql #'argument-tv)
                            (member :false-def v-arguments :test #'eql :key #'argument-tv))
                       ;; Likely resolves default contradiction — both TRUE-DEF and FALSE-DEF present
                       (missing-larkc 35547))
                      ((member? :true-def v-arguments #'eql #'argument-tv)
                       :true-def)
                      ((member? :false-def v-arguments #'eql #'argument-tv)
                       :false-def)
                      (t :unknown)))))))

;; (defun complex-argumentation (v-arguments) ...) -- active declareFunction, no body
;; (defun resolve-contradiction (v-arguments) ...) -- active declareFunction, no body
;; (defun tms-deduction-spec-p (object) ...) -- active declareFunction, no body
;; (defun tms-deduction-spec-tv (tms-deduction-spec) ...) -- active declareFunction, no body
;; (defun perform-tms-deduction-spec-argumentation (tms-deduction-specs) ...) -- active declareFunction, no body

(defvar *tms-treat-monotonic-contradiction-as-unknown?* nil
  "[Cyc] When non-nil, monotonic contradictions during argumentation are simply treated as :UNKNOWN rather than erroring.")
