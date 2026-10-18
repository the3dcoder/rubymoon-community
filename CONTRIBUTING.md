# Making a pack

Thank you for making something for other people's children. This guide goes from an empty folder to a pull
request. The example pack in `packs/cm.example.shapes` has four items and four pictures; copying it is the
easiest way to start, and every step below points back to it.

You'll need a GitHub account, a text editor, and Ruby 3.4 or newer to run the checker. A drawing app that saves
SVG helps too (Inkscape is free).

Before you start, have a quick read of the rules in the [README](README.md) and the checklist in
[SAFETY.md](SAFETY.md). They're what your reviewer will go through, so they're worth knowing up front.

## 1. Pick an id

Every pack has an id like `cm.robin.farm-sounds`:

- `cm.` for community,
- your GitHub handle in small letters (`robin`),
- a name for the pack (`farm-sounds`).

Use small letters, numbers and dashes, at most 32 characters in all. The id is also the folder name, and it
never changes once the pack is shared, so pick one you like.

## 2. Copy the example

```sh
git clone https://github.com/<you>/rubymoon-community   # your fork
cd rubymoon-community
git switch -c farm-sounds
cp -r packs/cm.example.shapes packs/cm.robin.farm-sounds
```

## 3. Fill in `pack.yaml`

This is the pack's manifest. Open the copy and change it field by field:

| Field | What to put |
|---|---|
| `schema` | Always `1`. |
| `id` | Your id from step 1, the same as the folder name. |
| `version` | `1.0.0` for the first version. |
| `min_firmware` | `1.0.0`. |
| `title` | A short title, at most 32 characters. |
| `description` | One or two sentences for grown-ups, at most 160 characters. |
| `icon` | The picture that stands for the pack (one of your pictures). |
| `author` | `{kind: community, name: <your handle or a pen name>}`. |
| `license` | Always `CC0-1.0`. |
| `skills` | The skills your items teach (see the list below), each with its `levels`. |
| `activities` | Where the pack shows up on the device: an `id`, a `template`, a `title` (24 characters), an `icon`, a `world`, the age `bands`, and a `pool` that says which items to play. |
| `credits` | Who made the pictures, for example `{assets: ['*'], license: CC0-1.0, credit: Drawn by Robin}`. |
| `assets` | The names of your pictures, from `assets/manifest.yml`. |

**Worlds** are the places on the device's home screen: `moon`, `planets`, `stories`, `play`, `shapes`,
`letters` and `numbers`.

**Age bands** are `B1` (about 3), `B2` (4), `B3` (5), `B4` (6) and `B5` (7 to 8). List every band the activity
suits, like `[B1, B2, B3]`.

**Borrowing Ruby Moon's own pictures.** You can use the project's art by writing `rm.core:<name>` (for example
`rm.core:icon_find`) if you add `requires: [{id: rm.core, min_version: 1.0.0}]`. Community packs can't borrow
from other community packs.

### Skills

Pick skills from this list. Copy the `levels` exactly; `start` (the level a child starts at in each band, B1 to
B5) and `prereq` are optional, but if you give them they must match.

| Skill | Levels | Start | Needs first |
|---|---|---|---|
| `prelit.vocab` Picture words | 3 | 1 1 2 3 3 | |
| `letters.upper` Big letters | 3 | 1 2 2 3 3 | |
| `letters.lower` Little letters | 3 | 1 1 2 3 3 | |
| `letters.case` Big and little | 3 | 1 1 2 3 3 | letters.upper 2 |
| `phonics.initial` First sounds | 3 | 1 1 2 2 3 | letters.upper 2 |
| `sight.preprimer` First words | 2 | 1 1 1 2 2 | |
| `sight.primer` More words | 4 | 1 1 1 1 2 | sight.preprimer 2 |
| `sight.find` Find the word | 2 | 1 1 1 2 2 | |
| `count.subitize` Quick look | 3 | 1 2 2 3 3 | |
| `count.objects` Counting | 4 | 1 2 2 3 4 | |
| `count.back` Count down | 2 | 1 2 2 2 2 | |
| `numerals.read` Find the number | 3 | 1 2 2 3 3 | |
| `compare.more_fewer` More or fewer | 3 | 1 1 2 3 3 | count.objects 2 |
| `addsub.add` Adding | 3 | 1 1 1 2 3 | count.objects 3 |
| `addsub.sub` Taking away | 3 | 1 1 1 2 3 | addsub.add 2 |
| `addsub.story` Story sums | 2 | 1 1 1 1 2 | addsub.add 2 |
| `shapes.flat` Flat shapes | 3 | 1 1 2 3 3 | |
| `shapes.solid` Solid shapes | 3 | 1 1 1 2 3 | |
| `patterns.ab` AB patterns | 2 | 1 1 2 2 2 | |
| `patterns.aab` AAB patterns | 2 | 1 1 1 2 2 | patterns.ab 2 |
| `patterns.abb` ABB patterns | 2 | 1 1 1 2 2 | patterns.ab 2 |
| `patterns.abc` ABC patterns | 2 | 1 1 1 2 2 | patterns.ab 2 |
| `logic.category` What kind is it? | 3 | 1 1 2 3 3 | |
| `logic.same` Same pictures | 2 | 1 1 2 2 2 | |
| `logic.odd` Odd one out | 3 | 1 1 1 2 3 | |
| `logic.sort` Picture pairs | 3 | 1 1 2 3 3 | |
| `logic.group` Groups | 3 | 1 1 1 2 3 | |
| `memory.pairs` Memory | 4 | 1 1 2 3 4 | |
| `moon.find` Find the Moon | 2 | 1 1 1 2 2 | |
| `moon.phase` Moon shapes | 3 | 1 1 2 2 3 | |
| `moon.order` Moon order | 3 | 1 1 1 2 3 | |
| `moon.facts` Moon facts | 3 | 1 1 1 2 3 | |
| `moon.artemis` Artemis missions | 3 | 1 1 1 2 3 | |
| `moon.story` Moon stories | 2 | 1 1 1 2 2 | |
| `planets.name` Name the planets | 3 | 1 1 2 2 3 | |
| `planets.size` Big and small | 3 | 1 1 1 2 3 | |
| `planets.order` Order from the Sun | 3 | 1 1 1 2 3 | |
| `planets.traits` Planet clues | 3 | 1 1 2 2 3 | |
| `planets.facts` Planet facts | 3 | 1 1 2 2 3 | |

