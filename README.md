# IAPTest — Sandbox SK1 Receipt Generator

Minimal SwiftUI app that performs an SK1 (StoreKit 1) sandbox in-app purchase
and dumps the base64 receipt for forensic analysis.

Used to verify the "SK1 sandbox receipt hijack" attack on apps that don't
strictly check `bundle_id` in the PKCS#7 receipt.

## Setup (one-time)

### 1. Push to your own GitHub repo

```bash
cd iaptest
git init
git add .
git commit -m "init"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/iaptest.git
git push -u origin main
```

### 2. Add GitHub Secrets

Go to repo → **Settings → Secrets and variables → Actions → New repository secret**.
Add these 6 secrets:

| Name | Value |
|---|---|
| `ASC_KEY_P8` | Full content of `AuthKey_xxx.p8` file (paste the entire text including BEGIN/END lines) |
| `ASC_KEY_ID` | The Key ID shown next to the .p8 (e.g. `ABC123XYZ4`) |
| `ASC_ISSUER_ID` | The Issuer ID shown at the top of ASC API Keys page (UUID format) |
| `DEVELOPMENT_TEAM` | Your 10-char Team ID (visible in developer.apple.com → Membership) |
| `BUNDLE_ID` | Your bundle ID (e.g. `com.yourname.iaptest`) — must already be created in Identifiers |
| `BUNDLE_PREFIX` | Prefix part (e.g. `com.yourname`) |

### 3. Run the workflow

- Go to **Actions** tab on GitHub
- Click "Build IAPTest IPA" workflow
- Click **Run workflow** → main branch → Run

After ~3-5 minutes, the workflow finishes. Download `IAPTest-IPA` artifact.

### 4. Install the IPA on iPhone

Use TrollStore (since you already have it):
- AirDrop / file-share IPA to iPhone
- Files app → tap IPA → Share → TrollStore → Install

### 5. Run the app + perform sandbox purchase

1. Tap IAPTest icon
2. Tap **Fetch Product**
   - If state shows "ready" + product info → all good
   - If "INVALID" → ASC config issue, check IAP product status + paid agreement
3. Tap **Buy**
   - iOS will prompt sandbox login dialog (first time)
   - Use your ASC sandbox tester credentials
   - Confirm "purchase" (no real money charged in sandbox)
4. Receipt base64 appears at bottom of screen
5. Tap **Copy Base64 Receipt** → paste it somewhere to save

## Notes

- The app uses SK1 (`SKProductsRequest` + `SKPaymentQueue`), not SK2.
- The receipt is the standard ASN.1 PKCS#7 sandbox receipt blob (~5-10 KB base64).
- Field `environment` inside the decoded receipt will be `Sandbox`.
- The receipt's `bundle_id` field will be your bundle ID (NOT `com.openai.chat`).
- This is what allows verifying whether RevenueCat / app server check `bundle_id` strictly.
