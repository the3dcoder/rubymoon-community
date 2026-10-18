# The kid-safety checklist

Every pack is read by a person before it's merged. This is what they go through. Authors, it's worth reading
before you start; reviewers, go through every line for every new pack, and for every update look at everything
that changed.

The checker already handles the mechanical things (ids, CC0, text limits, the characters the screen can show,
links in text, size, and whether each picture is a plain black-and-white drawing with no text, scripts or hidden
images). Nothing below can be checked by a program. That's why a person does it.

## How to review

- Read every item: the prompt, every option, the hint, the fact and the grown-up line.
- Look at every picture. GitHub shows each SVG in the pull request's **Files changed** tab. If you have the
  rubymoon gem, `rubymoon pack preview` shows an item the way the device draws it.
- Read the pack's README.md and CHANGELOG.md.
- When in doubt, leave it out. Ask kindly for a change, and say why.

## The checklist

- **Gentle.** Nothing scary, violent, gross or shaming. No weapons. Luna, the Moon friend on the device, is
  never sad. A wrong answer is never mocked.
- **No real people.** Drawings may show simple, generic cartoon people (an astronaut in a helmet, a
  firefighter, a baker), drawn plainly with no realistic face. Never a real person's likeness, nobody who could
  be recognised, and nothing traced from a photo of a person. Traced photos show animals, places and things
  only, with no people or faces, not even in the background.
- **No personal details.** No real names (the author's pen name in the credits is fine), no addresses, schools,
  street signs, number plates or anything else that points to a family or a place someone lives.
- **No selling.** No brands, logos, ads, links, or "ask a grown-up to buy". No characters someone else owns.
- **Kind to every family.** No stereotypes. Families, homes and children of every kind. No religious or
  political message.
- **True.** Facts are right and, for the Moon, planets and Earth, have a source. Animals do what real animals
  do. Space facts match NASA, and the Moon's phases are never explained as Earth's shadow.
- **Fair questions.** Exactly one right answer that a grown-up would agree with. Wrong options are fair: if two
  pictures look alike, it's on purpose. An odd-one-out row has only one way to group it. Hints really help.
- **Readable on e-paper.** Every picture is clear in black and white at tile size, without fine detail. Text
  fits its tile.
- **Right for the ages.** The bands suit the questions. Anything a child reads alone (`self_read: true`) is at
  their reading level. Grown-up lines are short and kind.
- **Shared freely.** Everything is the author's own work, dedicated to the public domain under CC0-1.0, with
  honest credits. Nothing traced from someone else's picture, book or show.
- **Small and complete.** One pack, a sensible size, a README that tells a parent what they're adding, and a
  changelog line for this version.

## Approvals

For now the reviewer is @the3dcoder, and every pack needs that approval. A second trusted parent will join
later. Once there are more reviewers, a new pack will need two approvals, and a reviewer's own pack will need
an approval from someone else.

## If something slips through

If you find a problem in a pack that's already merged, don't wait: report it privately as
[SECURITY.md](SECURITY.md) explains. A credible safety report gets the pack withdrawn first and sorted out after.
