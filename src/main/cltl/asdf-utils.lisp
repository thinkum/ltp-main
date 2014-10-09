

;; depends-on : condition-utils

(in-package #:utils)


(deftype component-designator ()
  '(or string symbol component))

;;; * Component Condition Types

(define-condition component-condition ()
  ((component
    :initarg :component
    :accessor component-condition-component)))

(define-condition component-location-condition ()
  ((location
    :initarg :location
    :accessor component-location-condition-location)))

(define-condition component-not-found (program-error
				       component-condition
				       component-location-condition)
  ()
  (:report
   (lambda (c s)
     (format s "Location ~S does not contain a component ~S"
	     (component-location-condition-location c)
	     (component-condition-component c)))))

;; (error 'component-not-found :component "FOO" :location "BAR")

(define-condition system-not-found (program-error
				    component-condition
				    component-location-condition)
  ()
  (:default-initargs :location asdf::*source-registry*)
  (:report
   (lambda (c s)
     (format s "Source registry ~S does not contain a system ~S"
	     (component-location-condition-location c)
	     (component-condition-component c)))))


;;; * Interfaces onto ASDF Component Search
(macrolet ((frob-c (component location errp)
	     (with-gensym (%c %comp %loc %ep)
	       `(let* ((,%comp ,component)
		       (,%loc ,location)
		       (,%ep ,errp)
		       (,%c  (find-component ,%loc ,%comp)))
		  (cond
		    (,%c (values ,%c))
		    (,%ep (error 'component-not-found
				 :location ,%loc
				 :component ,%comp))
		    (t (values nil)))))))

  (defgeneric find-component* (component location &optional errorp)
    ;; NOTE: The order of arguments in this function
    ;; differs substantially from that in ASDF:FIND-COMPONENT

    (:method (component (path cons) &optional (errorp t))
      (frob-c component path errorp))

    (:method (component (location module) &optional (errorp t))
      (frob-c component location errorp))

    (:method (component (location string) &optional (errorp t))
      (let ((sys (find-component* location nil errorp)))
	(when sys 
	  (frob-c component sys errorp))))

    (:method (system (location null) &optional (errorp t))
      (let ((s (find-system system nil)))
	(cond
	  (s (values s))
	  (errorp (error 'system-not-found :component system))
	  (t (values nil)))))))

;;; Test forms

;; (find-component* '#:foobarquux nil)
;;
;; (find-component* "asdf-utils" "info.metacommunity.cltl.utils")
;;
;; (find-component* "line" '("garnet-bitmaps" "garnetdraw"))



(defun find-system* (name &optional (errorp t))
  (declare (type component-designator name)
	   (values (or component null)))
  (values (find-component* name nil errorp)))

;; (find-system* "mcclim")


