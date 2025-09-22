;; title: AHIC
;; version: 1.0.0
;; summary: Automated Health Insurance Claims Processing
;; description: Smart contract for automated insurance claim processing with fraud prevention

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_CLAIM_NOT_FOUND (err u101))
(define-constant ERR_INVALID_CLAIM (err u102))
(define-constant ERR_CLAIM_EXPIRED (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_CLAIM_ALREADY_PROCESSED (err u105))
(define-constant ERR_INVALID_PROVIDER (err u106))
(define-constant ERR_POLICY_NOT_ACTIVE (err u107))
(define-constant ERR_CLAIM_AMOUNT_EXCEEDED (err u108))
(define-constant ERR_APPEAL_NOT_FOUND (err u109))
(define-constant ERR_APPEAL_ALREADY_EXISTS (err u110))
(define-constant ERR_APPEAL_NOT_REVIEWABLE (err u111))
(define-constant ERR_APPEAL_EXPIRED (err u112))
(define-constant ERR_INSUFFICIENT_APPEAL_FEE (err u113))

(define-constant CLAIM_EXPIRY_BLOCKS u1008)
(define-constant MIN_CLAIM_AMOUNT u1000000)
(define-constant MAX_CLAIM_AMOUNT u100000000)
(define-constant FRAUD_THRESHOLD u5)
(define-constant APPEAL_FEE u5000000)
(define-constant APPEAL_REVIEW_BLOCKS u144)

(define-data-var claim-counter uint u0)
(define-data-var total-paid uint u0)
(define-data-var contract-balance uint u0)
(define-data-var appeal-counter uint u0)
(define-data-var appeal-fees-collected uint u0)

(define-map policies
  { policy-id: uint }
  {
    holder: principal,
    premium: uint,
    coverage-limit: uint,
    deductible: uint,
    active: bool,
    expiry-block: uint
  }
)

(define-map claims
  { claim-id: uint }
  {
    policy-id: uint,
    claimant: principal,
    provider: principal,
    amount: uint,
    diagnosis-code: (string-ascii 20),
    treatment-date: uint,
    submitted-block: uint,
    status: (string-ascii 20),
    verified: bool
  }
)

(define-map medical-providers
  { provider: principal }
  {
    name: (string-ascii 100),
    license: (string-ascii 50),
    verified: bool,
    fraud-score: uint
  }
)

(define-map user-claims-count
  { user: principal }
  { count: uint }
)

(define-map policy-claims-total
  { policy-id: uint }
  { total-claimed: uint }
)

(define-map appeals
  { appeal-id: uint }
  {
    claim-id: uint,
    appellant: principal,
    appeal-fee: uint,
    submitted-block: uint,
    status: (string-ascii 20),
    reviewer: (optional principal),
    reviewed-block: (optional uint),
    additional-payout: uint
  }
)

(define-map claim-appeals
  { claim-id: uint }
  { appeal-id: uint }
)

(define-public (register-policy (premium uint) (coverage-limit uint) (deductible uint) (duration-blocks uint))
  (let
    (
      (policy-id (+ (var-get claim-counter) u1))
      (expiry-block (+ stacks-block-height duration-blocks))
    )
    (map-set policies
      { policy-id: policy-id }
      {
        holder: tx-sender,
        premium: premium,
        coverage-limit: coverage-limit,
        deductible: deductible,
        active: true,
        expiry-block: expiry-block
      }
    )
    (var-set claim-counter policy-id)
    (ok policy-id)
  )
)

(define-public (register-provider (name (string-ascii 100)) (license (string-ascii 50)))
  (begin
    (map-set medical-providers
      { provider: tx-sender }
      {
        name: name,
        license: license,
        verified: false,
        fraud-score: u0
      }
    )
    (ok true)
  )
)

(define-public (verify-provider (provider principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? medical-providers { provider: provider })
      provider-data
      (begin
        (map-set medical-providers
          { provider: provider }
          (merge provider-data { verified: true })
        )
        (ok true)
      )
      ERR_INVALID_PROVIDER
    )
  )
)

