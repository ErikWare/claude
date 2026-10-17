# Asset control file (convention)

Every project keeps `ASSETS.md` at its desk root. It lists the **physical assets** (machines, services, stores, domains, accounts, devices) and **how each is controlled**: how it's started, restarted, deployed and stopped, and what must never be done to it.

## Format: one block per asset, ≤6 lines
```
### <name> · <kind: machine | service | store | domain | account | device>
- what: one line
- where: host / URL / path (no secrets, no IPs)
- control: start · restart · deploy · stop (exact command or mechanism)
- follows: branch or trigger that changes it (or "manual")
- never: the one thing that breaks it
- verified: YYYY-MM-DD (or UNVERIFIED)
```

## Rules
- Update it the moment a control path changes. Mark facts you haven't checked as UNVERIFIED.
- No secrets. Name where a secret lives (`.env` key), never its value.
- Keep it short. Detail goes in the repo docs it points to.
