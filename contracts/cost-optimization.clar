;; Cost Optimization Contract

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_OPTIMIZATION_NOT_FOUND (err u501))
(define-constant ERR_INVALID_COST_MODEL (err u502))

(define-map cost-optimizations
  { optimization-id: uint }
  {
    optimizer: principal,
    migration-plan-id: uint,
    created-at: uint,
    current-cost: uint,
    projected-cost: uint,
    savings-potential: uint,
    optimization-strategies: (list 5 (string-ascii 50)),
    implementation-timeline: uint,
    approved: bool
  }
)

(define-map cost-models
  { model-id: uint }
  {
    optimization-id: uint,
    service-type: (string-ascii 30),
    current-usage: uint,
    projected-usage: uint,
    unit-cost: uint,
    scaling-factor: uint
  }
)

(define-map savings-tracking
  { tracking-id: uint }
  {
    optimization-id: uint,
    period-start: uint,
    period-end: uint,
    actual-savings: uint,
    projected-savings: uint,
    efficiency-score: uint
  }
)

(define-data-var next-optimization-id uint u1)
(define-data-var next-model-id uint u1)
(define-data-var next-tracking-id uint u1)

;; Public functions
(define-public (create-cost-optimization
  (migration-plan-id uint)
  (current-cost uint)
  (projected-cost uint)
  (optimization-strategies (list 5 (string-ascii 50)))
  (implementation-timeline uint))
  (let ((optimization-id (var-get next-optimization-id)))
    (asserts! (> current-cost u0) ERR_INVALID_COST_MODEL)

    (let ((savings-potential (if (> current-cost projected-cost)
                               (- current-cost projected-cost)
                               u0)))
      (map-set cost-optimizations
        { optimization-id: optimization-id }
        {
          optimizer: tx-sender,
          migration-plan-id: migration-plan-id,
          created-at: stacks-block-height,
          current-cost: current-cost,
          projected-cost: projected-cost,
          savings-potential: savings-potential,
          optimization-strategies: optimization-strategies,
          implementation-timeline: implementation-timeline,
          approved: false
        }
      )

      (var-set next-optimization-id (+ optimization-id u1))
      (ok optimization-id)
    )
  )
)

(define-public (add-cost-model
  (optimization-id uint)
  (service-type (string-ascii 30))
  (current-usage uint)
  (projected-usage uint)
  (unit-cost uint)
  (scaling-factor uint))
  (let ((model-id (var-get next-model-id)))
    (let ((optimization (unwrap! (map-get? cost-optimizations { optimization-id: optimization-id }) ERR_OPTIMIZATION_NOT_FOUND)))
      (asserts! (is-eq tx-sender (get optimizer optimization)) ERR_UNAUTHORIZED)

      (map-set cost-models
        { model-id: model-id }
        {
          optimization-id: optimization-id,
          service-type: service-type,
          current-usage: current-usage,
          projected-usage: projected-usage,
          unit-cost: unit-cost,
          scaling-factor: scaling-factor
        }
      )

      (var-set next-model-id (+ model-id u1))
      (ok model-id)
    )
  )
)

(define-public (track-savings
  (optimization-id uint)
  (period-start uint)
  (period-end uint)
  (actual-savings uint)
  (projected-savings uint))
  (let ((tracking-id (var-get next-tracking-id)))
    (let ((optimization (unwrap! (map-get? cost-optimizations { optimization-id: optimization-id }) ERR_OPTIMIZATION_NOT_FOUND)))
      (let ((efficiency-score (if (> projected-savings u0)
                                (/ (* actual-savings u100) projected-savings)
                                u0)))
        (map-set savings-tracking
          { tracking-id: tracking-id }
          {
            optimization-id: optimization-id,
            period-start: period-start,
            period-end: period-end,
            actual-savings: actual-savings,
            projected-savings: projected-savings,
            efficiency-score: efficiency-score
          }
        )

        (var-set next-tracking-id (+ tracking-id u1))
        (ok tracking-id)
      )
    )
  )
)

;; Read-only functions
(define-read-only (get-cost-optimization (optimization-id uint))
  (map-get? cost-optimizations { optimization-id: optimization-id })
)

(define-read-only (get-cost-model (model-id uint))
  (map-get? cost-models { model-id: model-id })
)

(define-read-only (get-savings-tracking (tracking-id uint))
  (map-get? savings-tracking { tracking-id: tracking-id })
)

(define-read-only (calculate-roi (optimization-id uint))
  (match (map-get? cost-optimizations { optimization-id: optimization-id })
    optimization (let ((savings (get savings-potential optimization))
                      (timeline (get implementation-timeline optimization)))
                    (if (> timeline u0)
                      (some (/ (* savings u12) timeline)) ;; Annualized ROI
                      none))
    none
  )
)
