# Regulatory Submission Portal Example

This example demonstrates how to build a basic regulatory compliance portal using Ruby, Sinatra, and the Stripe SDK. It simulates workflows for:

- **Suspicious Activity Reports (SARs)**
- **Anti-Money Laundering (AML) Reviews**

The portal allows compliance officers to:
1.  **Review** flagged transactions (fetched from Stripe or mocked).
2.  **Digitally Sign** reports using RSA keys.
3.  **Export** finalized reports to XML (FinCEN/standard formats) and PDF.
4.  **Submit** reports to regulatory authorities (simulated API).

## Prerequisites

- Ruby 2.6+
- Bundler

## Setup

1.  Navigate to this directory:
    ```bash
    cd examples/regulatory_portal
    ```

2.  Install dependencies:
    ```bash
    bundle install
    ```

## Configuration

To fetch real data from a Stripe account, set your API key:

```bash
export STRIPE_SECRET_KEY=sk_test_...
```

If no key is provided, the application will use mock transaction data.

## Running the Portal

Start the Sinatra server:

```bash
ruby app.rb
```

Visit `http://localhost:4567` in your browser.

## Features

### 1. Dashboard
View all drafted, signed, and submitted reports.

### 2. Create Reports
- Click "New SAR" or "New AML Review".
- Select transactions to include in the report.
- Generate the draft.

### 3. Digital Signature
- Reports start in `DRAFT` status.
- Click "Sign (Digital)" to apply a cryptographic signature (mocked using a generated RSA key).
- Only signed reports can be submitted.

### 4. Export & Submit
- Download reports as **XML** (formatted for automated processing).
- Download reports as **PDF** (formatted for manual filing/archiving).
- Click "Submit to Authority" to simulate the API submission process to agencies like FinCEN or DOJ.

## Disclaimer

This is a demonstration application. The XML formats and submission endpoints are simplified representations and should not be used for actual regulatory filings without implementing the specific technical specifications required by the relevant authorities (e.g. FinCEN XML Schema).
