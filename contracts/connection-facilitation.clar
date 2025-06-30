;; Connection Facilitation Contract
;; Facilitates connections between experts and knowledge seekers

;; Constants
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_NOT_FOUND (err u301))
(define-constant ERR_INVALID_STATUS (err u302))
(define-constant ERR_ALREADY_EXISTS (err u303))

;; Data Variables
(define-data-var next-request-id uint u1)
(define-data-var next-connection-id uint u1)

;; Data Maps
(define-map connection-requests
  { request-id: uint }
  {
    requester: principal,
    expertise-domain: uint,
    description: (string-ascii 200),
    urgency-level: uint, ;; 1-5 scale
    budget: uint,
    status: (string-ascii 20), ;; "pending", "matched", "completed", "cancelled"
    created-at: uint,
    expires-at: uint
  }
)

(define-map expert-connections
  { connection-id: uint }
  {
    request-id: uint,
    expert: principal,
    requester: principal,
    status: (string-ascii 20), ;; "proposed", "accepted", "active", "completed", "cancelled"
    proposed-at: uint,
    accepted-at: uint,
    completed-at: uint,
    rating: uint, ;; 1-5 scale
    feedback: (optional (string-ascii 200))
  }
)

(define-map active-connections
  { requester: principal, expert: principal }
  { connection-id: uint }
)

;; Public Functions

;; Create a connection request
(define-public (create-connection-request
  (expertise-domain uint)
  (description (string-ascii 200))
  (urgency-level uint)
  (budget uint)
  (duration-blocks uint))
  (let ((request-id (var-get next-request-id)))
    (asserts! (and (>= urgency-level u1) (<= urgency-level u5)) ERR_UNAUTHORIZED)
    (map-set connection-requests
      { request-id: request-id }
      {
        requester: tx-sender,
        expertise-domain: expertise-domain,
        description: description,
        urgency-level: urgency-level,
        budget: budget,
        status: "pending",
        created-at: stacks-block-height,
        expires-at: (+ stacks-block-height duration-blocks)
      }
    )
    (var-set next-request-id (+ request-id u1))
    (ok request-id)
  )
)

;; Propose connection as expert
(define-public (propose-connection (request-id uint))
  (let ((request-data (unwrap! (map-get? connection-requests { request-id: request-id }) ERR_NOT_FOUND))
        (connection-id (var-get next-connection-id)))
    (asserts! (is-eq (get status request-data) "pending") ERR_INVALID_STATUS)
    (asserts! (< stacks-block-height (get expires-at request-data)) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq tx-sender (get requester request-data))) ERR_UNAUTHORIZED)

    (map-set expert-connections
      { connection-id: connection-id }
      {
        request-id: request-id,
        expert: tx-sender,
        requester: (get requester request-data),
        status: "proposed",
        proposed-at: stacks-block-height,
        accepted-at: u0,
        completed-at: u0,
        rating: u0,
        feedback: none
      }
    )
    (var-set next-connection-id (+ connection-id u1))
    (ok connection-id)
  )
)

;; Accept connection proposal
(define-public (accept-connection (connection-id uint))
  (let ((connection-data (unwrap! (map-get? expert-connections { connection-id: connection-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get requester connection-data)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status connection-data) "proposed") ERR_INVALID_STATUS)

    (map-set expert-connections
      { connection-id: connection-id }
      (merge connection-data {
        status: "active",
        accepted-at: stacks-block-height
      })
    )
    (map-set active-connections
      { requester: (get requester connection-data), expert: (get expert connection-data) }
      { connection-id: connection-id }
    )
    (ok true)
  )
)

;; Complete connection and rate
(define-public (complete-connection
  (connection-id uint)
  (rating uint)
  (feedback (optional (string-ascii 200))))
  (let ((connection-data (unwrap! (map-get? expert-connections { connection-id: connection-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get requester connection-data)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status connection-data) "active") ERR_INVALID_STATUS)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_UNAUTHORIZED)

    (map-set expert-connections
      { connection-id: connection-id }
      (merge connection-data {
        status: "completed",
        completed-at: stacks-block-height,
        rating: rating,
        feedback: feedback
      })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get connection request
(define-read-only (get-connection-request (request-id uint))
  (map-get? connection-requests { request-id: request-id })
)

;; Get expert connection
(define-read-only (get-expert-connection (connection-id uint))
  (map-get? expert-connections { connection-id: connection-id })
)

;; Get active connection
(define-read-only (get-active-connection (requester principal) (expert principal))
  (map-get? active-connections { requester: requester, expert: expert })
)
