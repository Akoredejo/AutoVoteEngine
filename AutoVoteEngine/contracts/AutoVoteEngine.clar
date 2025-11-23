;; Autonomous Voting Strategy Engine
;; A decentralized voting system that enables users to create proposals, vote directly,
;; or delegate voting power through customizable strategies. The engine supports weighted
;; voting, quorum requirements, time-locked proposals, and autonomous strategy execution.

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-voted (err u103))
(define-constant err-proposal-closed (err u104))
(define-constant err-proposal-active (err u105))
(define-constant err-insufficient-votes (err u106))
(define-constant err-invalid-strategy (err u107))
(define-constant err-quorum-not-met (err u108))

(define-constant proposal-duration u1440) ;; ~10 days in blocks (assuming 10 min blocks)
(define-constant min-quorum-percentage u20) ;; 20% minimum quorum

;; data maps and vars
(define-data-var proposal-count uint u0)
(define-data-var total-voting-power uint u0)

;; Proposal structure
(define-map proposals
  uint
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    votes-for: uint,
    votes-against: uint,
    start-block: uint,
    end-block: uint,
    executed: bool,
    quorum-required: uint,
    status: (string-ascii 20)
  }
)

;; Voter records for each proposal
(define-map votes
  { proposal-id: uint, voter: principal }
  {
    vote-weight: uint,
    vote-choice: bool, ;; true = for, false = against
    voted-at: uint
  }
)

;; Voting power per user
(define-map voting-power
  principal
  uint
)

;; Voting strategies: users can define automated voting rules
(define-map voting-strategies
  { owner: principal, strategy-id: uint }
  {
    name: (string-ascii 50),
    auto-vote: bool,
    vote-preference: bool, ;; default vote choice
    min-quorum-threshold: uint,
    delegate-to: (optional principal),
    active: bool
  }
)

(define-map user-strategy-count
  principal
  uint
)

;; Delegation records
(define-map delegations
  { delegator: principal, delegate: principal }
  {
    voting-power-delegated: uint,
    active: bool,
    created-at: uint
  }
)

;; private functions

;; Calculate if quorum is met for a proposal
(define-private (is-quorum-met (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) false))
      (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
      (required-votes (get quorum-required proposal))
    )
    (>= total-votes required-votes)
  )
)

;; Check if proposal voting period is active
(define-private (is-proposal-active (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) false))
      (current-block block-height)
    )
    (and
      (>= current-block (get start-block proposal))
      (<= current-block (get end-block proposal))
      (not (get executed proposal))
    )
  )
)

;; Calculate voting power including delegations
(define-private (get-effective-voting-power (voter principal))
  (let
    (
      (base-power (default-to u0 (map-get? voting-power voter)))
    )
    base-power
  )
)

;; Update proposal status based on current state
(define-private (update-proposal-status (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) false))
      (current-block block-height)
      (new-status
        (if (get executed proposal)
          "executed"
          (if (> current-block (get end-block proposal))
            (if (is-quorum-met proposal-id)
              "passed"
              "failed")
            "active")))
    )
    (map-set proposals proposal-id
      (merge proposal { status: new-status })
    )
  )
)

;; public functions

;; Initialize or update voting power for a user
(define-public (set-voting-power (user principal) (power uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set voting-power user power)
    (var-set total-voting-power (+ (var-get total-voting-power) power))
    (ok true)
  )
)

;; Create a new proposal
(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)))
  (let
    (
      (new-proposal-id (+ (var-get proposal-count) u1))
      (start-block block-height)
      (end-block (+ block-height proposal-duration))
      (quorum (/ (* (var-get total-voting-power) min-quorum-percentage) u100))
    )
    (map-set proposals new-proposal-id
      {
        proposer: tx-sender,
        title: title,
        description: description,
        votes-for: u0,
        votes-against: u0,
        start-block: start-block,
        end-block: end-block,
        executed: false,
        quorum-required: quorum,
        status: "active"
      }
    )
    (var-set proposal-count new-proposal-id)
    (ok new-proposal-id)
  )
)