(define-public (submit-claim (policy-id uint) (provider principal) (amount uint) (diagnosis-code (string-ascii 20)) (treatment-date uint))
  (let
    (
      (claim-id (+ (var-get claim-counter) u1))
      (policy-data (unwrap! (map-get? policies { policy-id: policy-id }) ERR_INVALID_CLAIM))
      (provider-data (unwrap! (map-get? medical-providers { provider: provider }) ERR_INVALID_PROVIDER))
      (user-claims (default-to { count: u0 } (map-get? user-claims-count { user: tx-sender })))
    )
    (asserts! (get verified provider-data) ERR_INVALID_PROVIDER)
    (asserts! (get active policy-data) ERR_POLICY_NOT_ACTIVE)
    (asserts! (is-eq tx-sender (get holder policy-data)) ERR_UNAUTHORIZED)
    (asserts! (>= stacks-block-height (get expiry-block policy-data)) ERR_POLICY_NOT_ACTIVE)
    (asserts! (and (>= amount MIN_CLAIM_AMOUNT) (<= amount MAX_CLAIM_AMOUNT)) ERR_INVALID_CLAIM)
    (asserts! (< (get fraud-score provider-data) FRAUD_THRESHOLD) ERR_INVALID_PROVIDER)
    
    (map-set claims
      { claim-id: claim-id }
      {
        policy-id: policy-id,
        claimant: tx-sender,
        provider: provider,
        amount: amount,
        diagnosis-code: diagnosis-code,
        treatment-date: treatment-date,
        submitted-block: stacks-block-height,
        status: "pending",
        verified: false
      }
    )
    
    (map-set user-claims-count
      { user: tx-sender }
      { count: (+ (get count user-claims) u1) }
    )
    
    (var-set claim-counter claim-id)
    (ok claim-id)
  )
)

(define-public (verify-claim (claim-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? claims { claim-id: claim-id })
      claim-data
      (begin
        (map-set claims
          { claim-id: claim-id }
          (merge claim-data { verified: true, status: "verified" })
        )
        (ok true)
      )
      ERR_CLAIM_NOT_FOUND
    )
  )
)

(define-public (process-claim (claim-id uint))
  (let
    (
      (claim-data (unwrap! (map-get? claims { claim-id: claim-id }) ERR_CLAIM_NOT_FOUND))
      (policy-data (unwrap! (map-get? policies { policy-id: (get policy-id claim-data) }) ERR_INVALID_CLAIM))
      (current-total (default-to { total-claimed: u0 } (map-get? policy-claims-total { policy-id: (get policy-id claim-data) })))
      (claim-amount (get amount claim-data))
      (deductible (get deductible policy-data))
      (coverage-limit (get coverage-limit policy-data))
      (payout-amount (if (> claim-amount deductible) (- claim-amount deductible) u0))
      (new-total (+ (get total-claimed current-total) payout-amount))
    )
    (asserts! (get verified claim-data) ERR_INVALID_CLAIM)
    (asserts! (is-eq (get status claim-data) "verified") ERR_INVALID_CLAIM)
    (asserts! (<= (+ stacks-block-height CLAIM_EXPIRY_BLOCKS) (get submitted-block claim-data)) ERR_CLAIM_EXPIRED)
    (asserts! (<= new-total coverage-limit) ERR_CLAIM_AMOUNT_EXCEEDED)
    (asserts! (>= (var-get contract-balance) payout-amount) ERR_INSUFFICIENT_FUNDS)
    
    (map-set claims
      { claim-id: claim-id }
      (merge claim-data { status: "paid" })
    )
    
    (map-set policy-claims-total
      { policy-id: (get policy-id claim-data) }
      { total-claimed: new-total }
    )
    
    (var-set total-paid (+ (var-get total-paid) payout-amount))
    (var-set contract-balance (- (var-get contract-balance) payout-amount))
    
    (as-contract (stx-transfer? payout-amount tx-sender (get claimant claim-data)))
  )
)

