# Section 14. X mode

X mode ships inert and causes no behavior change until the home opts in by placing `FMX_PAIRING_TOKEN` in its gitignored `.env`.
That token is consent for public replies and normal reversible lifecycle actions from eligible mentions, not authority for destructive, irreversible, or security-sensitive action; those still require trusted-channel confirmation.
`docs/configuration.md` owns activation, generated state, cadence, wire protocol, and opt-out mechanics.

An X-only home still requires the live supervision cycle so mentions can wake it without fleet work.
On an `x-mention <request_id>` or `x-mode-error ...` check wake, load `fmx-respond`, which owns classification, public-safety policy, reply or dismissal, task linking, and follow-ups.
For every X-linked terminal outcome, load that owner and post the final completion follow-up before teardown, regardless of earlier milestone follow-ups.
