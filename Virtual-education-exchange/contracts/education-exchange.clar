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

;; Create exchange match
;; #[allow(unchecked_data)]
(define-public (create-match (student-two principal) (topic (string-ascii 100)))
    (let
        (
            (new-id (+ (var-get match-counter) u1))
            (profile-one (unwrap! (map-get? student-profiles { student: tx-sender }) err-not-found))
            (profile-two (unwrap! (map-get? student-profiles { student: student-two }) err-not-found))
        )
        (asserts! (var-get program-active) err-invalid-status)
        (asserts! (get active profile-one) err-invalid-match)
        (asserts! (get active profile-two) err-invalid-match)
        (asserts! (is-none (map-get? blocked-students { student: tx-sender, blocked: student-two })) err-unauthorized)
        (map-set exchange-matches
            { match-id: new-id }
            {
                student-one: tx-sender,
                student-two: student-two,
                topic: topic,
                status: "active",
                created-at: stacks-block-height,
                completed-at: u0,
                duration-hours: u0
            }
        )
        (var-set match-counter new-id)
        (ok new-id)
    )
)

;; Complete exchange with duration
;; #[allow(unchecked_data)]
(define-public (complete-exchange (match-id uint) (duration-hours uint))
    (let
        (
            (match (unwrap! (map-get? exchange-matches { match-id: match-id }) err-not-found))
        )
        (asserts! (> duration-hours u0) err-invalid-duration)
        (asserts! (or (is-eq tx-sender (get student-one match)) (is-eq tx-sender (get student-two match))) err-invalid-match)
        (map-set exchange-matches
            { match-id: match-id }
            (merge match { status: "completed", completed-at: stacks-block-height, duration-hours: duration-hours })
        )
        (try! (update-student-stats (get student-one match) duration-hours))
        (try! (update-student-stats (get student-two match) duration-hours))
        (try! (check-and-award-achievements (get student-one match)))
        (try! (check-and-award-achievements (get student-two match)))
        (ok true)
    )
)

;; Cancel exchange match
;; #[allow(unchecked_data)]
(define-public (cancel-match (match-id uint))
    (let
        (
            (match (unwrap! (map-get? exchange-matches { match-id: match-id }) err-not-found))
        )
        (asserts! (or (is-eq tx-sender (get student-one match)) (is-eq tx-sender (get student-two match))) err-invalid-match)
        (map-set exchange-matches
            { match-id: match-id }
            (merge match { status: "cancelled" })
        )
        (ok true)
    )
)

;; Submit feedback with comment
;; #[allow(unchecked_data)]
(define-public (submit-feedback (match-id uint) (rating uint) (comment (string-ascii 200)))
    (let
        (
            (match (unwrap! (map-get? exchange-matches { match-id: match-id }) err-not-found))
        )
        (asserts! (or (is-eq tx-sender (get student-one match)) (is-eq tx-sender (get student-two match))) err-invalid-match)
        (asserts! (<= rating u5) err-invalid-rating)
        (asserts! (is-eq (get status match) "completed") err-invalid-status)
        (map-set match-feedback
            { match-id: match-id, student: tx-sender }
            { rating: rating, feedback-given: true, comment: comment }
        )
        (ok true)
    )
)

;; Block a student from matching
;; #[allow(unchecked_data)]
(define-public (block-student (student-to-block principal))
    (begin
        (asserts! (is-some (map-get? student-profiles { student: tx-sender })) err-not-found)
        (map-set blocked-students
            { student: tx-sender, blocked: student-to-block }
            { blocked: true }
        )
        (ok true)
    )
)

;; Unblock a student
;; #[allow(unchecked_data)]
(define-public (unblock-student (student-to-unblock principal))
    (begin
        (asserts! (is-some (map-get? student-profiles { student: tx-sender })) err-not-found)
        (map-delete blocked-students { student: tx-sender, blocked: student-to-unblock })
        (ok true)
    )
)

;; Update student statistics
(define-private (update-student-stats (student principal) (hours uint))
    (let
        (
            (profile (unwrap! (map-get? student-profiles { student: student }) err-not-found))
        )
        (map-set student-profiles
            { student: student }
            (merge profile { 
                matches-completed: (+ (get matches-completed profile) u1),
                total-hours: (+ (get total-hours profile) hours)
            })
        )
        (var-set total-hours (+ (var-get total-hours) hours))
        (ok true)
    )
)

;; Check and award achievements
(define-private (check-and-award-achievements (student principal))
    (let
        (
            (profile (unwrap! (map-get? student-profiles { student: student }) err-not-found))
            (completed (get matches-completed profile))
            (hours (get total-hours profile))
        )
        (if (>= completed u1)
            (map-set student-achievements
                { student: student, achievement-type: "first-exchange" }
                { earned: true, earned-at: stacks-block-height }
            )
            true
        )
        (if (>= completed u5)
            (map-set student-achievements
                { student: student, achievement-type: "five-exchanges" }
                { earned: true, earned-at: stacks-block-height }
            )
            true
        )
        (if (>= completed u10)
            (map-set student-achievements
                { student: student, achievement-type: "ten-exchanges" }
                { earned: true, earned-at: stacks-block-height }
            )
            true
        )
        (if (>= hours u10)
            (map-set student-achievements
                { student: student, achievement-type: "ten-hours" }
                { earned: true, earned-at: stacks-block-height }
            )
            true
        )
        (if (>= hours u50)
            (map-set student-achievements
                { student: student, achievement-type: "fifty-hours" }
                { earned: true, earned-at: stacks-block-height }
            )
            true
        )
        (ok true)
    )
)

;; Admin: Toggle program status
(define-public (toggle-program-status)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set program-active (not (var-get program-active)))
        (ok (var-get program-active))
    )
)

;; Admin: Set grade level range
(define-public (set-grade-range (min-grade uint) (max-grade uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (< min-grade max-grade) err-invalid-grade)
        (var-set min-grade-level min-grade)
        (var-set max-grade-level max-grade)
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-student-profile (student principal))
    (map-get? student-profiles { student: student })
)

(define-read-only (get-match (match-id uint))
    (map-get? exchange-matches { match-id: match-id })
)

(define-read-only (get-feedback (match-id uint) (student principal))
    (map-get? match-feedback { match-id: match-id, student: student })
)

(define-read-only (get-achievement (student principal) (achievement-type (string-ascii 50)))
    (map-get? student-achievements { student: student, achievement-type: achievement-type })
)

(define-read-only (is-blocked (student principal) (blocked principal))
    (default-to { blocked: false } (map-get? blocked-students { student: student, blocked: blocked }))
)

(define-read-only (get-total-students)
    (ok (var-get student-counter))
)

(define-read-only (get-total-matches)
    (ok (var-get match-counter))
)

(define-read-only (get-total-hours)
    (ok (var-get total-hours))
)

(define-read-only (get-program-status)
    (ok (var-get program-active))
)

(define-read-only (get-grade-range)
    (ok { min: (var-get min-grade-level), max: (var-get max-grade-level) })
)

(define-read-only (is-student-active (student principal))
    (match (map-get? student-profiles { student: student })
        profile (ok (get active profile))
        (ok false)
    )
)