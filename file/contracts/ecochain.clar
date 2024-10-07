;; EcoChain Waste Management Smart Contract
;; Version 1.0

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-amount (err u101))

;; Data Variables
(define-data-var total-waste-tracked uint u0)

;; Data Maps
(define-map user-recycling-stats
    principal
    {
        total-recycled: uint,
        eco-tokens: uint
    })

;; Token definitions
(define-fungible-token eco-token)

;; Public functions
(define-public (record-waste-disposal (amount uint))
    (let
        ((current-user tx-sender)
         (user-stats (default-to
            {total-recycled: u0, eco-tokens: u0}
            (map-get? user-recycling-stats current-user))))
        (if (> amount u0)
            (begin
                (map-set user-recycling-stats
                    current-user
                    {
                        total-recycled: (+ (get total-recycled user-stats) amount),
                        eco-tokens: (+ (get eco-tokens user-stats) (calculate-reward amount))
                    })
                (var-set total-waste-tracked (+ (var-get total-waste-tracked) amount))
                (ft-mint? eco-token (calculate-reward amount) current-user)
                (ok true))
            err-invalid-amount)))

;; Read-only functions
(define-read-only (get-user-stats (user principal))
    (ok (default-to
        {total-recycled: u0, eco-tokens: u0}
        (map-get? user-recycling-stats user))))

(define-read-only (get-total-waste-tracked)
    (ok (var-get total-waste-tracked)))

;; Private functions
(define-private (calculate-reward (amount uint))
    ;; Simple reward calculation: 1 token per 10 units of waste
    (/ amount u10))

;; Initialize contract
(begin
    (ft-mint? eco-token u1000000 contract-owner))