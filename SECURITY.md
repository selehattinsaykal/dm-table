# Security policy

## Reporting a vulnerability

Please report security issues privately through GitHub's **Security → Report a vulnerability**
(private vulnerability reporting) rather than opening a public issue. Include reproduction steps and
the affected version. You can expect an initial response within a few days.

Do not include API keys, campaign backups or player data in a report.

## Threat model

DM Table is a **LAN application with no authentication by design**. The DM's device runs an HTTP +
WebSocket server on the local network; anyone who can reach that port and holds a session link/QR can
join the table as a player. This is intentional for a group sitting at the same table, and it means:

- **Do not expose the server port to the internet** or to an untrusted network.
- On Windows, grant firewall access for **private networks only**.
- A malicious client can only do what the protocol allows: the server re-validates every request
  against the database (character ownership, prices, rules values) and never trusts fields in the
  message body. Bugs in that validation *are* security bugs — please report them.

Player-scoped data (other players' quest decisions, DM notes, whispers, hidden map pins) is filtered
**server-side** before broadcast. A leak of DM-only or other-player-only data into a snapshot is a
security bug, not just a cosmetic one.

## API keys

AI features are opt-in and use your own provider key (Gemini / OpenAI / Claude). The key is:

- stored only in the device's local preferences (`shared_preferences`),
- never written to the campaign database,
- never included in a backup archive,
- never transmitted over the LAN or included in a player snapshot.

It is sent only to the provider you configured, over HTTPS, when you run one of the AI tools. Revoke
and rotate the key in your provider's console if you suspect exposure.

## Data at rest

Campaign databases, media and backups are plain files under the user's documents folder and are **not
encrypted**. Anyone with access to the machine or to a backup archive can read them.