(define-public (fund-contract (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set contract-balance (+ (var-get contract-balance) amount))
    (ok true)
  )
)

(define-public (update-fraud-score (provider principal) (new-score uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? medical-providers { provider: provider })
      provider-data
      (begin
        (map-set medical-providers
          { provider: provider }
          (merge provider-data { fraud-score: new-score })
        )
        (ok true)
      )
      ERR_INVALID_PROVIDER
    )
  )
)

(define-public (deactivate-policy (policy-id uint))
  (let
    (
      (policy-data (unwrap! (map-get? policies { policy-id: policy-id }) ERR_INVALID_CLAIM))
    )
    (asserts! (is-eq tx-sender (get holder policy-data)) ERR_UNAUTHORIZED)
    (map-set policies
      { policy-id: policy-id }
      (merge policy-data { active: false })
    )
    (ok true)
  )
)

(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (>= (var-get contract-balance) amount) ERR_INSUFFICIENT_FUNDS)
    (var-set contract-balance (- (var-get contract-balance) amount))
    (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER))
  )
)

(define-read-only (get-policy (policy-id uint))
  (map-get? policies { policy-id: policy-id })
)

(define-read-only (get-claim (claim-id uint))
  (map-get? claims { claim-id: claim-id })
)

(define-read-only (get-provider (provider principal))
  (map-get? medical-providers { provider: provider })
)

(define-read-only (get-contract-stats)
  {
    total-claims: (var-get claim-counter),
    total-paid: (var-get total-paid),
    contract-balance: (var-get contract-balance),
    total-appeals: (var-get appeal-counter),
    appeal-fees-collected: (var-get appeal-fees-collected)
  }
)

(define-read-only (get-user-claims-count (user principal))
  (default-to { count: u0 } (map-get? user-claims-count { user: user }))
)

(define-read-only (get-policy-usage (policy-id uint))
  (default-to { total-claimed: u0 } (map-get? policy-claims-total { policy-id: policy-id }))
)

(define-read-only (is-claim-valid (claim-id uint))
  (match (map-get? claims { claim-id: claim-id })
    claim-data
    (let
      (
        (policy-data (unwrap! (map-get? policies { policy-id: (get policy-id claim-data) }) false))
        (provider-data (unwrap! (map-get? medical-providers { provider: (get provider claim-data) }) false))
      )
      (and
        (get active policy-data)
        (get verified provider-data)
        (get verified claim-data)
        (< (get fraud-score provider-data) FRAUD_THRESHOLD)
        (>= (get expiry-block policy-data) stacks-block-height)
      )
    )
    false
  )
)

(define-read-only (calculate-payout (claim-id uint))
  (match (map-get? claims { claim-id: claim-id })
    claim-data
    (match (map-get? policies { policy-id: (get policy-id claim-data) })
      policy-data
      (let
        (
          (claim-amount (get amount claim-data))
          (deductible (get deductible policy-data))
          (current-total (default-to { total-claimed: u0 } (map-get? policy-claims-total { policy-id: (get policy-id claim-data) })))
          (coverage-limit (get coverage-limit policy-data))
          (payout-amount (if (> claim-amount deductible) (- claim-amount deductible) u0))
          (remaining-coverage (- coverage-limit (get total-claimed current-total)))
        )
        (ok (if (<= payout-amount remaining-coverage) payout-amount remaining-coverage))
      )
      (err u404)
    )
    (err u404)
  )
)

(define-read-only (get-claim-status (claim-id uint))
  (match (map-get? claims { claim-id: claim-id })
    claim-data (ok (get status claim-data))
    ERR_CLAIM_NOT_FOUND
  )
)

(define-private (is-policy-holder (policy-id uint) (user principal))
  (match (map-get? policies { policy-id: policy-id })
    policy-data (is-eq user (get holder policy-data))
    false
  )
)