## 4. Write the items

Items go in `items/*.yaml`, as a list. You can use one file or several (`10-animals.yaml`, `20-sounds.yaml`);
they're read in name order. Every item has:

| Field | What it is |
|---|---|
| `id` | A name for the item, unique in the pack, like `find-cow`. Small letters, numbers, `-` and `_`. Never change or reuse it later: the device remembers progress by it. |
| `rev` | `1`. Raise it when you change an item's answer or meaning. |
| `type` | `choice`, `truefalse`, `sequence`, `count`, `match` or `story`. |
| `skill`, `lvl` | One of the pack's skills, and the step on its ladder (no higher than its `levels`). |
| `diff` | How hard it feels, from 1 to 9. |
| `prompt` | An `icon` (`find`, `count`, `order`, `same`, `next`, `yesno`, `add`, `sub`, `match`, `look`, `read`, `say`) and usually some `text`. It can also carry a `parent_line` for the grown-up and an `img`. |
| `hint` | Optional. Shown after a first wrong try, so make it genuinely helpful. |
| `fact` | Optional. A short true thing to say afterwards. Moon, planet and Earth facts also need a `source` (a web page) and a `checked` date like `'2026-10-18'`. |

What each type adds:

- **`choice`**: `options`, 2 to 4 tiles, exactly one with `ok: true`. A tile is a picture (`{img: cow}`), a word
  (`{word: Cow}`) or a big letter or number (`{glyph: C}`).
- **`truefalse`**: `answer: true` or `false`, and a `fact`.
- **`sequence`**: `seq`, 3 or 4 tiles in the right order.
- **`count`**: a `scene` with one or two `groups` like `{sprite: apple, n: 3}`, and the `answer`.
- **`match`**: a `mode` (`memory` or `pairs`) and 2, 3, 4 or 6 `pairs` of tiles.
- **`story`**: up to 10 `pages`, each a big picture (`img`) with a line of `text`.

Here's a choice item from the example:

```yaml
- id: find-circle
  rev: 1
  type: choice
  skill: shapes.flat
  lvl: 1
  diff: 1
  prompt: {icon: find, text: Find the circle.}
  options:
    - {img: circle, ok: true}
    - {img: square}
  hint: A circle is round all the way around.
```

### Words: limits and letters

The screen is small and the reader is little, so text is short:

| Text | At most |
|---|---|
| Pack title | 32 characters |
| Description | 160 |
| Activity title | 24 |
| Prompt text, grown-up line, hint | 80 each |
| Fact | 160 |
| Word or label on a tile | 12 |
| Story page | 120 |

The device's fonts have plain letters, numbers, everyday punctuation and accented letters like é, ñ and ü.
Curly quotes and emoji won't show, so use straight quotes (`'` and `"`). One YAML quirk to know: a word on its
own like `No`, `Yes`, `On` or `Off` is read as true or false, so put quotes around it: `{word: 'No'}`.

## 5. Draw the pictures

Pictures are SVG drawings in `assets/`, in black and white. The device's screen has no grey, so where you want
grey, fill with a pattern of black and white (dots or stripes). The example's circle shows how.

