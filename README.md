# Ruby Moon community packs

Ruby Moon is a little learning device for children aged 3 and up. It runs on the Xteink X4, a pocket-sized
e-paper reader, and it plays gentle games about the Moon, space, shapes, letters and numbers. Everything it
plays comes in **packs**: small bundles of questions, stories and black-and-white pictures.

Ruby Moon started as one parent's project for one little girl. This repository is where other families can
make packs too, share them, and use each other's.

## Who it's for

- **Grown-ups who'd like to make something.** A pack can be as small as five questions about farm animals or
  the shapes in your kitchen. You don't need to be a programmer: a pack is a couple of plain text files and a
  few drawings, and the checker in this repository tells you, in plain words, if anything needs fixing.
- **Families with a Ruby Moon.** Every pack here is read by a person before it's merged, and nothing reaches
  your child's device until you have looked at it and said yes.

## How a pack gets from here to a device

1. **A grown-up writes a pack** and opens a pull request here. [CONTRIBUTING.md](CONTRIBUTING.md) walks through
   it step by step.
2. **The checker runs** on every pull request. It looks at the ids, the licence, the text limits and every
   picture, and points at anything that needs fixing.
3. **A reviewer reads every item and looks at every picture**, going through the checklist in
   [SAFETY.md](SAFETY.md). They may ask for changes. When they're happy, they merge it.
4. **The pack is built and listed** in the community catalog, a signed list of every reviewed pack.
5. **A parent turns on the Community tab** in their family's Ruby Moon Hub (the small app that looks after the
   device at home), looks through the pack on their phone, and taps **Add to Ruby Moon**.
6. **The hub checks the file again and signs it with that family's own key.** The device only accepts packs
   signed by the Ruby Moon project or by its own family's hub, so a community pack can only arrive because a
   grown-up in that home approved that exact file.
7. **The device picks it up at its next sync.** Packs are data (words, pictures and answers), never code.

After that:

- **Updates always need a parent's OK.** When a pack gets a new version, the hub shows what changed. Nothing
  updates on its own, not even a small fix.
- **Safety withdrawals are quick.** If a pack turns out to be unsafe, we withdraw it, and every hub turns it off
  on the device at the next sync and tells the parent why. [SECURITY.md](SECURITY.md) has the details.
- **Nothing about a child leaves home.** No accounts, no ratings, no install counts, no tracking of any kind.

### Where things stand

This repository is where packs are written, checked and reviewed. Building them, signing the catalog and the
hub's Community tab come next, so for now merged packs live here as sources. The rules below already apply.

## The rules, in plain words

- **Everything is CC0.** Every pack and every file in this repository is dedicated to the public domain under
  [CC0-1.0](LICENSE), so any family can use it, change it and share it. Only send work that's yours to give.
- **Pictures are drawings, or your own photos, of animals, places and things.** Never people and never faces,
  in photos or drawings. Today the checker takes drawings only (black-and-white SVG files), so a photo needs
  turning into a drawing first; CONTRIBUTING.md shows how.
- **No personal details.** No real names, addresses, schools or anything that points to a family.
- **No selling.** No brands, logos, ads, links, or characters that belong to someone else.
- **Gentle and kind.** Nothing scary, mean or gross. A wrong answer is never laughed at. Families, homes and
  children of every kind are welcome; no religious or political messages.
- **True and fair.** Facts are right, and Moon, planet and Earth facts say where they come from. Every question
  has exactly one right answer.
- **Small enough to review.** One pack per pull request, at most 300 items and 1 MiB.
- **Pack ids look like `cm.<your-handle>.<pack-name>`**, for example `cm.robin.farm-sounds`: small letters,
  numbers and dashes, at most 32 characters, with your GitHub handle in the middle.
- **A person reviews every pack.** The checker catches the mechanical things; the review catches the rest.

## What's in this repository

```
packs/<id>/              one folder per pack
  pack.yaml              the manifest: id, title, ages, activities, credits
  items/*.yaml           the questions and stories
  assets/manifest.yml    one entry per picture: size, licence, credit
  assets/*.svg           the pictures
  README.md              what it is, which ages, how to play it together
  CHANGELOG.md           one line per version
packs/cm.example.shapes  a tiny example pack to copy
scripts/check_packs.rb   the checker
test/                    the checker's tests
SAFETY.md                the review checklist
```

To check every pack yourself, with Ruby 3.4 or newer:

```sh
ruby scripts/check_packs.rb
```

## Getting in touch

- An idea for a pack, or a mistake in one: open an issue.
- Anything about a child's safety, a person in a picture, personal details or a licence problem: please
  report it privately with GitHub's **Report a vulnerability** button, as [SECURITY.md](SECURITY.md) explains.

Please read the [code of conduct](CODE_OF_CONDUCT.md) too. It's short.

## Licence

[CC0-1.0](LICENSE). Every pack and every file here, the checker included, is dedicated to the public domain.