(define-private (validate-claim-timing (claim-data (tuple (policy-id uint) (claimant principal) (provider principal) (amount uint) (diagnosis-code (string-ascii 20)) (treatment-date uint) (submitted-block uint) (status (string-ascii 20)) (verified bool))))
  (let
    (
      (submission-block (get submitted-block claim-data))
      (current-block stacks-block-height)
    )
    (<= (- current-block submission-block) CLAIM_EXPIRY_BLOCKS)
  )
)

(define-private (check-fraud-indicators (provider principal) (amount uint))
  (match (map-get? medical-providers { provider: provider })
    provider-data
    (let
      (
        (fraud-score (get fraud-score provider-data))
        (amount-risk (if (> amount u50000000) u2 (if (> amount u25000000) u1 u0)))
      )
      (< (+ fraud-score amount-risk) FRAUD_THRESHOLD)
    )
    false
  )
)

(define-public (batch-process-claims (claim-ids (list 20 uint)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map process-single-claim claim-ids))
  )
)

(define-private (process-single-claim (claim-id uint))
  (match (process-claim claim-id)
    success true
    error false
  )
)

(define-public (update-policy-status (policy-id uint) (active bool))
  (let
    (
      (policy-data (unwrap! (map-get? policies { policy-id: policy-id }) ERR_INVALID_CLAIM))
    )
    (asserts! (is-eq tx-sender (get holder policy-data)) ERR_UNAUTHORIZED)
    (map-set policies
      { policy-id: policy-id }
      (merge policy-data { active: active })
    )
    (ok true)
  )
)

(define-public (extend-policy (policy-id uint) (additional-blocks uint))
  (let
    (
      (policy-data (unwrap! (map-get? policies { policy-id: policy-id }) ERR_INVALID_CLAIM))
    )
    (asserts! (is-eq tx-sender (get holder policy-data)) ERR_UNAUTHORIZED)
    (map-set policies
      { policy-id: policy-id }
      (merge policy-data { expiry-block: (+ (get expiry-block policy-data) additional-blocks) })
    )
    (ok true)
  )
)

(define-public (submit-appeal (claim-id uint))
  (let
    (
      (claim-data (unwrap! (map-get? claims { claim-id: claim-id }) ERR_CLAIM_NOT_FOUND))
      (policy-data (unwrap! (map-get? policies { policy-id: (get policy-id claim-data) }) ERR_INVALID_CLAIM))
      (appeal-id (+ (var-get appeal-counter) u1))
      (existing-appeal (map-get? claim-appeals { claim-id: claim-id }))
    )
    (asserts! (is-eq tx-sender (get claimant claim-data)) ERR_UNAUTHORIZED)
    (asserts! (or (is-eq (get status claim-data) "paid") (is-eq (get status claim-data) "verified")) ERR_INVALID_CLAIM)
    (asserts! (is-none existing-appeal) ERR_APPEAL_ALREADY_EXISTS)
    
    (try! (stx-transfer? APPEAL_FEE tx-sender (as-contract tx-sender)))
    
    (map-set appeals
      { appeal-id: appeal-id }
      {
        claim-id: claim-id,
        appellant: tx-sender,
        appeal-fee: APPEAL_FEE,
        submitted-block: stacks-block-height,
        status: "pending",
        reviewer: none,
        reviewed-block: none,
        additional-payout: u0
      }
    )
    
    (map-set claim-appeals
      { claim-id: claim-id }
      { appeal-id: appeal-id }
    )
    
    (var-set appeal-counter appeal-id)
    (var-set appeal-fees-collected (+ (var-get appeal-fees-collected) APPEAL_FEE))
    (ok appeal-id)
  )
)

