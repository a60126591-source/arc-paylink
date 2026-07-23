# ArcPayLink — 60-second Office Hours pitch

Hi, I built ArcPayLink, a lightweight payment-request application on Arc Testnet.

A user creates an onchain request with a recipient, a USDC amount, a short title, and a memo. Another user can inspect and settle that request. The smart contract enforces the exact amount, prevents double payment, supports cancellation, forwards funds directly to the recipient, and emits auditable events.

I chose Arc because its native USDC gas model makes the user experience easier to explain: payment value and transaction fees are both dollar-denominated. The current prototype includes a verified Solidity contract, automated tests, a mobile-friendly web interface, and a live paid demo request.

The next features I am considering are expiring requests, partial payments, reusable merchant links, and simple payment analytics. I would appreciate feedback on which direction is most useful for the Arc ecosystem.
