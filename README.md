# ArcPayLink

ArcPayLink is a stablecoin-native payment request dApp for Arc Testnet. Users create a request with a recipient, amount, title, and memo; another wallet settles it using Arc's native USDC gas token.

## Features

- Create transparent payment requests
- Exact-amount settlement in native testnet USDC
- Direct forwarding to the recipient
- Creator-controlled cancellation
- Double-payment protection and reentrancy guard
- Onchain events and readable request state
- Mobile-friendly static frontend
- One-command phone/Codespaces deployment

## Fast deployment from a phone

1. Open this repository in GitHub Codespaces.
2. In the terminal, run:

```bash
bash scripts/start-phone.sh
```

3. When the script shows a testnet wallet address, open the Circle Faucet, select **Arc Testnet**, request test USDC, return to the terminal, and press Enter.

The script builds and tests the contract, deploys it, attempts verification, creates and pays a demo request, updates the frontend configuration, writes `DEPLOYMENT.md` and `SUBMISSION.md`, and pushes non-secret files to GitHub.

## Network

- Network: Arc Testnet
- Chain ID: `5042002`
- RPC: `https://rpc.testnet.arc.network`
- Native currency: USDC (18 decimals)
- Explorer: `https://testnet.arcscan.app`

## Security

The generated `.wallet.env` is for testnet only and is excluded by `.gitignore`. Never send real assets to the generated wallet and never publish its private key.

## Contract interface

- `createRequest(recipient, amount, title, memo)`
- `payRequest(requestId)`
- `cancelRequest(requestId)`
- `getRequest(requestId)`
- `nextRequestId()`

## Frontend

The static dApp is in `web/`. After deployment, enable GitHub Pages with **GitHub Actions** as the source. The included workflow publishes the site automatically.

## License

MIT