(define-public (review-appeal (appeal-id uint) (approved bool) (additional-payout uint))
  (let
    (
      (appeal-data (unwrap! (map-get? appeals { appeal-id: appeal-id }) ERR_APPEAL_NOT_FOUND))
      (blocks-elapsed (- stacks-block-height (get submitted-block appeal-data)))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status appeal-data) "pending") ERR_APPEAL_NOT_REVIEWABLE)
    (asserts! (<= blocks-elapsed APPEAL_REVIEW_BLOCKS) ERR_APPEAL_EXPIRED)
    
    (map-set appeals
      { appeal-id: appeal-id }
      (merge appeal-data {
        status: (if approved "approved" "rejected"),
        reviewer: (some tx-sender),
        reviewed-block: (some stacks-block-height),
        additional-payout: (if approved additional-payout u0)
      })
    )
    
    (if approved
      (begin
        (var-set contract-balance (- (var-get contract-balance) additional-payout))
        (as-contract (stx-transfer? additional-payout tx-sender (get appellant appeal-data)))
      )
      (ok true)
    )
  )
)

(define-public (finalize-appeal (appeal-id uint))
  (let
    (
      (appeal-data (unwrap! (map-get? appeals { appeal-id: appeal-id }) ERR_APPEAL_NOT_FOUND))
      (blocks-elapsed (- stacks-block-height (get submitted-block appeal-data)))
      (claim-data (unwrap! (map-get? claims { claim-id: (get claim-id appeal-data) }) ERR_CLAIM_NOT_FOUND))
      (refund-amount (get appeal-fee appeal-data))
    )
    (asserts! (is-eq (get status appeal-data) "pending") ERR_APPEAL_NOT_REVIEWABLE)
    (asserts! (> blocks-elapsed APPEAL_REVIEW_BLOCKS) ERR_APPEAL_NOT_REVIEWABLE)
    
    (map-set appeals
      { appeal-id: appeal-id }
      (merge appeal-data {
        status: "auto-approved",
        reviewer: none,
        reviewed-block: (some stacks-block-height),
        additional-payout: refund-amount
      })
    )
    
    (var-set contract-balance (- (var-get contract-balance) refund-amount))
    (as-contract (stx-transfer? refund-amount tx-sender (get appellant appeal-data)))
  )
)

(define-public (withdraw-appeal-fees)
  (let
    (
      (fees-amount (var-get appeal-fees-collected))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> fees-amount u0) ERR_INSUFFICIENT_FUNDS)
    
    (var-set appeal-fees-collected u0)
    (as-contract (stx-transfer? fees-amount tx-sender CONTRACT_OWNER))
  )
)

(define-read-only (get-active-policies-count)
  (let
    (
      (policy-count (var-get claim-counter))
    )
    (fold check-active-policy (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) u0)
  )
)

(define-private (check-active-policy (policy-id uint) (count uint))
  (match (map-get? policies { policy-id: policy-id })
    policy-data
    (if (get active policy-data) (+ count u1) count)
    count
  )
)

(define-read-only (get-provider-stats (provider principal))
  (match (map-get? medical-providers { provider: provider })
    provider-data
    (ok {
      name: (get name provider-data),
      verified: (get verified provider-data),
      fraud-score: (get fraud-score provider-data),
      claims-processed: u0
    })
    ERR_INVALID_PROVIDER
  )
)

(define-read-only (get-appeal (appeal-id uint))
  (map-get? appeals { appeal-id: appeal-id })
)

(define-read-only (get-claim-appeal (claim-id uint))
  (map-get? claim-appeals { claim-id: claim-id })
)

(define-read-only (get-appeal-stats)
  {
    total-appeals: (var-get appeal-counter),
    fees-collected: (var-get appeal-fees-collected)
  }
)

(define-read-only (is-appeal-expired (appeal-id uint))
  (match (map-get? appeals { appeal-id: appeal-id })
    appeal-data
    (let
      (
        (blocks-elapsed (- stacks-block-height (get submitted-block appeal-data)))
      )
      (> blocks-elapsed APPEAL_REVIEW_BLOCKS)
    )
    false
  )
)
