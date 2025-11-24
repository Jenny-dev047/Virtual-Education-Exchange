;; education-exchange.clar
;; Virtual education exchange program connecting global students

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-registered (err u102))
(define-constant err-invalid-match (err u103))
(define-constant err-invalid-rating (err u104))
(define-constant err-invalid-status (err u105))
(define-constant err-unauthorized (err u106))
(define-constant err-already-inactive (err u107))
(define-constant err-invalid-grade (err u108))
(define-constant err-invalid-duration (err u109))