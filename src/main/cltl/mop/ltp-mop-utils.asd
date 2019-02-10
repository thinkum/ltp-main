;; ltp-mop-utils.asd                                                -*- lisp -*-
;;------------------------------------------------------------------------------
;;
;; Copyright (c) 2014-2017 Sean Champ and others. All rights reserved.
;;
;; This program and the accompanying materials are made available under the
;; terms of the Eclipse Public License v1.0 which accompanies this distribution
;; and is available at http://www.eclipse.org/legal/epl-v10.html
;; 
;; Contributors: Sean Champ - Initial Implementation
;;
;;------------------------------------------------------------------------------

(in-package #:cl-user)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defpackage #:ltp-utils-system
    ;; note package reuse - package ltp-utils-system
    (:use #:asdf #:cl)))

(in-package #:ltp-utils-system)


(defsystem #:ltp-mop-utils
  ;; :description ""
  :version "1.0"
  ;;  :homepage "https://github.com/MetaCommunity/mci-cltl-utils"
  ;;  :license "https://github.com/MetaCommunity/mci-cltl-utils/blob/master/LICENSE"
  :depends-on (#:ltp-utils
               #:closer-mop
               #+LTP_PROTOTYPES #:bordeaux-threads
               )
  :components 
  ((:file "ltp-mop-utils-package") ;; c2mop integration
   (:file "mop-utils" ;; validate-[super]class (convenience macro)
          :depends-on ("ltp-mop-utils-package"))

   #+LTP_PROTOTYPES
   (:file "aclass"
          :depends-on ("mop-utils"))
   ))
