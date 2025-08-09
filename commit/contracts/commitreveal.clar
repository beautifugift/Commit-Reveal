;; Commit-Reveal Raffle (deterministic fairness via commitments; selection can be verified off-chain)
;; Accounting-only ticket registry; no randomness on-chain loops

;; Errors
(define-constant ERR_INVALID (err u600))
(define-constant ERR_NOT_FOUND (err u601))
(define-constant ERR_STATUS (err u602))
(define-constant ERR_UNAUTHORIZED (err u603))

(define-constant ADMIN tx-sender)

(define-data-var next-raffle-id uint u1)

(define-map raffles
  { raffle-id: uint }
  {
    organizer: principal,
    name: (string-ascii 80),
    ticket-price: uint,
    max-winners: uint,
    commit-end: uint,
    reveal-end: uint,
    status: uint ;; 1=open, 2=closed
  }
)

(define-map tickets
  { raffle-id: uint, buyer: principal }
  {
    tickets: uint,
    spent: uint,
    last-update: uint
  }
)

(define-map commits
  { raffle-id: uint, committer: principal }
  {
    commit-hash: (string-ascii 64),
    revealed-seed: (optional (string-ascii 64))
  }
)

;; Validation
(define-private (is-valid-principal (p principal)) (not (is-eq p 'SP000000000000000000002Q6VF78)))
(define-private (len-ok (s (string-ascii 80)) (m uint)) (and (> (len s) u0) (<= (len s) m)))
(define-private (is-valid-raffle-id (id uint)) (and (> id u0) (< id (var-get next-raffle-id))))

;; Create raffle
(define-public (create-raffle
  (name (string-ascii 80))
  (ticket-price uint)
  (max-winners uint)
  (commit-end uint)
  (reveal-end uint))
  (let ((rid (var-get next-raffle-id)))
    (asserts! (len-ok name u80) ERR_INVALID)
    (asserts! (> ticket-price u0) ERR_INVALID)
    (asserts! (> max-winners u0) ERR_INVALID)
    (asserts! (> commit-end stacks-block-height) ERR_INVALID)
    (asserts! (> reveal-end commit-end) ERR_INVALID)
    (map-set raffles { raffle-id: rid }
      {
        organizer: tx-sender,
        name: name,
        ticket-price: ticket-price,
        max-winners: max-winners,
        commit-end: commit-end,
        reveal-end: reveal-end,
        status: u1
      })
    (var-set next-raffle-id (+ rid u1))
    (ok rid)
  )
)

;; Buy tickets (accounting only)
(define-public (buy-tickets (raffle-id uint) (ticket-count uint) (spend uint))
  (let ((rid (begin (asserts! (is-valid-raffle-id raffle-id) ERR_NOT_FOUND) raffle-id))
        (r (unwrap! (map-get? raffles { raffle-id: raffle-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq (get status r) u1) ERR_STATUS)
    (asserts! (<= stacks-block-height (get commit-end r)) ERR_STATUS)
    (asserts! (> ticket-count u0) ERR_INVALID)
    (asserts! (is-eq spend (* ticket-count (get ticket-price r))) ERR_INVALID)
    (match (map-get? tickets { raffle-id: rid, buyer: tx-sender })
      t (map-set tickets { raffle-id: rid, buyer: tx-sender }
            { tickets: (+ (get tickets t) ticket-count),
              spent: (+ (get spent t) spend),
              last-update: stacks-block-height })
      (map-set tickets { raffle-id: rid, buyer: tx-sender }
        { tickets: ticket-count, spent: spend, last-update: stacks-block-height })
    )
    (ok true)
  )
)

;; Commit seed
(define-public (commit-seed (raffle-id uint) (commit-hash (string-ascii 64)))
  (let ((rid (begin (asserts! (is-valid-raffle-id raffle-id) ERR_NOT_FOUND) raffle-id))
        (r (unwrap! (map-get? raffles { raffle-id: raffle-id }) ERR_NOT_FOUND)))
    (asserts! (<= stacks-block-height (get commit-end r)) ERR_STATUS)
    (asserts! (len-ok commit-hash u64) ERR_INVALID)
    (ok (map-set commits { raffle-id: rid, committer: tx-sender } { commit-hash: commit-hash, revealed-seed: none }))
  )
)

;; Reveal seed
(define-public (reveal-seed (raffle-id uint) (seed (string-ascii 64)))
  (let ((rid (begin (asserts! (is-valid-raffle-id raffle-id) ERR_NOT_FOUND) raffle-id))
        (r (unwrap! (map-get? raffles { raffle-id: raffle-id }) ERR_NOT_FOUND))
        (c (unwrap! (map-get? commits { raffle-id: raffle-id, committer: tx-sender }) ERR_NOT_FOUND)))
    (asserts! (and (> stacks-block-height (get commit-end r)) (<= stacks-block-height (get reveal-end r))) ERR_STATUS)
    (asserts! (len-ok seed u64) ERR_INVALID)
    ;; The actual hash check is off-chain reproducible. On-chain we store the reveal for verification.
    (ok (map-set commits { raffle-id: rid, committer: tx-sender } (merge c { revealed-seed: (some seed) })))
  )
)

;; Close raffle
(define-public (close (raffle-id uint))
  (let ((rid (begin (asserts! (is-valid-raffle-id raffle-id) ERR_NOT_FOUND) raffle-id))
        (r (unwrap! (map-get? raffles { raffle-id: raffle-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get organizer r)) ERR_UNAUTHORIZED)
    (asserts! (> stacks-block-height (get reveal-end r)) ERR_STATUS)
    (ok (map-set raffles { raffle-id: rid } (merge r { status: u2 })))
  )
)

;; RO
(define-read-only (get-raffle (raffle-id uint))
  (map-get? raffles { raffle-id: raffle-id })
)

(define-read-only (get-commit (raffle-id uint) (committer principal))
  (map-get? commits { raffle-id: raffle-id, committer: committer })
)

(define-read-only (get-tickets (raffle-id uint) (buyer principal))
  (map-get? tickets { raffle-id: raffle-id, buyer: buyer })
)