;; Cast a vote on a proposal
(define-public (vote (proposal-id uint) (vote-for bool))
  (let
    (
      (voter-power (get-effective-voting-power tx-sender))
      (proposal (unwrap! (map-get? proposals proposal-id) err-not-found))
      (existing-vote (map-get? votes { proposal-id: proposal-id, voter: tx-sender }))
    )
    (asserts! (is-proposal-active proposal-id) err-proposal-closed)
    (asserts! (is-none existing-vote) err-already-voted)
    (asserts! (> voter-power u0) err-insufficient-votes)
    
    ;; Record the vote
    (map-set votes
      { proposal-id: proposal-id, voter: tx-sender }
      {
        vote-weight: voter-power,
        vote-choice: vote-for,
        voted-at: block-height
      }
    )
    
    ;; Update proposal vote counts
    (map-set proposals proposal-id
      (merge proposal
        (if vote-for
          { votes-for: (+ (get votes-for proposal) voter-power), votes-against: (get votes-against proposal) }
          { votes-for: (get votes-for proposal), votes-against: (+ (get votes-against proposal) voter-power) }
        )
      )
    )
    
    (ok true)
  )
)

;; Create a voting strategy
(define-public (create-voting-strategy 
    (name (string-ascii 50))
    (auto-vote bool)
    (vote-preference bool)
    (min-quorum uint)
    (delegate (optional principal)))
  (let
    (
      (strategy-count (default-to u0 (map-get? user-strategy-count tx-sender)))
      (new-strategy-id (+ strategy-count u1))
    )
    (map-set voting-strategies
      { owner: tx-sender, strategy-id: new-strategy-id }
      {
        name: name,
        auto-vote: auto-vote,
        vote-preference: vote-preference,
        min-quorum-threshold: min-quorum,
        delegate-to: delegate,
        active: true
      }
    )
    (map-set user-strategy-count tx-sender new-strategy-id)
    (ok new-strategy-id)
  )
)

;; Delegate voting power to another user
(define-public (delegate-voting-power (delegate principal) (power uint))
  (let
    (
      (delegator-power (get-effective-voting-power tx-sender))
    )
    (asserts! (<= power delegator-power) err-insufficient-votes)
    (asserts! (not (is-eq tx-sender delegate)) err-invalid-strategy)
    
    (map-set delegations
      { delegator: tx-sender, delegate: delegate }
      {
        voting-power-delegated: power,
        active: true,
        created-at: block-height
      }
    )
    
    ;; Update voting power
    (map-set voting-power tx-sender (- delegator-power power))
    (map-set voting-power delegate 
      (+ (default-to u0 (map-get? voting-power delegate)) power))
    
    (ok true)
  )
)

;; Revoke delegation
(define-public (revoke-delegation (delegate principal))
  (let
    (
      (delegation (unwrap! (map-get? delegations 
        { delegator: tx-sender, delegate: delegate }) err-not-found))
      (delegated-power (get voting-power-delegated delegation))
    )
    (asserts! (get active delegation) err-unauthorized)
    
    ;; Return voting power
    (map-set voting-power tx-sender 
      (+ (default-to u0 (map-get? voting-power tx-sender)) delegated-power))
    (map-set voting-power delegate 
      (- (default-to u0 (map-get? voting-power delegate)) delegated-power))
    
    ;; Deactivate delegation
    (map-set delegations
      { delegator: tx-sender, delegate: delegate }
      (merge delegation { active: false })
    )
    
    (ok true)
  )
)

;; Execute a proposal (finalize voting)
(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) err-not-found))
    )
    (asserts! (> block-height (get end-block proposal)) err-proposal-active)
    (asserts! (not (get executed proposal)) err-proposal-closed)
    (asserts! (is-quorum-met proposal-id) err-quorum-not-met)
    
    (map-set proposals proposal-id
      (merge proposal { executed: true, status: "executed" })
    )
    
    (ok true)
  )
)

;; Read-only functions for querying state
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-user-voting-power (user principal))
  (default-to u0 (map-get? voting-power user))
)

(define-read-only (get-strategy (owner principal) (strategy-id uint))
  (map-get? voting-strategies { owner: owner, strategy-id: strategy-id })
)


