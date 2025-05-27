;; Community Wellbeing Contract
;; Tracks community health improvements and regenerative outcomes

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_COMMUNITY_NOT_FOUND (err u301))
(define-constant ERR_INVALID_METRIC (err u302))
(define-constant ERR_COMMUNITY_EXISTS (err u303))

;; Data Variables
(define-data-var next-community-id uint u1)

;; Data Maps
(define-map communities
  { community-id: uint }
  {
    name: (string-ascii 100),
    location: (string-ascii 100),
    population: uint,
    registrar: principal,
    registration-date: uint,
    is-active: bool
  }
)

(define-map wellbeing-metrics
  { community-id: uint, metric-type: (string-ascii 50), period: uint }
  {
    value: uint,
    recorder: principal,
    record-date: uint,
    improvement-rate: int
  }
)

(define-map community-by-name
  { name: (string-ascii 100) }
  { community-id: uint }
)

;; Public Functions

;; Register a new community
(define-public (register-community
  (name (string-ascii 100))
  (location (string-ascii 100))
  (population uint))

  (let ((community-id (var-get next-community-id)))
    (asserts! (is-none (map-get? community-by-name { name: name })) ERR_COMMUNITY_EXISTS)

    (map-set communities
      { community-id: community-id }
      {
        name: name,
        location: location,
        population: population,
        registrar: tx-sender,
        registration-date: block-height,
        is-active: true
      }
    )

    (map-set community-by-name
      { name: name }
      { community-id: community-id }
    )

    (var-set next-community-id (+ community-id u1))
    (ok community-id)
  )
)

;; Record wellbeing metric
(define-public (record-wellbeing-metric
  (community-id uint)
  (metric-type (string-ascii 50))
  (value uint)
  (period uint))

  (let ((community (unwrap! (map-get? communities { community-id: community-id }) ERR_COMMUNITY_NOT_FOUND)))
    (asserts! (get is-active community) ERR_COMMUNITY_NOT_FOUND)
    (asserts! (and (>= value u0) (<= value u100)) ERR_INVALID_METRIC)

    ;; Calculate improvement rate compared to previous period
    (let ((previous-metric (map-get? wellbeing-metrics
                           { community-id: community-id, metric-type: metric-type, period: (- period u1) })))
      (let ((improvement-rate
             (match previous-metric
               prev-metric (- (to-int value) (to-int (get value prev-metric)))
               0)))

        (map-set wellbeing-metrics
          { community-id: community-id, metric-type: metric-type, period: period }
          {
            value: value,
            recorder: tx-sender,
            record-date: block-height,
            improvement-rate: improvement-rate
          }
        )
        (ok true)
      )
    )
  )
)

;; Update community status
(define-public (update-community-status (community-id uint) (is-active bool))
  (let ((community (unwrap! (map-get? communities { community-id: community-id }) ERR_COMMUNITY_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set communities
      { community-id: community-id }
      (merge community { is-active: is-active })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get community details
(define-read-only (get-community (community-id uint))
  (map-get? communities { community-id: community-id })
)

;; Get community by name
(define-read-only (get-community-by-name (name (string-ascii 100)))
  (match (map-get? community-by-name { name: name })
    community-ref (map-get? communities { community-id: (get community-id community-ref) })
    none
  )
)

;; Get wellbeing metric
(define-read-only (get-wellbeing-metric
  (community-id uint)
  (metric-type (string-ascii 50))
  (period uint))
  (map-get? wellbeing-metrics { community-id: community-id, metric-type: metric-type, period: period })
)

;; Calculate average wellbeing score for a community
(define-read-only (get-community-wellbeing-average (community-id uint) (period uint))
  ;; This is a simplified calculation - in practice, you'd aggregate multiple metrics
  (match (map-get? wellbeing-metrics { community-id: community-id, metric-type: "overall", period: period })
    metric (some (get value metric))
    none
  )
)
