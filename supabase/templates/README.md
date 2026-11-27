# Bid2Scale sign-in emails

Paste each file into Supabase → Authentication → Emails → Templates, with
this subject. They use codes (`{{ .Token }}`), which is what the app asks for.

| Supabase template | File | Subject |
|---|---|---|
| Confirm signup | `confirm_signup.html` | Confirm your email · Bid2Scale |
| Magic link | `magic_link.html` | Your Bid2Scale sign-in code |
| Reset password | `reset_password.html` | Reset your Bid2Scale password |
| Change email address | `change_email.html` | Confirm your new Bid2Scale email |
| Reauthentication | `reauthentication.html` | Your Bid2Scale verification code |

The bid alert digest uses the same look; it is built in
`scripts/bid_worker.py` (`build_email`) and sent by the office PC.
