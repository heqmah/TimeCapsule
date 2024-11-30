;; TimeCapsule - Decentralized Time-Locked Asset Vault
;; A secure way to lock STX and fungible tokens with time-based release and beneficiary support

(define-data-var contract-owner principal tx-sender)

;; Vault structure
(define-map vaults
    { owner: principal }
    {
        amount: uint,
        unlock-height: uint,
        beneficiary: (optional principal),
        grace-period: uint,
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

;; Public functions
(define-public (create-vault (lock-period uint) (beneficiary (optional principal)) (grace-period uint))
    (let (
        (unlock-height (+ block-height lock-period))
    )
    (asserts! (is-none (get-vault-details tx-sender)) ERR-VAULT-EXISTS)
    (map-set vaults
        { owner: tx-sender }
        {
            amount: u0,
            unlock-height: unlock-height,
            beneficiary: beneficiary,
            grace-period: grace-period,
            token-type: "STX"
        }
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
        (merge vault { amount: (+ (get amount vault) amount) })
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
        (merge vault { amount: (- (get amount vault) amount) })
    )
    (ok true))
)

(define-public (claim-as-beneficiary (owner principal))
    (let (
        (vault (unwrap! (get-vault-details owner) ERR-NO-VAULT))
        (current-height block-height)
        (grace-end (+ (get unlock-height vault) (get grace-period vault)))
    )
    (asserts! (>= current-height grace-end) ERR-NOT-UNLOCKED)
    (asserts! (is-some (get beneficiary vault)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (some tx-sender) (get beneficiary vault)) ERR-NOT-AUTHORIZED)
    
    (try! (as-contract (stx-transfer? (get amount vault) (as-contract tx-sender) tx-sender)))
    (map-delete vaults { owner: owner })
    (ok true))
)

;; Administrative functions
(define-public (update-beneficiary (new-beneficiary (optional principal)))
    (let (
        (vault (unwrap! (get-vault-details tx-sender) ERR-NO-VAULT))
    )
    (map-set vaults
        { owner: tx-sender }
        (merge vault { beneficiary: new-beneficiary })
    )
    (ok true))
)