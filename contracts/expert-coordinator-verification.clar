;; Expert Coordinator Verification Contract
;; Validates and manages knowledge expert coordinators

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_CREDENTIALS (err u103))

;; Data Variables
(define-data-var next-coordinator-id uint u1)

;; Data Maps
(define-map coordinators
  { coordinator-id: uint }
  {
    address: principal,
    name: (string-ascii 50),
    expertise-areas: (list 10 (string-ascii 30)),
    verification-status: bool,
    reputation-score: uint,
    verified-at: uint,
    verified-by: principal
  }
)

(define-map coordinator-by-address
  { address: principal }
  { coordinator-id: uint }
)

(define-map verification-requirements
  { requirement-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    required: bool
  }
)

;; Public Functions

;; Register a new coordinator
(define-public (register-coordinator
  (name (string-ascii 50))
  (expertise-areas (list 10 (string-ascii 30))))
  (let ((coordinator-id (var-get next-coordinator-id)))
    (asserts! (is-none (map-get? coordinator-by-address { address: tx-sender })) ERR_ALREADY_VERIFIED)
    (map-set coordinators
      { coordinator-id: coordinator-id }
      {
        address: tx-sender,
        name: name,
        expertise-areas: expertise-areas,
        verification-status: false,
        reputation-score: u0,
        verified-at: u0,
        verified-by: CONTRACT_OWNER
      }
    )
    (map-set coordinator-by-address
      { address: tx-sender }
      { coordinator-id: coordinator-id }
    )
    (var-set next-coordinator-id (+ coordinator-id u1))
    (ok coordinator-id)
  )
)

;; Verify a coordinator (only contract owner)
(define-public (verify-coordinator (coordinator-id uint))
  (let ((coordinator-data (unwrap! (map-get? coordinators { coordinator-id: coordinator-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (get verification-status coordinator-data)) ERR_ALREADY_VERIFIED)
    (map-set coordinators
      { coordinator-id: coordinator-id }
      (merge coordinator-data {
        verification-status: true,
        verified-at: stacks-block-height,
        verified-by: tx-sender
      })
    )
    (ok true)
  )
)

;; Update reputation score
(define-public (update-reputation (coordinator-id uint) (new-score uint))
  (let ((coordinator-data (unwrap! (map-get? coordinators { coordinator-id: coordinator-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set coordinators
      { coordinator-id: coordinator-id }
      (merge coordinator-data { reputation-score: new-score })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get coordinator by ID
(define-read-only (get-coordinator (coordinator-id uint))
  (map-get? coordinators { coordinator-id: coordinator-id })
)

;; Get coordinator by address
(define-read-only (get-coordinator-by-address (address principal))
  (match (map-get? coordinator-by-address { address: address })
    coordinator-ref (map-get? coordinators { coordinator-id: (get coordinator-id coordinator-ref) })
    none
  )
)

;; Check if coordinator is verified
(define-read-only (is-coordinator-verified (coordinator-id uint))
  (match (map-get? coordinators { coordinator-id: coordinator-id })
    coordinator-data (get verification-status coordinator-data)
    false
  )
)
