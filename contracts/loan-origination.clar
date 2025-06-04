;; Loan Origination Contract
;; Originates loans automatically

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_LOAN_NOT_FOUND (err u301))
(define-constant ERR_INVALID_STATUS (err u302))
(define-constant ERR_INSUFFICIENT_FUNDS (err u303))

;; Loan statuses
(define-constant STATUS_PENDING "pending")
(define-constant STATUS_APPROVED "approved")
(define-constant STATUS_FUNDED "funded")
(define-constant STATUS_ACTIVE "active")
(define-constant STATUS_REJECTED "rejected")

;; Data structures
(define-map loans
  uint ;; loan-id
  {
    borrower: principal,
    lender: principal,
    amount: uint,
    interest-rate: uint,
    term-months: uint,
    monthly-payment: uint,
    status: (string-ascii 20),
    origination-date: uint,
    risk-assessment-id: uint
  }
)

(define-map loan-applications
  uint ;; application-id
  {
    borrower: principal,
    requested-amount: uint,
    purpose: (string-ascii 100),
    term-months: uint,
    application-date: uint,
    status: (string-ascii 20)
  }
)

(define-data-var next-loan-id uint u1)
(define-data-var next-application-id uint u1)

;; Public functions

;; Submit loan application
(define-public (submit-loan-application
  (amount uint)
  (purpose (string-ascii 100))
  (term-months uint))

  (let ((application-id (var-get next-application-id)))
    (map-set loan-applications application-id {
      borrower: tx-sender,
      requested-amount: amount,
      purpose: purpose,
      term-months: term-months,
      application-date: block-height,
      status: STATUS_PENDING
    })

    (var-set next-application-id (+ application-id u1))
    (ok application-id)
  )
)

;; Originate loan (after risk assessment)
(define-public (originate-loan
  (application-id uint)
  (lender principal)
  (risk-assessment-id uint)
  (approved-amount uint)
  (interest-rate uint))

  (let (
    (application (unwrap! (map-get? loan-applications application-id) ERR_LOAN_NOT_FOUND))
    (loan-id (var-get next-loan-id))
    (monthly-payment (calculate-monthly-payment approved-amount interest-rate (get term-months application)))
  )

    ;; Create loan record
    (map-set loans loan-id {
      borrower: (get borrower application),
      lender: lender,
      amount: approved-amount,
      interest-rate: interest-rate,
      term-months: (get term-months application),
      monthly-payment: monthly-payment,
      status: STATUS_APPROVED,
      origination-date: block-height,
      risk-assessment-id: risk-assessment-id
    })

    ;; Update application status
    (map-set loan-applications application-id
      (merge application { status: STATUS_APPROVED }))

    (var-set next-loan-id (+ loan-id u1))
    (ok loan-id)
  )
)

;; Fund loan
(define-public (fund-loan (loan-id uint))
  (let ((loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
    (asserts! (is-eq (get status loan) STATUS_APPROVED) ERR_INVALID_STATUS)
    (asserts! (is-eq tx-sender (get lender loan)) ERR_UNAUTHORIZED)

    ;; Update loan status to funded
    (map-set loans loan-id (merge loan { status: STATUS_FUNDED }))

    (ok true)
  )
)

;; Activate loan (after funding)
(define-public (activate-loan (loan-id uint))
  (let ((loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
    (asserts! (is-eq (get status loan) STATUS_FUNDED) ERR_INVALID_STATUS)

    ;; Update loan status to active
    (map-set loans loan-id (merge loan { status: STATUS_ACTIVE }))

    (ok true)
  )
)

;; Private functions

;; Calculate monthly payment using simple interest
(define-private (calculate-monthly-payment (principal uint) (annual-rate uint) (term-months uint))
  (let (
    (monthly-rate (/ annual-rate u1200)) ;; Convert annual rate to monthly decimal
    (total-interest (/ (* principal (* annual-rate term-months)) u1200))
    (total-amount (+ principal total-interest))
  )
    (/ total-amount term-months)
  )
)

;; Read-only functions

;; Get loan details
(define-read-only (get-loan (loan-id uint))
  (map-get? loans loan-id)
)

;; Get loan application
(define-read-only (get-loan-application (application-id uint))
  (map-get? loan-applications application-id)
)

;; Get borrower's active loans count
(define-read-only (get-borrower-loan-count (borrower principal))
  ;; This would need to be implemented with a counter or iteration
  ;; For simplicity, returning a placeholder
  u0
)
