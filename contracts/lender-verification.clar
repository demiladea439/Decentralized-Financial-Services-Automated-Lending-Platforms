;; Lender Verification Contract
;; Validates and manages automated lending platforms

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INSUFFICIENT_STAKE (err u103))

;; Minimum stake required for lender verification (in microSTX)
(define-constant MIN_LENDER_STAKE u1000000)

;; Data structures
(define-map verified-lenders
  principal
  {
    stake-amount: uint,
    verification-date: uint,
    reputation-score: uint,
    total-loans-funded: uint,
    active: bool
  }
)

(define-map lender-applications
  principal
  {
    stake-amount: uint,
    application-date: uint,
    status: (string-ascii 20)
  }
)

;; Public functions

;; Apply for lender verification
(define-public (apply-for-verification (stake-amount uint))
  (let ((applicant tx-sender))
    (asserts! (>= stake-amount MIN_LENDER_STAKE) ERR_INSUFFICIENT_STAKE)
    (asserts! (is-none (map-get? verified-lenders applicant)) ERR_ALREADY_VERIFIED)

    ;; Store application
    (map-set lender-applications applicant {
      stake-amount: stake-amount,
      application-date: block-height,
      status: "pending"
    })

    (ok true)
  )
)

;; Verify a lender (admin function)
(define-public (verify-lender (lender principal))
  (let ((application (unwrap! (map-get? lender-applications lender) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    ;; Add to verified lenders
    (map-set verified-lenders lender {
      stake-amount: (get stake-amount application),
      verification-date: block-height,
      reputation-score: u100,
      total-loans-funded: u0,
      active: true
    })

    ;; Update application status
    (map-set lender-applications lender
      (merge application { status: "approved" }))

    (ok true)
  )
)

;; Update lender reputation
(define-public (update-reputation (lender principal) (new-score uint))
  (let ((lender-data (unwrap! (map-get? verified-lenders lender) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set verified-lenders lender
      (merge lender-data { reputation-score: new-score }))

    (ok true)
  )
)

;; Read-only functions

;; Check if lender is verified
(define-read-only (is-verified-lender (lender principal))
  (match (map-get? verified-lenders lender)
    lender-data (get active lender-data)
    false
  )
)

;; Get lender details
(define-read-only (get-lender-details (lender principal))
  (map-get? verified-lenders lender)
)

;; Get lender reputation
(define-read-only (get-lender-reputation (lender principal))
  (match (map-get? verified-lenders lender)
    lender-data (some (get reputation-score lender-data))
    none
  )
)
