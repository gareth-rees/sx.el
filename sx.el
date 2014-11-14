;;; sx.el --- core functions                         -*- lexical-binding: t; -*-

;; Copyright (C) 2014  Sean Allred

;; Author: Sean Allred <code@seanallred.com>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This file defines basic commands used by all other parts of
;; StackMode.

;;; Code:


;;; Utility Functions

(defun sx-message (format-string &rest args)
  "Display a message"
  (message "[stack] %s" (apply #'format format-string args)))

(defun sx--thing-as-string (thing &optional sequence-sep)
  "Return a string representation of THING.  If THING is already
a string, just return it."
  (cond
   ((stringp thing) thing)
   ((symbolp thing) (symbol-name thing))
   ((numberp thing) (number-to-string thing))
   ((sequencep thing)
    (mapconcat #'sx--thing-as-string
               thing (if sequence-sep sequence-sep ";")))))

(defun sx--filter-data (data desired-tree)
  "Filters DATA and returns the DESIRED-TREE"
  (if (vectorp data)
      (apply #'vector
             (mapcar (lambda (entry)
                       (sx--filter-data
                        entry desired-tree))
                     data))
    (delq
     nil
     (mapcar (lambda (cons-cell)
               ;; TODO the resolution of `f' is O(2n) in the worst
               ;; case.  It may be faster to implement the same
               ;; functionality as a `while' loop to stop looking the
               ;; list once it has found a match.  Do speed tests.
               ;; See edfab4443ec3d376c31a38bef12d305838d3fa2e.
               (let ((f (or (memq (car cons-cell) desired-tree)
                            (assoc (car cons-cell) desired-tree))))
                 (when f
                   (if (and (sequencep (cdr cons-cell))
                            (sequencep (elt (cdr cons-cell) 0)))
                       (cons (car cons-cell)
                             (sx--filter-data
                              (cdr cons-cell) (cdr f)))
                     cons-cell))))
             data))))


;;; Interpreting request data
(defun sx--deep-dot-search (data)
  "Find symbols somewhere inside DATA which start with a `.'.
Returns a list where each element is a cons cell. The car is the
symbol, the cdr is the symbol without the `.'."
  (cond
   ((symbolp data)
    (let ((name (symbol-name data)))
      (when (string-match "\\`\\." name)
        ;; Return the cons cell inside a list, so it can be appended
        ;; with other results in the clause below.
        (list (cons data (intern (replace-match "" nil nil name)))))))
   ((not (listp data)) nil)
   (t (apply
       #'append
       (remove nil (mapcar #'sx--deep-dot-search data))))))

(defmacro sx-assoc-let (alist &rest body)
  "Execute BODY while let-binding dotted symbols to their values in ALIST.
Dotted symbol is any symbol starting with a `.'. Only those
present in BODY are letbound, which leads to optimal performance.

For instance the following code

  (stack-core-with-data alist
    (list .title .body))

is equivalent to

  (let ((.title (cdr (assoc 'title alist)))
        (.body (cdr (assoc 'body alist))))
    (list .title .body))"
  (declare (indent 1)
           (debug t))
  (let ((symbol-alist (sx--deep-dot-search body)))
    `(let ,(mapcar (lambda (x) `(,(car x) (cdr (assoc ',(cdr x) ,alist))))
                   symbol-alist)
       ,@body)))

(defcustom sx-init-hook nil
  "Hook run when stack-mode initializes.

Run after `sx-init--internal-hook'.")

(defvar sx-init--internal-hook nil
  "Hook run when stack-mode initializes.

This is used internally to set initial values for variables such
as filters.")

(defmacro sx-init-variable (variable value &optional setter)
  "Set VARIABLE to VALUE using SETTER.
SETTER should be a function of two arguments.  If SETTER is nil,
`set' is used."
  (eval
   `(add-hook
     'sx-init--internal-hook
     (lambda ()
       (,(or setter #'setq) ,variable ,value))))
  nil)

(defun stack-initialize ()
  (run-hooks
   'sx-init--internal-hook
   'sx-init-hook))

(provide 'sx)
;;; sx.el ends here

;; Local Variables:
;; indent-tabs-mode: nil
;; End: