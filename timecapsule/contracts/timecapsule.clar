;; TimeCapsule - Decentralized Time-Locked Asset Vault
;; A secure way to lock STX and fungible tokens with enhanced beneficiary system

(define-data-var contract-owner principal tx-sender)

;; Constants for validation
(define-constant MIN-LOCK-PERIOD u144) ;; Minimum 1 day (assuming 144 blocks per day)
(define-constant MAX-LOCK-PERIOD u52560) ;; Maximum 1 year
(define-constant MIN-GRACE-PERIOD u144) ;; Minimum 1 day grace period
(define-constant DEFAULT-GRACE-PERIOD u4320) ;; Default 30 days grace period

;; Beneficiary Status
(define-constant BENEFICIARY-ACTIVE u1)
(define-constant BENEFICIARY-PENDING u2)
(define-constant BENEFICIARY-INACTIVE u0)

;; Vault structure
(define-map vaults
    { owner: principal }
    {
        amount: uint,
        unlock-height: uint,
        lock-duration: uint,
        beneficiary: (optional principal),
        beneficiary-status: uint,
        grace-period: uint,
        last-activity: uint,
        token-type: (string-ascii 32)
    }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NO-VAULT (err u101))
(define-constant ERR-VAULT-EXISTS (err u102))
(define-constant ERR-NOT-UNLOCKED (err u103))
(define-constant ERR-GRACE-PERIOD-EXPIRED (err u104))
(define-constant ERR-INSUFFICIENT-FUNDS (err u105))
(define-constant ERR-INVALID-LOCK-PERIOD (err u106))
(define-constant ERR-EXTENSION-TOO-SHORT (err u107))
(define-constant ERR-INVALID-BENEFICIARY (err u108))
(define-constant ERR-NO-BENEFICIARY (err u109))
(define-constant ERR-BENEFICIARY-NOT-ACTIVE (err u110))

;; Read-only functions
(define-read-only (get-vault-details (owner principal))
    (map-get? vaults { owner: owner })
)

(define-read-only (is-unlocked (owner principal))
    (let (
        (vault (unwrap! (get-vault-details owner) false))
        (current-height block-height)
    )
    (>= current-height (get unlock-height vault)))
)

(define-read-only (get-remaining-lock-time (owner principal))
    (let (
        (vault (unwrap! (get-vault-details owner) u0))
        (current-height block-height)
    )
    (if (>= current-height (get unlock-height vault))
        u0
        (- (get unlock-height vault) current-height)))
)

(define-read-only (can-claim-as-beneficiary (owner principal) (beneficiary principal))
    (let (
        (vault (unwrap! (get-vault-details owner) false))
        (current-height block-height)
        (grace-end (+ (get unlock-height vault) (get grace-period vault)))
        (inactive-period (- current-height (get last-activity vault)))
    )
    (and
        (is-eq (some beneficiary) (get beneficiary vault))
        (is-eq (get beneficiary-status vault) BENEFICIARY-ACTIVE)
        (or 
            (>= current-height grace-end)
            (>= inactive-period (get grace-period vault))
        )
    ))
)

;; Public functions
(define-public (create-vault (lock-duration uint) (beneficiary (optional principal)) (grace-period uint))
    (let (
        (unlock-height (+ block-height lock-duration))
        (actual-grace-period (if (< grace-period MIN-GRACE-PERIOD) 
                                DEFAULT-GRACE-PERIOD 
                                grace-period))
    )
    (asserts! (is-none (get-vault-details tx-sender)) ERR-VAULT-EXISTS)
    (asserts! (and (>= lock-duration MIN-LOCK-PERIOD) (<= lock-duration MAX-LOCK-PERIOD)) ERR-INVALID-LOCK-PERIOD)
    
    (map-set vaults
        { owner: tx-sender }
        {
            amount: u0,
            unlock-height: unlock-height,
            lock-duration: lock-duration,
            beneficiary: beneficiary,
            beneficiary-status: (if (is-some beneficiary) BENEFICIARY-ACTIVE BENEFICIARY-INACTIVE),
            grace-period: actual-grace-period,
            last-activity: block-height,
            token-type: "STX"
        }
    )
    (ok true))
)

(define-public (extend-lock-period (extension-blocks uint))
    (let (
        (vault (unwrap! (get-vault-details tx-sender) ERR-NO-VAULT))
        (current-height block-height)
        (new-unlock-height (+ (get unlock-height vault) extension-blocks))
        (new-duration (+ (get lock-duration vault) extension-blocks))
    )
    (asserts! (>= extension-blocks MIN-LOCK-PERIOD) ERR-EXTENSION-TOO-SHORT)
    (asserts! (<= new-duration MAX-LOCK-PERIOD) ERR-INVALID-LOCK-PERIOD)
    
    (map-set vaults
        { owner: tx-sender }
        (merge vault {
            unlock-height: new-unlock-height,
            lock-duration: new-duration,
            last-activity: block-height
        })
    )
    (ok true))
)

(define-public (update-beneficiary (new-beneficiary (optional principal)))
    (let (
        (vault (unwrap! (get-vault-details tx-sender) ERR-NO-VAULT))
    )
    (map-set vaults
        { owner: tx-sender }
        (merge vault {
            beneficiary: new-beneficiary,
            beneficiary-status: (if (is-some new-beneficiary) BENEFICIARY-ACTIVE BENEFICIARY-INACTIVE),
            last-activity: block-height
        })
    )
    (ok true))
)

(define-public (deposit-stx (amount uint))
    (let (
        (vault (unwrap! (get-vault-details tx-sender) ERR-NO-VAULT))
    )
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set vaults
        { owner: tx-sender }
        (merge vault {
            amount: (+ (get amount vault) amount),
            last-activity: block-height
        })
    )
    (ok true))
)

(define-public (withdraw-stx (amount uint))
    (let (
        (vault (unwrap! (get-vault-details tx-sender) ERR-NO-VAULT))
        (current-height block-height)
    )
    (asserts! (>= current-height (get unlock-height vault)) ERR-NOT-UNLOCKED)
    (asserts! (<= amount (get amount vault)) ERR-INSUFFICIENT-FUNDS)
    
    (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
    (map-set vaults
        { owner: tx-sender }
        (merge vault {
            amount: (- (get amount vault) amount),
            last-activity: block-height
        })
    )
    (ok true))
)

(define-public (claim-as-beneficiary (owner principal))
    (let (
        (vault (unwrap! (get-vault-details owner) ERR-NO-VAULT))
        (current-height block-height)
        (grace-end (+ (get unlock-height vault) (get grace-period vault)))
        (inactive-period (- current-height (get last-activity vault)))
    )
    ;; Verify beneficiary status and conditions
    (asserts! (is-some (get beneficiary vault)) ERR-NO-BENEFICIARY)
    (asserts! (is-eq (some tx-sender) (get beneficiary vault)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get beneficiary-status vault) BENEFICIARY-ACTIVE) ERR-BENEFICIARY-NOT-ACTIVE)
    (asserts! (or 
        (>= current-height grace-end)
        (>= inactive-period (get grace-period vault))
    ) ERR-NOT-UNLOCKED)
    
    ;; Transfer funds and close vault
    (try! (as-contract (stx-transfer? (get amount vault) (as-contract tx-sender) tx-sender)))
    (map-delete vaults { owner: owner })
    (ok true))
)

(define-public (ping)
    (let (
        (vault (unwrap! (get-vault-details tx-sender) ERR-NO-VAULT))
    )
    (map-set vaults
        { owner: tx-sender }
        (merge vault { last-activity: block-height })
    )
    (ok true))
)