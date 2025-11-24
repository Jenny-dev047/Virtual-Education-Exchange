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

;; Data variables
(define-data-var student-counter uint u0)
(define-data-var match-counter uint u0)
(define-data-var program-active bool true)
(define-data-var min-grade-level uint u1)
(define-data-var max-grade-level uint u12)
(define-data-var total-hours uint u0)

;; Data maps
(define-map student-profiles
    { student: principal }
    {
        country: (string-ascii 50),
        interests: (string-ascii 100),
        grade-level: uint,
        active: bool,
        matches-completed: uint,
        total-hours: uint,
        registration-date: uint
    }
)

(define-map exchange-matches
    { match-id: uint }
    {
        student-one: principal,
        student-two: principal,
        topic: (string-ascii 100),
        status: (string-ascii 20),
        created-at: uint,
        completed-at: uint,
        duration-hours: uint
    }
)

(define-map match-feedback
    { match-id: uint, student: principal }
    { rating: uint, feedback-given: bool, comment: (string-ascii 200) }
)

(define-map student-achievements
    { student: principal, achievement-type: (string-ascii 50) }
    { earned: bool, earned-at: uint }
)

(define-map blocked-students
    { student: principal, blocked: principal }
    { blocked: bool }
)

;; Register student profile
;; #[allow(unchecked_data)]
(define-public (register-student (country (string-ascii 50)) (interests (string-ascii 100)) (grade-level uint))
    (begin
        (asserts! (is-none (map-get? student-profiles { student: tx-sender })) err-already-registered)
        (asserts! (and (>= grade-level (var-get min-grade-level)) (<= grade-level (var-get max-grade-level))) err-invalid-grade)
        (map-set student-profiles
            { student: tx-sender }
            {
                country: country,
                interests: interests,
                grade-level: grade-level,
                active: true,
                matches-completed: u0,
                total-hours: u0,
                registration-date: stacks-block-height
            }
        )
        (var-set student-counter (+ (var-get student-counter) u1))
        (ok true)
    )
)

;; Update student profile
;; #[allow(unchecked_data)]
(define-public (update-profile (country (string-ascii 50)) (interests (string-ascii 100)) (grade-level uint))
    (let
        (
            (profile (unwrap! (map-get? student-profiles { student: tx-sender }) err-not-found))
        )
        (asserts! (and (>= grade-level (var-get min-grade-level)) (<= grade-level (var-get max-grade-level))) err-invalid-grade)
        (map-set student-profiles
            { student: tx-sender }
            (merge profile { country: country, interests: interests, grade-level: grade-level })
        )
        (ok true)
    )
)

;; Deactivate student profile
(define-public (deactivate-profile)
    (let
        (
            (profile (unwrap! (map-get? student-profiles { student: tx-sender }) err-not-found))
        )
        (asserts! (get active profile) err-already-inactive)
        (map-set student-profiles
            { student: tx-sender }
            (merge profile { active: false })
        )
        (ok true)
    )
)

;; Reactivate student profile
(define-public (reactivate-profile)
    (let
        (
            (profile (unwrap! (map-get? student-profiles { student: tx-sender }) err-not-found))
        )
        (asserts! (not (get active profile)) err-invalid-status)
        (map-set student-profiles
            { student: tx-sender }
            (merge profile { active: true })
        )
        (ok true)
    )
)