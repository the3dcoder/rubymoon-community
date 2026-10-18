# Reporting a problem privately

Some problems shouldn't be discussed in public. If you find any of these, please report it privately:

- a real person, or a photo of a person or a face, in a pack;
- someone's name, address, school or other personal details;
- anything unsafe or upsetting for a young child;
- a file that sneaks something past the checker (a script, a link, a hidden image or hidden text);
- your own work shared here without your permission;
- a weakness in the checker or this repository's workflows.

## How to report

1. Go to this repository's **Security** tab.
2. Click **Report a vulnerability**. (It's GitHub's private reporting form; the name sounds technical, but it's
   the right place for safety reports too.)
3. Tell us the pack id, the version, the item or picture, and what's wrong.

The direct link is
[github.com/the3dcoder/rubymoon-community/security/advisories/new](https://github.com/the3dcoder/rubymoon-community/security/advisories/new).
Only the reviewers can see your report.

Please don't post the details in a public issue, and please don't attach photos of children, even to show
what's wrong. A description is enough.

For everyday mistakes (a wrong fact, an unfair question, a picture that's hard to see), a public issue is
perfect.

## What happens next

- We look at safety reports as soon as we can.
- **We act first and talk after.** If a report is credible, we withdraw the pack straight away and work out the
  details afterwards.
- We'll tell you what we did, in the report.

## How a withdrawal works

When the community catalog is running, a withdrawn pack is marked in the catalog with the reason (safety,
licence, quality, or the author asked) and the date. Each family's hub sees that at its next catalog check:

- **Safety:** the hub turns the pack off on the device at the next sync and tells the parent why.
- **Any other reason:** the hub shows the parent a note and lets them decide.
- A withdrawn pack can't be added again. The catalog's version only ever goes up, so an old copy can't be used
  to hide a withdrawal.

Until the catalog is running, packs reach families only from this repository, so a withdrawal means removing
the pack here straight away.

## What this repository holds

Pack sources and a checker. There are no signing keys, passwords or other secrets here, and the workflow that
checks pull requests can only read the repository. The `main` branch is the only one we look after.
