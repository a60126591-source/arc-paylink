#!/usr/bin/env bash
set -euo pipefail

RPC_URL="https://rpc.testnet.arc.network"
CHAIN_ID="5042002"
EXPLORER="https://testnet.arcscan.app"
FAUCET="https://faucet.circle.com"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bold='\033[1m'
green='\033[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
reset='\033[0m'

step() { printf "\n${bold}%s${reset}\n" "$1"; }
fail() { printf "${red}%s${reset}\n" "$1" >&2; exit 1; }

step "1/8 — Installing Foundry (only if needed)"
if ! command -v forge >/dev/null 2>&1; then
  curl -L https://foundry.paradigm.xyz | bash
  export PATH="$HOME/.foundry/bin:$PATH"
  "$HOME/.foundry/bin/foundryup"
else
  printf "Foundry is already installed.\n"
fi
export PATH="$HOME/.foundry/bin:$PATH"

step "2/8 — Building and testing ArcPayLink"
forge test

step "3/8 — Preparing a fresh TESTNET-ONLY wallet"
if [[ ! -f .wallet.env ]]; then
  WALLET_OUTPUT="$(cast wallet new)"
  ADDRESS="$(printf '%s\n' "$WALLET_OUTPUT" | sed -nE 's/^[[:space:]]*Address:[[:space:]]*(0x[0-9a-fA-F]{40}).*/\1/p' | head -n1)"
  PRIVATE_KEY="$(printf '%s\n' "$WALLET_OUTPUT" | sed -nE 's/^[[:space:]]*Private key:[[:space:]]*(0x[0-9a-fA-F]{64}).*/\1/p' | head -n1)"
  [[ -n "$ADDRESS" && -n "$PRIVATE_KEY" ]] || fail "Could not parse the new wallet. Run 'cast wallet new' manually and contact support."
  umask 077
  cat > .wallet.env <<ENV
WALLET_ADDRESS="$ADDRESS"
PRIVATE_KEY="$PRIVATE_KEY"
ENV
else
  # shellcheck disable=SC1091
  source .wallet.env
  ADDRESS="$WALLET_ADDRESS"
fi
# shellcheck disable=SC1091
source .wallet.env

printf "\n${yellow}TESTNET wallet address:${reset}\n%s\n" "$WALLET_ADDRESS"
printf "\nOpen the Circle Faucet, select Arc Testnet, paste this address, and request test USDC:\n%s\n" "$FAUCET"
printf "\n${bold}Never send real funds to this wallet. Never share .wallet.env.${reset}\n"
read -r -p "After the faucet confirms the transfer, return here and press Enter... "

step "4/8 — Checking faucet balance"
BALANCE_WEI="$(cast balance "$WALLET_ADDRESS" --rpc-url "$RPC_URL")"
if [[ "$BALANCE_WEI" == "0" ]]; then
  fail "No balance found yet. Wait about 30 seconds, then run: bash scripts/start-phone.sh"
fi
BALANCE_USDC="$(cast from-wei "$BALANCE_WEI" ether)"
printf "Balance: %s USDC (native test token)\n" "$BALANCE_USDC"

step "5/8 — Deploying ArcPayLink to Arc Testnet"
DEPLOY_OUTPUT="$(forge create src/ArcPayLink.sol:ArcPayLink \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast 2>&1 | tee /dev/stderr)"

CONTRACT_ADDRESS="$(printf '%s\n' "$DEPLOY_OUTPUT" | sed -nE 's/^[[:space:]]*Deployed to:[[:space:]]*(0x[0-9a-fA-F]{40}).*/\1/p' | tail -n1)"
DEPLOY_TX="$(printf '%s\n' "$DEPLOY_OUTPUT" | sed -nE 's/^[[:space:]]*Transaction hash:[[:space:]]*(0x[0-9a-fA-F]{64}).*/\1/p' | tail -n1)"
[[ -n "$CONTRACT_ADDRESS" ]] || fail "Deployment output did not include a contract address."

cat > .env <<ENV
ARC_TESTNET_RPC_URL="$RPC_URL"
CONTRACT_ADDRESS="$CONTRACT_ADDRESS"
DEPLOY_TX="$DEPLOY_TX"
ENV

step "6/8 — Verifying source code on ArcScan"
set +e
forge verify-contract "$CONTRACT_ADDRESS" src/ArcPayLink.sol:ArcPayLink \
  --chain-id "$CHAIN_ID" \
  --verifier blockscout \
  --verifier-url "$EXPLORER/api/"
VERIFY_STATUS=$?
set -e
if [[ $VERIFY_STATUS -ne 0 ]]; then
  printf "${yellow}Verification was not confirmed immediately. The deployment is still valid; retry later with:${reset}\n"
  printf "forge verify-contract %s src/ArcPayLink.sol:ArcPayLink --chain-id %s --verifier blockscout --verifier-url %s/api/\n" "$CONTRACT_ADDRESS" "$CHAIN_ID" "$EXPLORER"
fi

step "7/8 — Creating and paying one demo request"
DEMO_AMOUNT="100000000000000000"
cast send "$CONTRACT_ADDRESS" \
  "createRequest(address,uint256,string,string)" \
  "$WALLET_ADDRESS" "$DEMO_AMOUNT" \
  "ArcPayLink demo" \
  "First payment request created on Arc Testnet" \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" >/dev/null

cast send "$CONTRACT_ADDRESS" \
  "payRequest(uint256)" 0 \
  --value "$DEMO_AMOUNT" \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" >/dev/null

cat > web/config.js <<CONFIG
window.ARCPAYLINK_CONFIG = {
  contractAddress: "$CONTRACT_ADDRESS",
  chainId: 5042002,
  rpcUrl: "$RPC_URL",
  explorerUrl: "$EXPLORER"
};
CONFIG

cat > DEPLOYMENT.md <<DEPLOYMENT
# ArcPayLink Deployment

- Network: Arc Testnet
- Chain ID: 5042002
- Contract: $CONTRACT_ADDRESS
- Deployment transaction: $DEPLOY_TX
- Explorer: $EXPLORER/address/$CONTRACT_ADDRESS
- Deployer: $WALLET_ADDRESS
- Demo request ID: 0 (created and paid)
DEPLOYMENT

cat > SUBMISSION.md <<SUBMISSION
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
$EXPLORER/address/$CONTRACT_ADDRESS

## Deployment transaction
$EXPLORER/tx/$DEPLOY_TX

## Demo state
Payment request ID 0 was created and paid on Arc Testnet.

## Feedback requested
Feedback on product direction, payment-request UX, and useful extensions such as expirations, partial payments, reusable links, and merchant analytics.
SUBMISSION

step "8/8 — Saving the deployment to GitHub"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git config user.name "${GITHUB_USER:-ArcPayLink Builder}" || true
  git config user.email "${GITHUB_USER:-builder}@users.noreply.github.com" || true
  git add .
  if ! git diff --cached --quiet; then
    git commit -m "Deploy ArcPayLink on Arc Testnet" || true
  fi
  if git remote get-url origin >/dev/null 2>&1; then
    git push || printf "${yellow}Automatic push did not work. Run 'git push' manually.${reset}\n"
  fi
fi

printf "\n${green}${bold}DONE${reset}\n"
printf "Contract: %s/address/%s\n" "$EXPLORER" "$CONTRACT_ADDRESS"
printf "Deployment: %s/tx/%s\n" "$EXPLORER" "$DEPLOY_TX"
printf "Submission text: SUBMISSION.md\n"
printf "Frontend folder: web/\n"
printf "\nKeep .wallet.env private. It is ignored by Git and is only for this testnet wallet.\n"
