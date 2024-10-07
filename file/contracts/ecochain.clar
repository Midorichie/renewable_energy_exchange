;; EcoChain Waste Management Smart Contract
;; Version 2.0

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-no-stake (err u102))

;; Data Variables
(define-data-var total-waste-tracked uint u0)
(define-data-var reward-rate uint u10)  ;; Adjustable reward rate

;; Data Maps
(define-map user-recycling-stats
    principal
    {
        total-recycled: uint,
        eco-tokens: uint,
        reputation-score: uint,
        last-recycling: uint,
        recycling-streak: uint
    })

(define-map waste-bins
    uint
    {
        location: (string-ascii 64),
        total-collected: uint,
        last-emptied: uint,
        bin-type: (string-ascii 16)
    })

;; Token definitions
(define-fungible-token eco-token)
(define-non-fungible-token recycler-badge uint)

;; Public functions
(define-public (record-waste-disposal (amount uint) (bin-id uint) (waste-type (string-ascii 16)))
    (let
        ((current-user tx-sender)
         (user-stats (default-to
            {total-recycled: u0, eco-tokens: u0, reputation-score: u0, last-recycling: u0, recycling-streak: u0}
            (map-get? user-recycling-stats current-user)))
         (current-time (get-current-time)))
        (if (> amount u0)
            (begin
                (try! (update-bin-stats bin-id amount))
                (try! (update-user-stats current-user amount current-time user-stats))
                (try! (process-rewards current-user amount waste-type user-stats))
                (ok true))
            err-invalid-amount)))

(define-public (stake-tokens (amount uint))
    (let ((current-user tx-sender))
        (try! (ft-transfer? eco-token amount current-user (as-contract tx-sender)))
        (ok true)))

;; Read-only functions
(define-read-only (get-user-stats (user principal))
    (ok (default-to
        {total-recycled: u0, eco-tokens: u0, reputation-score: u0, last-recycling: u0, recycling-streak: u0}
        (map-get? user-recycling-stats user))))

(define-read-only (get-bin-stats (bin-id uint))
    (ok (map-get? waste-bins bin-id)))

(define-read-only (get-total-waste-tracked)
    (ok (var-get total-waste-tracked)))

;; Private functions
(define-private (update-bin-stats (bin-id uint) (amount uint))
    (let ((bin (unwrap! (map-get? waste-bins bin-id) err-invalid-amount)))
        (map-set waste-bins
            bin-id
            (merge bin {
                total-collected: (+ (get total-collected bin) amount),
                last-emptied: (get-current-time)
            }))
        (ok true)))

(define-private (update-user-stats (user principal) (amount uint) (current-time uint) (old-stats {total-recycled: uint, eco-tokens: uint, reputation-score: uint, last-recycling: uint, recycling-streak: uint}))
    (let ((new-streak (if (< (- current-time (get last-recycling old-stats)) u86400)
                        (+ (get recycling-streak old-stats) u1)
                        u1)))
        (map-set user-recycling-stats
            user
            {
                total-recycled: (+ (get total-recycled old-stats) amount),
                eco-tokens: (get eco-tokens old-stats),
                reputation-score: (+ (get reputation-score old-stats) u1),
                last-recycling: current-time,
                recycling-streak: new-streak
            })
        (ok true)))

(define-private (process-rewards (user principal) (amount uint) (waste-type (string-ascii 16)) (user-stats {total-recycled: uint, eco-tokens: uint, reputation-score: uint, last-recycling: uint, recycling-streak: uint}))
    (let
        ((base-reward (/ amount (var-get reward-rate)))
         (streak-bonus (if (> (get recycling-streak user-stats) u5) u2 u1))
         (type-multiplier (get-waste-type-multiplier waste-type))
         (final-reward (* (* base-reward streak-bonus) type-multiplier)))
        (ft-mint? eco-token final-reward user)))

(define-private (get-waste-type-multiplier (waste-type (string-ascii 16)))
    (if (is-eq waste-type "hazardous")
        u3  ;; Higher reward for proper hazardous waste disposal
        u1))

(define-private (get-current-time)
    block-height)

;; Initialize contract
(begin
    (ft-mint? eco-token u1000000 contract-owner))