;; Tokenized Enterprise Architecture - Cloud Architect Verification Contract

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_CREDENTIALS (err u103))

;; Data structures
(define-map verified-architects
  { architect: principal }
  {
    verification-date: uint,
    certification-level: (string-ascii 20),
    specializations: (list 5 (string-ascii 30)),
    reputation-score: uint,
    active: bool
  }
)

(define-map architect-tokens
  { architect: principal }
  { token-balance: uint }
)

(define-data-var total-verified-architects uint u0)
(define-data-var verification-fee uint u1000000) ;; 1 STX in microSTX

;; Public functions
(define-public (verify-architect
  (architect principal)
  (certification-level (string-ascii 20))
  (specializations (list 5 (string-ascii 30))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? verified-architects { architect: architect })) ERR_ALREADY_VERIFIED)

    (map-set verified-architects
      { architect: architect }
      {
        verification-date: stacks-block-height,
        certification-level: certification-level,
        specializations: specializations,
        reputation-score: u100,
        active: true
      }
    )

    ;; Mint verification tokens
    (map-set architect-tokens
      { architect: architect }
      { token-balance: u1000 }
    )

    (var-set total-verified-architects (+ (var-get total-verified-architects) u1))
    (ok true)
  )
)

(define-public (update-reputation (architect principal) (new-score uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (let ((architect-data (unwrap! (map-get? verified-architects { architect: architect }) ERR_NOT_FOUND)))
      (map-set verified-architects
        { architect: architect }
        (merge architect-data { reputation-score: new-score })
      )
      (ok true)
    )
  )
)

(define-public (deactivate-architect (architect principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (let ((architect-data (unwrap! (map-get? verified-architects { architect: architect }) ERR_NOT_FOUND)))
      (map-set verified-architects
        { architect: architect }
        (merge architect-data { active: false })
      )
      (ok true)
    )
  )
)

;; Read-only functions
(define-read-only (get-architect-info (architect principal))
  (map-get? verified-architects { architect: architect })
)

(define-read-only (is-verified-architect (architect principal))
  (match (map-get? verified-architects { architect: architect })
    architect-data (get active architect-data)
    false
  )
)

(define-read-only (get-architect-tokens (architect principal))
  (default-to u0 (get token-balance (map-get? architect-tokens { architect: architect })))
)

(define-read-only (get-total-verified-architects)
  (var-get total-verified-architects)
)
