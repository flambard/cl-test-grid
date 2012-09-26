;;;; -*- Mode: LISP; Syntax: COMMON-LISP; indent-tabs-mode: nil; coding: utf-8; show-trailing-whitespace: t -*-
;;;; Copyright (C) 2011 Anton Vodonosov (avodonosov@yandex.ru)
;;;; See LICENSE for details.

(in-package #:test-grid-reporting)


(defun fast-exclusive-or (list-1 list-2 &rest rest &key key (test #'eql) (test-not nil))
  "Exactly as CL:SET-EXCLUSIVE-OR, but takes advantage
of hash table if the :TEST predicate is suitable
for CL:MAKE-HASH-TABLE, i.e. one is a designator
designator of EQ, EQL, EQUAL or EQUALP. 

Otherwise, if :TEST is different predicate, or :TEST-NOT
is used, FAST-EXCLUSIVE-OR signals a warning and
falls back to CL:SET-EXCLUSIVE-OR.

Note, that CL:SET-EXCLUSIVE-OR takes minutes(!) on the
list sized we are interested in (tested on CCL and SBCL)."
  (when test-not
    (warn "FAST-EXCLUSIVE-OR falls back to CL:SET-EXCLUSIVE-OR because we don't know how to handle TEST-NOT")
    (return-from fast-exclusive-or (apply #'cl:set-exclusive-or list-1 list-2 rest)))
  (when (not (member test
                     `(eq eql equal equalp ,#'eq ,#'eql ,#'equal #'equalp)))
    (warn "FAST-EXCLUSIVE-OR falls back to CL:SET-EXCLUSIVE-OR because the TEST predicate is not a designator of EQ, EQL, EQUAL or EQUALP")
    (return-from fast-exclusive-or (apply #'cl:set-exclusive-or list-1 list-2 rest)))

  (unless key (setq key #'identity))
  (flet ((to-hash (list)
           (let ((hash (make-hash-table :test test)))
             (dolist (el list)
               (setf (gethash (funcall key el) hash) t))
             hash)))
    (let ((hash-1 (to-hash list-1))
          (hash-2 (to-hash list-2))
          result)
      (dolist (el-1 list-1)
        (when (not (gethash (funcall key el-1) hash-2))
          (push el-1 result)))
      (dolist (el-2 list-2)
        (when (not (gethash (funcall key el-2) hash-1))
          (push el-2 result)))
      result)))