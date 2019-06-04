;; singleton.lisp
;;------------------------------------------------------------------------------
;;
;; Copyright (c) 2019 Sean Champ and others. All rights reserved.
;;
;; This program and the accompanying materials are made available under the
;; terms of the Eclipse Public License v1.0 which accompanies this distribution
;; and is available at http://www.eclipse.org/legal/epl-v10.html
;;
;; Contributors: Sean Champ - Initial Implementation
;;
;;------------------------------------------------------------------------------


(in-package #:cl-user)

(defpackage #:ltp/common/mop/singleton
  (:nicknames #:ltp.common.mop.singleton)
  (:use #:ltp/common/mop
        #:ltp/common
        #:cl))

(in-package #:ltp/common/mop/singleton)



(defclass singleton (standard-class)
  ())


(validate-class singleton)


(defclass singleton-slot-definition (standard-slot-definition)
  ;; TBD: SLOT-DEFINITION (??)
  ()
  (:default-initargs
   :allocation :class))


(defclass singleton-direct-slot-definition
    (singleton-slot-definition standard-direct-slot-definition)
  ;; NB: These will extend the standard MOP classes
  ;; though the allocation meta-slot will be by-in-large
  ;; unused here - assumed to be, in effect, always :CLASS
  ())


(defmethod direct-slot-definition-class ((class singleton)
                                         &rest initargs)
  (find-class 'singleton-direct-slot-definition))


(defclass singleton-effective-slot-definition
    (singleton-slot-definition standard-effective-slot-definition)
  ())


(defmethod effective-slot-definition-class ((class singleton)
                                            &rest initargs)
  (find-class 'singleton-effective-slot-definition))


;; MOP Interop ...

;; Applications TD
;; - Use for internal representation of "Application Personalities" in
;;   the Lisp Environment
;;
;; - Use for internal representation of ABIs

;; NB: Static dispatching w/ CLtL2+MOP standard methods


;; FIXME: Err for any singleton slot definition with
;; :allocation :instance specified during metaobject
;; initialization

#+nil
(eval-when ()

(defclass singleton-1 (singleton)
  ((sl-a)
   (sl-b))
  (:metaclass singleton))

(finalize-inheritance (find-class 'singleton-1))


(class-slots (find-class 'singleton-1))

(class-direct-slots (find-class 'singleton-1))



(defclass singleton-2 (singleton-1)
  ((sl-c))
  (:metaclass singleton))

(finalize-inheritance (find-class 'singleton-2))

(class-slots (find-class 'singleton-2))

(class-direct-slots (find-class 'singleton-2))


)
