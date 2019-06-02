;; common-lambda.lisp
;;------------------------------------------------------------------------------
;;
;; Copyright (c) 2014-2019 Sean Champ and others. All rights reserved.
;;
;; This program and the accompanying materials are made available under the
;; terms of the Eclipse Public License v1.0 which accompanies this distribution
;; and is available at http://www.eclipse.org/legal/epl-v10.html
;;
;; Contributors: Sean Champ - Initial API and implementation
;;
;;------------------------------------------------------------------------------


(in-package #:ltp/common)

(defconstant* +declare-notype+
  ;; Untyped DECLARE specifiers
  ;;
  ;; These should be processed before any type declarations are parsed
  ;; from a DECLARE form
  '(dynamic-extent ignore optimize inline special ignorable notinline
    declaration))

#+NIL
(defconstant* +declare+
    ;; NB Not used in DEFUN*; provided for illustration
    (append '(type ftype) +declare-notype+))

(defconstant* +defun-lambda-param-kwd+
    ;; NB: This provides a more specialized set of symbols than
    ;; CL:LAMBDA-LIST-KEYWORDS
  '(&optional &rest &key &allow-other-keys))

(defconstant* +defun-lambda-kwd+
    (append +defun-lambda-param-kwd+
            '(&aux)))

(defvar *default-ftype-values* '(values t))

;; FIXME update the FTYPE routines for specialized &KEY args

(defmacro defun* (name lambda &rest forms &environment env)
  ;; TD: LABELS* - refer to remarks, below. "Test here"
  (macrolet ((pushl (v where)
                   `(setq ,where (nconc ,where (list ,v)))))
    (labels ((parse-docs (forms)
               (let ((frst (car forms)))
                 (cond
                   ((stringp frst)
                    (values (cdr forms) frst))
                   (t
                    (values forms nil)))))
             (parse-forms-declare (forms decls)
               ;; assumption: any docstring has been removed from forms
               ;;
               ;; NB: Handle multiple DECLARE
               (let ((frst (car forms)))
                 (cond
                   ((eq (car frst) 'declare)
                    (parse-forms-declare (cdr forms)
                                         (nconc decls
                                                (cdr frst))))
                   (t
                    (values forms decls)))))
             (parse-lambda-vars (llist)
               ;; NB: This function's return value is used for PARSE-FTYPE LVARS
               ;;
               ;; Usage - Within PARSE-FTYPE, this function's return
               ;; value is processed within an iterative form, such that
               ;; will compute a type for each lambda parameter parsed
               ;; out by PARSE-LAMBDA-VARS.
               ;;
               ;; For &key arguments, these two functions will utilize a
               ;; specific, list-based data structure:
               ;;   (CONTEXT . (VAR . KEYNAME))
               ;; juxtaposed to the data structure used for other lambda
               ;; list parameters:
               ;;   (CONTEXT . VAR)
               (let ((kwdpkg (find-package '#:keyword))
                     vars context)
                 (declare (type package kwdpkg)
                          (dynamic-extent kwdpkg))
                 (dolist (expr llist vars)
                   (etypecase expr
                     (symbol
                      (cond
                        ((find expr +defun-lambda-kwd+ :test #'eq)
                         (setq context expr))
                        ;; NB: All symbol type expressions not denoted
                        ;; in +DEFUN-LAMBDA-KWD+ will be parsed subsq.
                        ((eq context (quote &key))
                         (let ((key (intern (symbol-name expr)
                                            kwdpkg)))
                           (pushl (cons context (cons expr key))
                                  vars)))
                        (t (pushl (cons context expr) vars))))
                     (cons
                      ;; assumptions: EXPR is a CONS - thus denoting an
                      ;; &optional or &key parameter. These specifiers
                      ;; will include further information than a
                      ;; parameter name.
                      (let ((vexpr (car expr)))
                        (case context
                          (&optional
                           (pushl (cons context vexpr) vars))
                          (&key
                           (etypecase vexpr
                             (symbol
                              (let ((key (intern (symbol-name vexpr)
                                                 kwdpkg)))
                                (pushl (cons context (cons vexpr key))
                                       vars)))
                             (cons
                              ;; Specialized &key forms
                              (let ((key (car vexpr))
                                    (var (cadr vexpr)))
                                (pushl (cons context (cons var key))
                                       vars)))))
                          (&aux) ;; no-op
                          ;; FIXME: This style warning introduces NAME
                          ;; and LAMBDA from the calling lexical
                          ;; environment. As such, it introduces a
                          ;; concern with regards to porting this lambda
                          ;; list parser for both LABELS* and DEFUN*
                          ;;
                          ;; Note also, BOA lambda list forms in
                          ;; constructor specifications for DEFSTRUCT
                          (t (simple-style-warning
                              "~<Ignoring lambda list expression ~S ~S~>~
~< in DEFUN* ~S ~S~>" context vexpr name lambda)))
                        ))))))

             (parse-decl-types (decls env)
               ;; TBD: Return value for PARSE-FTYPE DECLS
               (let (typed
                     ;;; unused lambda parser parameters
                     ;; ftyped cldecl classed other
                     vdecl)

                 ;; NB: This does not need to provide a full, compiler-
                 ;; integrated defun (lambda) declarations parser. It
                 ;; must parse the declarations, to some extent, in
                 ;; order to determine which declarations denote types
                 ;; for bindings established per the defun lambda list.
                 ;;
                 ;; Subsequent functions may use this function's return
                 ;; value, for estalblishing type declarations for
                 ;; function parameters, such that would be visible from
                 ;; any calling lexical environment.
                 ;;
                 ;; Note that some ambiguity is possible, in the normal
                 ;; declarations syntax. This parser is a best effort for
                 ;; addressing such ambiguities as may pertain to typing of
                 ;; lambda list parameters.
                 (dolist (expr decls)
                   ;; sort each element of DECLS per declaration kind
                   (let ((kind (car expr)))
                     (cond
                       ((eq kind 'type)
                        (let ((type (cadr expr)))
                          ;; record the type for each explicitly typed
                          ;; variable
                          (dolist (var (cddr expr))
                            (pushl (cons var type) typed))))
                       ((eq kind 'values)
                        ;; Assumption: This EXPR denotes a CMUCL lambda
                        ;; VALUES declaration. This declaration may also
                        ;; be evaluated in SBCL.

                        ;; NB This does not warn about multiple VALUES
                        ;; declarations - would implicitly use the last
                        ;; VALUES decl.

                        ;; FIXME prune this VALUES EXPR from the set of
                        ;; output declarations, when not either of CMUCL
                        ;; or SBCL - thus avoiding some style warnings,
                        ;; in implementations assumed not to implement
                        ;; the VALUES declaration, per se.

                        ;; Note that this DEFUN* proposes to utilize
                        ;; the CMUCL (or SBCL) lambda VALUES declaration
                        ;; in producing a top-level FTYPE declaration -
                        ;; thus, supporting such a convention of strong
                        ;; typing, insofar as in FTYPE declarations,
                        ;; for all implementations.
                        ;;
                        ;; Implementation-specific optimizations would
                        ;; be beyond the scope of this comment
                        (setq vdecl expr))
                       ((eq kind 'ftype)
                        ;; NB a manner of a subset of TYPE decls
                        ;; Not per se used here (No-Op)
                        #+NIL (pushl expr ftyped)
                        )
                       ((find kind +declare-notype+ :test #'eq)
                        ;; No-Op
                        #+NIL
                        (pushl expr cldecl))
                       ((find-class kind nil env)
                        #+NIL (pushl expr classed)
                        #-NIL
                        (dolist (var (cdr expr))
                          (pushl (cons var kind) typed)
                          ))
                       (t ;; No-Op
                        #+NIL
                        (pushl expr other)))))
                 ;; NB: OTHER may contain non-class type-name and
                 ;; implementation-specific declarations
                 ;;
                 ;; FIXME: This, in its present revision, will not
                 ;; recognize any shorthand type declarations that do
                 ;; not represent class names.
                 ;;
                 ;; This revision of DEFUN* will not provide implementation-
                 ;; specific code.
                 ;;
                 ;; Assumption: Any declarations in OTHER will not provide
                 ;; type information about the LAMBDA list

                 ;; ...
                 (values typed vdecl)))
             (parse-ftype (name lvars type-map vdecl)
               (declare (type list type-map))
               ;; NB vis a vis VALUES in DECLARE w/ CMUCL and SBCL,
               ;; and CL:FTYPE declarations
               ;;
               ;; Parse any VALUES decls from the original DECLARE set.
               ;; Subsequently, use that value (when non-nil) in a
               ;; top-level FTYPE declaration - using a default type T
               ;; for the VALUES type and for any LAMBDA parameters
               ;; that have not been expressly typed in the DECLARE form.
               ;;
               ;; When adapted for LABELS* the FTYPE declaration must be
               ;; handled for a declaration within the calling lexical
               ;; environment, a non-null lexical environment.

               ;; NB To retain portability, this will implement some
               ;; assumptions about type specifiers in the DECLARE list

               ;; NB: The FTYPE declaration must match not only the names
               ;; of variables provided in the lambda list - insofar as to
               ;; specify a type for each parameter. Furthermore, the
               ;; FTYPE declaration must match the grammar of the provided
               ;; lambda list.
               ;;
               ;; Note that this is not for typing of all lexical
               ;; variables that the lambda-list may specify to the
               ;; defining function. It pertains only to functional
               ;; parameters that would be visible within the calling
               ;; lexical environment.

               ;; FIXME still need to parse out the non-standard VALUES decls
               ;;
               ;; ... b.c stong typing in Common Lisp programs, juxtaposed
               ;; to a casual DECLARATION decl in non-CMUCL-fam lisps
               (let (param-spec context)
                 ;; Re-map LVARS x TYPE-MAP into a lambda-like PARAM-SPEC
                 (dolist (bkt lvars)
                   ;; NB: for any &key parameter, the CDR of BKT will be
                   ;; a list -- as produced within PARSE-LAMBDA-VARS --
                   ;; to a general format: (CONTEXT . (VAR . KEYNAME))
                   ;;
                   ;; For any other lambda list parameter, the CDR of
                   ;; BKT should be a symbol, denoting a variable name
                   ;; within the specified lambda list context, CTXT
                   (destructuring-bind (ctxt . varinfo ) bkt
                     (unless (eq ctxt '&aux)
                       ;; FIXME/TBD: &AUX in FTYPE. Here, it's skipped simply
                       (unless (eq ctxt context)
                         (setq context ctxt)
                         (pushl ctxt param-spec))
                       (let* ((varname (etypecase varinfo
                                         (cons (car varinfo))
                                         (symbol varinfo)))
                              (type-n (position varname type-map
                                                :key #'car
                                                :test #'eq))
                              ;; FIXME: Parameterize this default type
                              (type t))
                         (when type-n
                           ;; else, initial type 'T' is used
                           (setq type (cdr (nth type-n type-map))))
                         (case ctxt
                           ;; (&rest)
                           ;; FIXME use a default type LIST for any &REST param
                           (&key
                            (let ((kwd (cdr varinfo)))
                              ;; Note the remark about "Specialized &key
                              ;; forms" in PARSE-LAMBDA-VARS local defun
                              (pushl (list kwd type) param-spec)))
                           (t
                            (pushl type param-spec))))
                       )))
                 ;; Provide a default value for VDECL
                 (unless vdecl
                   (setq vdecl *default-ftype-values*))
                 (values `(ftype (function ,param-spec ,vdecl) ,name))))

             (parse-meta (name llist forms)
               (let ((lvars (parse-lambda-vars llist)))
                 (multiple-value-bind (forms docs)
                     (parse-docs forms)
                   (multiple-value-bind (forms decls)
                       (parse-forms-declare forms nil)
                     (multiple-value-bind (type-map vdecl)
                         (parse-decl-types decls env)
                       (multiple-value-bind (ftype)
                           (parse-ftype name lvars type-map vdecl)
                         (values ftype docs decls forms))))))
               ))

      (multiple-value-bind (ftype docs decls forms)
          (parse-meta name lambda (copy-list forms))
        `(progn
           (declaim ,ftype)
           (defun ,name ,lambda
             ,@(when docs (list docs))
             ,@(when decls (list `(declare ,@decls)))
             ,@forms)
           )))))


