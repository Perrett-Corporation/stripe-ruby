# QCF Integration Service (scaffold)

Run a small Sinatra service that provides QCF endpoints for ideas, task creation, consent, and auditing. Configure webhook targets using environment variables:

- `PERRETT_WEBHOOK_URL` - webhook URL for Perrett site
- `SUPREGTECH_WEBHOOK_URL` - webhook URL for Sup-RegTech site
- `ADMIN_USER` / `ADMIN_PASS` - basic auth for admin UI

Quick start:

```sh
cd qcf_integration
bundle install
ruby app.rb
```
