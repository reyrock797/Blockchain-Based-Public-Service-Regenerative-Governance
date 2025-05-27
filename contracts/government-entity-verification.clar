;; Government Entity Verification Contract
;; Validates regenerative governance systems and entities

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ENTITY_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_VERIFIED (err u102))
(define-constant ERR_INVALID_SCORE (err u103))

;; Data Variables
(define-data-var next-entity-id uint u1)

;; Data Maps
(define-map verified-entities
  { entity-id: uint }
  {
    name: (string-ascii 100),
    verifier: principal,
    verification-date: uint,
    regenerative-score: uint,
    is-active: bool
  }
)

(define-map entity-by-name
  { name: (string-ascii 100) }
  { entity-id: uint }
)

;; Public Functions

;; Verify a government entity for regenerative governance
(define-public (verify-entity (name (string-ascii 100)) (regenerative-score uint))
  (let ((entity-id (var-get next-entity-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (>= regenerative-score u1) (<= regenerative-score u100)) ERR_INVALID_SCORE)
    (asserts! (is-none (map-get? entity-by-name { name: name })) ERR_ALREADY_VERIFIED)

    (map-set verified-entities
      { entity-id: entity-id }
      {
        name: name,
        verifier: tx-sender,
        verification-date: block-height,
        regenerative-score: regenerative-score,
        is-active: true
      }
    )

    (map-set entity-by-name
      { name: name }
      { entity-id: entity-id }
    )

    (var-set next-entity-id (+ entity-id u1))
    (ok entity-id)
  )
)

;; Update entity status
(define-public (update-entity-status (entity-id uint) (is-active bool))
  (let ((entity (unwrap! (map-get? verified-entities { entity-id: entity-id }) ERR_ENTITY_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set verified-entities
      { entity-id: entity-id }
      (merge entity { is-active: is-active })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get entity details
(define-read-only (get-entity (entity-id uint))
  (map-get? verified-entities { entity-id: entity-id })
)

;; Get entity by name
(define-read-only (get-entity-by-name (name (string-ascii 100)))
  (match (map-get? entity-by-name { name: name })
    entity-ref (map-get? verified-entities { entity-id: (get entity-id entity-ref) })
    none
  )
)

;; Check if entity is verified and active
(define-read-only (is-entity-verified (entity-id uint))
  (match (map-get? verified-entities { entity-id: entity-id })
    entity (get is-active entity)
    false
  )
)
