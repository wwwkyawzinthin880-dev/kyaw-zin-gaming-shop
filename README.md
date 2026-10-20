# KYAW ZIN Gaming Shop

Next.js starter for a THB-only MLBB diamond shop.

## Business rules
- 1 THB = 1 COIN.
- Customer submits a wallet top-up request and receipt.
- Owner verifies the actual bank transfer before approving the request.
- Customer chooses a package and enters MLBB User ID + Zone ID.
- Server-side supplier API fulfills the order and returns a status.

## Current status: UI preview only
The customer storefront and separate owner dashboard pages are committed, but they are not live transaction software yet. Top-up requests are not persisted, owner authentication is not configured, wallet credits are not enabled, and no supplier API is connected. Do not accept real funds through this preview.

## Database starter
- supabase/schema.sql defines profiles, wallets, top-up requests, ledger entries, orders and initial Row Level Security policies.
- Configure a Supabase project and apply the schema in a staging project first.
- Assign the owner role securely from the server/database; never allow a customer to self-promote.
- Implement atomic server-side approval RPCs that lock the request, reject duplicate approval, and update wallet + ledger in one transaction.
- Add authenticated server-side order routes that reserve/debit COIN atomically and handle supplier failures/refunds.
- Configure private receipt storage and authorization checks.

## Environment
Copy .env.example to .env.local and fill values only after creating the corresponding services. Do not commit real secrets. Supplier API keys and the Supabase service-role key must stay server-side.

## Local development
Node.js 20+
- npm install
- npm run dev

Routes:
- / customer storefront preview
- /owner owner dashboard preview (not protected yet)

Before production, test login and role authorization, duplicate approvals, insufficient balance, failed supplier deliveries, refunds, rate limiting, and audit logging.