- **Size.** Answer tiles are 112 by 112. A big picture for a question or a story page is at most 440 by 360.
  Sizes are multiples of 8.
- **Lines.** Bold and simple: lines 3 to 6 pixels thick, no hairlines. A good test: squint, or shrink it to the
  size of a postage stamp. If you can still tell what it is, it works.
- **What's allowed in the file.** Only shapes (`rect`, `circle`, `ellipse`, `line`, `polyline`, `polygon`,
  `path`), groups (`g`) and patterns, filled and stroked with black, white or a pattern. No text, no embedded
  images, no links, no scripts, no styles, no see-through fills. One short note on a single line before `<svg>` is fine
  (what the picture is, its size, CC0-1.0); comments inside the drawing aren't. The `<svg>` needs
  `xmlns="http://www.w3.org/2000/svg"` and a `viewBox` that matches the size.
- **What to draw.** Animals, places and things, and simple cartoon people if a pack needs them (an astronaut in
  a helmet, say). Never a real person, and never a realistic face.
- **Saving from a drawing app.** Apps add their own extras. In Inkscape, use *File > Save As* and pick
  *Plain SVG*. Then open the file in a text editor: if you see colours like `#3a7bd5`, change them to `#000`
  or `#fff`. The checker will point at anything left over.
- **Photos.** Your own photos of animals, places and things are welcome as a starting point, but for now the
  checker takes drawings only. Trace the photo: put it on a layer in your drawing app, draw bold black outlines
  over it, delete the photo layer, and save the outlines as plain SVG. Only trace photos of animals, places and
  things: no people or faces, not even in the background.

Then describe each picture in `assets/manifest.yml` and add its name to `assets` in `pack.yaml`:

```yaml
- id: cow
  src: assets/cow.svg
  size: [112, 112]
  mode: 1bit
  dither: none
  license: CC0-1.0
  credit: Drawn by Robin
  source_url: null
```

Every picture you list must be used by an item or an icon, and every SVG in `assets/` must be listed.

## 6. Write the pack's README and changelog

`README.md` tells a parent what they're adding: what the pack is, which ages it suits, how many items it has,
a few words on playing it together, and the credits. `CHANGELOG.md` gets one line per version. The example's
are a good length.

## 7. Check it

```sh
ruby scripts/check_packs.rb packs/cm.robin.farm-sounds
```

It lists anything that needs fixing, file by file, in plain words, and says "The pack looks good." when it's
done. The same check runs on your pull request.

### With the rubymoon gem

Once the `rubymoon` gem is published, it adds a fuller format check, a picture of each item as the device draws
it, and a scaffold for new packs:

```sh
gem install rubymoon
rubymoon pack new cm.robin.farm-sounds --dir packs          # a new pack with one item
rubymoon pack lint packs/cm.robin.farm-sounds --strict
rubymoon pack preview packs/cm.robin.farm-sounds --item find-cow --out find-cow.png
```

Previews of your own SVG drawings need libvips installed. A pack made with `pack new` still needs a
`description`, `credits`, `README.md` and `CHANGELOG.md` before this repository's checker is happy. Run both
checks before you open your pull request.

## 8. Open a pull request

1. Commit your pack folder on your branch, push it to your fork, and open a pull request here.
2. **One pack per pull request**, new or updated. It keeps reviews small.
3. Fill in the checklist in the pull request. It asks you to confirm that you made everything yourself and
   dedicate it to the public domain under CC0-1.0.
4. The checker runs. If it finds something, fix it and push again; the pull request updates itself.
5. A reviewer reads every item and looks at every picture, using [SAFETY.md](SAFETY.md). They may suggest
   changes. That's normal, and it isn't a judgement of your work; it's how every pack gets better.
6. When they're happy, they merge it. Right now the reviewer is @the3dcoder, and a pack needs that approval. A
   second trusted parent will join later; once there are more reviewers, a new pack will need two approvals.

## Updating a pack

- Raise `version` (`1.0.0` to `1.0.1` for a fix, `1.1.0` for new items) and add a line to `CHANGELOG.md`.
- Raise an item's `rev` if you change its answer or what it means.
- Never change or reuse an item `id`, and never change the pack id.
- Families see "Update available" with your changelog, and nothing changes on a child's device until a parent
  says OK.

Only the pack's author or a reviewer should update a pack. To suggest a change to someone else's pack, open an
issue.

## Working on the checker

The checker is `scripts/check_packs.rb`; it uses only Ruby's standard library. Its tests use minitest:

```sh
bundle install
bundle exec ruby -Itest -e 'Dir.glob("test/**/*_test.rb").sort.each { |f| require File.expand_path(f) }'
```

The tests copy the example pack, break it in one small way, and check what the checker says. When you add or
change a rule, add a test like that, and keep the messages friendly: they're written for a parent, not a
programmer.
