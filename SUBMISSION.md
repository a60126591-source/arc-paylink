# Arc Office Hours Submission — ArcPayLink

## Project name
ArcPayLink

## One-line description
A lightweight onchain payment-request app that lets users create and settle USDC-denominated payment links directly on Arc Testnet.

## What it does
ArcPayLink creates transparent payment requests containing a recipient, amount, title, and memo. A payer settles the request using Arc's native USDC gas token. The smart contract prevents double payment, supports cancellation by the creator, forwards funds directly to the recipient, and emits auditable events.

## Why Arc
Arc's native USDC gas model makes payment flows easier to understand because both transaction fees and settlement value are dollar-denominated. ArcPayLink demonstrates a simple stablecoin-native payment primitive built directly around that model.

## Contract
https://testnet.arcscan.app/address/0xC281b0F1c9Bc32eee1cDE0f8603E57767052AA28

## Deployment transaction
https://testnet.arcscan.app/tx/0xa93b62ce1b1a696de50a5e5394affd20b5fb92290af725828103682e784bb1f4

## Demo state
Payment request ID 0 was created and paid on Arc Testnet.

## Feedback requested
Feedback on product direction, payment-request UX, and useful extensions such as expirations, partial payments, reusable links, and merchant analytics.