#+NIL
(eval-when ()

(macroexpand (quote
(defun* frob+ (m n o)
  "Trivially Typed +"
  (declare (fixnum m) (type integer n o)
           (values integer &optional))
  (declare (dynamic-extent m n o))
  (+ m n o))
))

(frob+ 1 2 3)

(defun* frob* (m n &optional (o 1))
  "Trivially Typed *"
  (declare (fixnum m)
           (values integer &optional))
  (declare (type integer o)
           (dynamic-extent m n o))
  (* m n o))

(frob* 1 1)

(frob* 1 1 2)


(defun* frob- (m n &optional (o 1))
  "Trivially Typed -"
  (declare (fixnum m))
  (declare (dynamic-extent m n o)
           (type integer o))
  (- m n o))



(macroexpand (quote
(defun* find-frob (digit where &rest kwlist
                         &key ((:start %start) 0) from-end
                         &allow-other-keys &aux (c (digit-char digit)))
  "Find NIL"
  (declare (type (mod 10) digit) (string where)
           (ignore kwlist)
           (type (mod #.array-dimension-limit) %start))
  (let ((n
         (position c where :test #'char= :start %start
                   :from-end from-end)))
    (declare (type base-char c))
    (cond
      (n (values c n))
      (t (values nil nil )))))
))



;; (find-frob 1 "54321012345")
;; (find-frob 1 "54321012345" :from-end t)

)
