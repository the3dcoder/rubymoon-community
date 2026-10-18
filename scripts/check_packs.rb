#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks the community packs in packs/<id>/ before a person reviews them.
#
#   ruby scripts/check_packs.rb                          every pack in packs/
#   ruby scripts/check_packs.rb packs/cm.robin.farm      just the folders you name
#
# It needs only Ruby's standard library. It prints what it found, file by file, and exits with 1 when a pack needs
# fixing. It covers the community rules (ids, CC0, plain black-and-white drawings, size) and the basics of the
# manifest and items. The rubymoon gem's `pack lint --strict` adds the full format checks on top.

require "date"
require "json"
require "strscan"
require "yaml"

module PackCheck
  ROOT = File.expand_path("..", __dir__)

  LICENSE = "CC0-1.0"
  ID_MAX = 32
  ID_RE = /\Acm\.[a-z0-9]+(?:-[a-z0-9]+)*\.[a-z0-9]+(?:-[a-z0-9]+)*\z/
  PACK_BYTES_MAX = 1_048_576
  ITEMS_MAX = 300
  PICTURE_BYTES_MAX = 65_536
  MANIFEST_BYTES_MAX = 4096
  ITEM_BYTES_MAX = 2048

  TEXT_RE = /\A[\u0020-\u007E\u00A0-\u00FF]*\z/
  LINK_RE = %r{://|\bwww\.|[^\s@]+@[^\s@]+\.[a-z]{2,}}i
  SEMVER_RE = /\A(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,4})\z/
  DOMAINS = %w[prelit letters phonics sight count numerals compare addsub shapes patterns logic memory time moon
               planets earth].freeze
  SKILL_RE = /\A(?:#{DOMAINS.join('|')})(?:\.[a-z0-9_]{1,24}){1,2}\z/
  SKILL_GLOB_RE = /\A(?:#{DOMAINS.join('|')})(?:(?:\.[a-z0-9_]{1,24}){1,2}|(?:\.[a-z0-9_]{1,24})?\.\*)\z/
  LOCAL_ID_RE = /\A[a-z0-9][a-z0-9_-]{0,31}\z/
  ITEM_ID_RE = /\A[a-z0-9][a-z0-9_-]{0,39}\z/
  ASSET_NAME_RE = /\A[a-z0-9][a-z0-9_]{0,31}\z/
  ASSET_REF_RE = /\A(?:([a-z0-9][a-z0-9.-]{0,31}):)?([a-z0-9][a-z0-9_]{0,31})\z/
  CREDIT_PATTERN_RE = /\A[a-z0-9_*]{1,32}\z/
  GLYPH_RE = /\A[A-Z0-9+=?-]{1,3}\z/
  TAG_RE = /\A[a-z0-9_-]{1,16}\z/
  DATE_RE = /\A\d{4}-\d{2}-\d{2}\z/
  HTTPS_RE = %r{\Ahttps://[^\s]+\z}

  # Ruby Moon skill taxonomy, as in the rubymoon gem (data/taxonomy.yaml): id => [levels, start for B1..B5, prereq].
  # A manifest skill uses these levels, and its start and prereq match when it gives them.
  TAXONOMY = {
    "prelit.vocab" => [3, [1, 1, 2, 3, 3]],
    "letters.upper" => [3, [1, 2, 2, 3, 3]],
    "letters.lower" => [3, [1, 1, 2, 3, 3]],
    "letters.case" => [3, [1, 1, 2, 3, 3], [["letters.upper", 2]]],
    "phonics.initial" => [3, [1, 1, 2, 2, 3], [["letters.upper", 2]]],
    "sight.preprimer" => [2, [1, 1, 1, 2, 2]],
    "sight.primer" => [4, [1, 1, 1, 1, 2], [["sight.preprimer", 2]]],
    "sight.find" => [2, [1, 1, 1, 2, 2]],
    "count.subitize" => [3, [1, 2, 2, 3, 3]],
    "count.objects" => [4, [1, 2, 2, 3, 4]],
    "count.back" => [2, [1, 2, 2, 2, 2]],
    "numerals.read" => [3, [1, 2, 2, 3, 3]],
    "compare.more_fewer" => [3, [1, 1, 2, 3, 3], [["count.objects", 2]]],
    "addsub.add" => [3, [1, 1, 1, 2, 3], [["count.objects", 3]]],
    "addsub.sub" => [3, [1, 1, 1, 2, 3], [["addsub.add", 2]]],
    "addsub.story" => [2, [1, 1, 1, 1, 2], [["addsub.add", 2]]],
    "shapes.flat" => [3, [1, 1, 2, 3, 3]],
    "shapes.solid" => [3, [1, 1, 1, 2, 3]],
    "patterns.ab" => [2, [1, 1, 2, 2, 2]],
    "patterns.aab" => [2, [1, 1, 1, 2, 2], [["patterns.ab", 2]]],
    "patterns.abb" => [2, [1, 1, 1, 2, 2], [["patterns.ab", 2]]],
    "patterns.abc" => [2, [1, 1, 1, 2, 2], [["patterns.ab", 2]]],
    "logic.category" => [3, [1, 1, 2, 3, 3]],
    "logic.same" => [2, [1, 1, 2, 2, 2]],
    "logic.odd" => [3, [1, 1, 1, 2, 3]],
    "logic.sort" => [3, [1, 1, 2, 3, 3]],
    "logic.group" => [3, [1, 1, 1, 2, 3]],
    "memory.pairs" => [4, [1, 1, 2, 3, 4]],
    "moon.find" => [2, [1, 1, 1, 2, 2]],
    "moon.phase" => [3, [1, 1, 2, 2, 3]],
    "moon.order" => [3, [1, 1, 1, 2, 3]],
    "moon.facts" => [3, [1, 1, 1, 2, 3]],
    "moon.artemis" => [3, [1, 1, 1, 2, 3]],
    "moon.story" => [2, [1, 1, 1, 2, 2]],
    "planets.name" => [3, [1, 1, 2, 2, 3]],
    "planets.size" => [3, [1, 1, 1, 2, 3]],
    "planets.order" => [3, [1, 1, 1, 2, 3]],
    "planets.traits" => [3, [1, 1, 2, 2, 3]],
    "planets.facts" => [3, [1, 1, 2, 2, 3]]
  }.freeze

  TEMPLATES = %w[choice truefalse sequence count match story].freeze
  PROJECT_TEMPLATES = %w[journal moon-explorer rocket].freeze
  WORLDS = %w[moon planets stories play shapes letters numbers].freeze
  BANDS = %w[B1 B2 B3 B4 B5].freeze
  PROMPT_ICONS = %w[find count order same next yesno add sub match look read say journal story moon rocket].freeze
  RASTER_EXTS = %w[.png .jpg .jpeg .gif .webp .heic .heif .bmp .tif .tiff .avif].freeze

  MANIFEST_KEYS = %w[schema id version min_firmware title description icon author license private system requires
                     skills activities stickers cast credits assets items].freeze
  MANIFEST_REQUIRED = %w[schema id version min_firmware title description icon author license skills activities
                         credits].freeze
  ACTIVITY_KEYS = %w[id template title icon world bands pool options_max together needs_time no_learner order].freeze
  ACTIVITY_REQUIRED = %w[id template title icon world bands pool].freeze
  ITEM_COMMON = %w[id rev type skill lvl diff prompt response hint fact source checked self_read private tags].freeze
  ITEM_REQUIRED = %w[id rev type skill lvl diff].freeze
  ITEM_TYPE_KEYS = {
    "choice" => %w[options shuffle], "truefalse" => %w[answer], "sequence" => %w[seq fixed_first],
    "count" => %w[scene answer options range], "match" => %w[mode pairs grid], "story" => %w[pages then]
  }.freeze
  ITEM_TYPE_REQUIRED = {
    "choice" => %w[prompt options], "truefalse" => %w[prompt answer fact], "sequence" => %w[prompt seq],
    "count" => %w[prompt scene answer], "match" => %w[prompt mode pairs], "story" => %w[pages]
  }.freeze
  GENERATE_KEYS = %w[kind id_prefix skill lvl diff a b max_result sprite layout text response].freeze
  GENERATE_REQUIRED = %w[kind id_prefix skill lvl diff a b max_result sprite layout].freeze
  ASSET_KEYS = %w[id src size mode dither mask frames frame_ms static_only license credit source_url].freeze
  ASSET_REQUIRED = %w[id src size license credit source_url].freeze

  Problem = Struct.new(:file, :message)

  # The checks for one pack folder. `problems` holds Problems whose `file` is relative to the pack folder
  # ("." for the folder itself).
  class Checker
    attr_reader :dir, :problems, :item_count, :picture_count

    def initialize(dir)
      @dir = File.expand_path(dir)
      @problems = []
      @item_count = 0
      @picture_count = 0
      @refs = []
      @items = []
    end

    def run
      return self unless check_folder

      manifest = load_manifest
      return self unless manifest

      check_manifest(manifest)
      load_items(manifest)
      @items.each { |item, file, label| check_item(item, file, label, manifest) }
      check_item_links(manifest)
      check_assets(manifest)
      self
    end

    def ok? = problems.empty?

    private

    # ---- folder and files -------------------------------------------------------------------------------------

    def check_folder
      unless File.directory?(dir)
        problem(".", "isn't a folder.")
        return false
      end
      if File.symlink?(dir)
        problem(".", "is a link to another folder. Put the pack's files here directly.")
        return false
      end

      id = File.basename(dir)
      check_id(id, ".", "The folder name #{id}")
      total = 0
      linked = false
      Dir.glob("**/*", File::FNM_DOTMATCH, base: dir).sort.each do |rel|
        next if %w[. ..].include?(File.basename(rel))

        path = File.join(dir, rel)
        if File.symlink?(path)
          problem(rel, "is a link to somewhere else. A pack holds plain files only.")
          linked = true
          next
        end
        next if File.directory?(path)

        total += File.size(path)
        problem(rel, unexpected_file(rel)) unless allowed_file?(rel)
      end
      if total > PACK_BYTES_MAX
        problem(".", "holds #{kib(total)} of files. A community pack stays under #{kib(PACK_BYTES_MAX)}; " \
                     "split it into two packs or make the pictures simpler.")
      end
      %w[README.md CHANGELOG.md].each do |f|
        problem(".", "needs a #{f}. CONTRIBUTING.md says what goes in it.") unless File.file?(File.join(dir, f))
      end
      !linked
    end

    def allowed_file?(rel)
      %w[pack.yaml README.md CHANGELOG.md assets/manifest.yml].include?(rel) ||
        rel.match?(%r{\Aitems/[^/]+\.ya?ml\z}) || rel.match?(%r{\Aassets/[^/]+\.svg\z})
    end

    def unexpected_file(rel)
      if RASTER_EXTS.include?(File.extname(rel).downcase)
        "is a photo or bitmap file. For now every picture is an SVG drawing; CONTRIBUTING.md shows how to " \
          "turn a photo into a drawing."
      elsif File.basename(rel) == "pack.json"
        "is a JSON manifest. Community packs use pack.yaml."
      else
        "isn't something a pack holds. A pack has pack.yaml, README.md, CHANGELOG.md, items/*.yaml, " \
          "assets/manifest.yml and assets/*.svg, and nothing else."
      end
    end

    def check_id(id, file, what)
      return problem(file, "#{what} should be text.") unless id.is_a?(String)

      unless ID_RE.match?(id)
        problem(file, "#{what} isn't a community pack id. Ids look like cm.<your-handle>.<pack-name>, in small " \
                      "letters, numbers and dashes, for example cm.robin.farm-sounds.")
      end
      return unless id.length > ID_MAX

      problem(file, "#{what} is #{id.length} characters long. Pack ids are at most #{ID_MAX}; shorten the pack name.")
    end

    # ---- YAML -------------------------------------------------------------------------------------------------

    def load_yaml(rel)
      text = File.read(File.join(dir, rel), mode: "rb").force_encoding(Encoding::UTF_8)
      unless text.valid_encoding?
        problem(rel, "isn't saved as UTF-8 text. Save it again as UTF-8.")
        return :error
      end
      normalize(YAML.safe_load(text, permitted_classes: [Date], aliases: false, filename: rel))
    rescue Psych::Exception => e
      problem(rel, "can't be read as YAML: #{e.message.lines.first.to_s.strip}")
      :error
    end

    def normalize(value)
      case value
      when Hash then value.to_h { |k, v| [k.to_s, normalize(v)] }
      when Array then value.map { |v| normalize(v) }
      when Date then value.iso8601
      else value
      end
    end

    # ---- manifest ---------------------------------------------------------------------------------------------

    def load_manifest
      unless File.file?(File.join(dir, "pack.yaml"))
        problem(".", "needs a pack.yaml. Copy the one from packs/cm.example.shapes to start.")
        return nil
      end
      doc = load_yaml("pack.yaml")
      return nil if doc == :error

      unless doc.is_a?(Hash)
        problem("pack.yaml", "should be a list of fields (id, title, author and so on). See the example pack.")
        return nil
      end
      doc
    end

    def check_manifest(m)
      f = "pack.yaml"
      m.each_key do |k|
        next if MANIFEST_KEYS.include?(k)

        problem(f, case k
                   when "scripts" then "has a scripts section. Packs are data only and never carry code."
                   when "build" then "has a build section. The build tool adds that; leave it out."
                   else "has a field called #{k}, which isn't part of a pack manifest."
                   end)
      end
      (MANIFEST_REQUIRED - m.keys).each { |k| problem(f, "needs a #{k} field.") }

      problem(f, "schema should be 1.") if m.key?("schema") && m["schema"] != 1
      if m.key?("id")
        check_id(m["id"], f, "The id #{m['id']}")
        folder = File.basename(dir)
        if m["id"].is_a?(String) && m["id"] != folder
          problem(f, "has the id #{m['id']}, but the folder is called #{folder}. They must be the same.")
        end
      end
      %w[version min_firmware].each do |k|
        next unless m.key?(k)
        next if m[k].is_a?(String) && SEMVER_RE.match?(m[k])

        problem(f, "#{k} should look like 1.0.0 (three numbers with dots), in quotes if YAML changes it.")
      end
      text(m["title"], f, "The title", max: 32) if m.key?("title")
      text(m["description"], f, "The description", max: 160) if m.key?("description")
      ref(m["icon"], "icon", f, "The pack icon") if m.key?("icon")
      check_author(m["author"], f) if m.key?("author")
      if m.key?("license") && m["license"] != LICENSE
        problem(f, "has the license #{m['license'].inspect}. Everything here is shared as #{LICENSE}.")
      end
      problem(f, "has private: true. Community packs are for sharing, so leave private out.") if m["private"] == true
      problem(f, "has system: true. Only the project's own core pack is a system pack.") if m["system"] == true
      check_requires(m["requires"], f) if m.key?("requires")
      check_skills(m["skills"], f) if m.key?("skills")
      check_activities(m["activities"], f, m) if m.key?("activities")
      check_stickers(m["stickers"], f) if m.key?("stickers")
      check_cast(m["cast"], f) if m.key?("cast")
      check_credits(m["credits"], f) if m.key?("credits")
      check_asset_list(m["assets"], f) if m.key?("assets")

      size = JSON.generate(m.except("assets", "items")).bytesize
      return unless size > MANIFEST_BYTES_MAX

      problem(f, "is #{size} bytes once compiled; a manifest is at most #{MANIFEST_BYTES_MAX}. Shorten the " \
                 "titles and descriptions, or split the pack.")
    end

    def check_author(author, f)
      return problem(f, "author should look like {kind: community, name: Your Name}.") unless author.is_a?(Hash)

      unknown_keys(author, %w[kind name], f, "author") do |k|
        k == "url" ? "author has a url. Community packs don't carry links; leave it out." : nil
      end
      if author["kind"] != "community"
        problem(f, "author kind is #{author['kind'].inspect}. Community packs use kind: community.")
      end
      text(author["name"], f, "The author name", max: 48, required: true)
    end

    def check_requires(list, f)
      return problem(f, "requires should be a list.") unless list.is_a?(Array)

      list.each do |r|
        unless r.is_a?(Hash) && r["id"] == "rm.core" && (r.keys - %w[id min_version]).empty? &&
               r["min_version"].is_a?(String) && SEMVER_RE.match?(r["min_version"])
          problem(f, "requires #{r.inspect}. Community packs may borrow pictures from rm.core only, " \
                     "written as {id: rm.core, min_version: 1.0.0}.")
        end
      end
    end

    def check_skills(list, f)
      return problem(f, "skills should be a list with at least one skill.") unless list.is_a?(Array) && !list.empty?

      problem(f, "has #{list.size} skills; the most a pack can have is 64.") if list.size > 64
      seen = {}
      list.each_with_index do |s, i|
        unless s.is_a?(Hash)
          problem(f, "skill #{i + 1} should look like {id: shapes.flat, levels: 3}.")
          next
        end
        id = s["id"]
        where = id.is_a?(String) ? "skill #{id}" : "skill #{i + 1}"
        unknown_keys(s, %w[id levels title start prereq], f, where)
        problem(f, "#{where} appears twice.") if seen[id]
        seen[id] = true
        int(s["levels"], f, "#{where}: levels", 1, 15, required: true)
        check_taxonomy(s, f, where)
        text(s["title"], f, "#{where}: the title", max: 32) if s.key?("title")
        if s.key?("start") && !(s["start"].is_a?(Array) && s["start"].size == 5 &&
                                s["start"].all? { |n| n.is_a?(Integer) && n.between?(1, 15) })
          problem(f, "#{where}: start should be five levels, one per band, like [1, 1, 2, 3, 3].")
        end
        next unless s.key?("prereq")

        ok = s["prereq"].is_a?(Array) && s["prereq"].size <= 2 && s["prereq"].all? do |p|
          p.is_a?(Hash) && (p.keys - %w[skill lvl]).empty? && str?(p["skill"], SKILL_RE) &&
            p["lvl"].is_a?(Integer) && p["lvl"].between?(1, 15)
        end
        problem(f, "#{where}: prereq should be up to two entries like {skill: patterns.ab, lvl: 2}.") unless ok
      end
    end

    def check_taxonomy(s, f, where)
      levels, start, prereq = TAXONOMY[s["id"]]
      unless levels
        return problem(f, "#{where} isn't one of Ruby Moon's skills. CONTRIBUTING.md lists them all, like shapes.flat.")
      end

      problem(f, "#{where} has #{levels} levels in Ruby Moon, so use levels: #{levels}.") if s["levels"] != levels
      problem(f, "#{where}: start should be #{start.inspect} (or leave it out).") if s.key?("start") && s["start"] != start
      return unless s.key?("prereq")

      want = Array(prereq).map { |skill, lvl| {"skill" => skill, "lvl" => lvl} }
      return if s["prereq"] == want

      shown = want.empty? ? "left out" : want.map { |p| "{skill: #{p['skill']}, lvl: #{p['lvl']}}" }.join(", ")
      problem(f, "#{where}: prereq should be #{shown} (or leave it out).")
    end

    def check_activities(list, f, m)
      unless list.is_a?(Array) && !list.empty?
        return problem(f, "activities should be a list with at least one activity.")
      end

      problem(f, "has #{list.size} activities; the most a pack can have is 24.") if list.size > 24
      seen = {}
      list.each_with_index do |a, i|
        unless a.is_a?(Hash)
          problem(f, "activity #{i + 1} should be a list of fields (id, template, title and so on).")
          next
        end
        id = a["id"]
        where = id.is_a?(String) ? "activity #{id}" : "activity #{i + 1}"
        unknown_keys(a, ACTIVITY_KEYS, f, where)
        (ACTIVITY_REQUIRED - a.keys).each { |k| problem(f, "#{where} needs #{k}.") }
        if a.key?("id")
          problem(f, "#{where}: the id should be small letters, numbers, - or _.") unless str?(id, LOCAL_ID_RE)
          problem(f, "#{where} appears twice.") if seen[id]
          seen[id] = true
        end
        template(a["template"], f, where) if a.key?("template")
        text(a["title"], f, "#{where}: the title", max: 24) if a.key?("title")
        ref(a["icon"], "icon", f, "#{where}: the icon") if a.key?("icon")
        if a.key?("world") && !WORLDS.include?(a["world"])
          problem(f, "#{where}: world should be one of #{WORLDS.join(', ')}.")
        end
        bands(a["bands"], f, where) if a.key?("bands")
        pool(a["pool"], f, where, m) if a.key?("pool")
        int(a["options_max"], f, "#{where}: options_max", 2, 4) if a.key?("options_max")
        int(a["order"], f, "#{where}: order", -100, 100) if a.key?("order")
        %w[together needs_time no_learner].each { |k| bool(a[k], f, "#{where}: #{k}") if a.key?(k) }
      end
    end

    def template(value, f, where)
      return if TEMPLATES.include?(value)

      if PROJECT_TEMPLATES.include?(value)
        problem(f, "#{where} uses the #{value} template, which belongs to Ruby Moon's own Moon and rocket " \
                   "activities. Community packs use #{TEMPLATES.join(', ')}.")
      else
        problem(f, "#{where}: #{value.inspect} isn't a template. Use one of #{TEMPLATES.join(', ')}.")
      end
    end

    def bands(value, f, where)
      return if value.is_a?(Array) && !value.empty? && value.uniq.size == value.size && (value - BANDS).empty?

      problem(f, "#{where}: bands should be a list of ages from B1 (3) to B5 (7-8), like [B1, B2].")
    end

    def pool(p, f, where, m)
      unless p.is_a?(Hash) && !p.empty?
        return problem(f, "#{where}: pool should say which items to use, like {skills: [shapes.flat]}.")
      end

      unknown_keys(p, %w[skills lvl types items], f, "#{where}: pool")
      skill_ids = Array(m["skills"]).filter_map { |s| s["id"] if s.is_a?(Hash) }
      if p.key?("skills")
        globs = p["skills"]
        if globs.is_a?(Array) && globs.size.between?(1, 4) && globs.all? { |g| str?(g, SKILL_GLOB_RE) }
          globs.each do |g|
            next if skill_ids.any? { |s| glob_match?(g, s) }

            problem(f, "#{where}: pool skill #{g} doesn't match any skill in this pack's skills list.")
          end
        else
          problem(f, "#{where}: pool skills should be 1 to 4 skill ids, like [shapes.flat] or [shapes.*].")
        end
      end
      if p.key?("lvl") && !(p["lvl"].is_a?(Array) && p["lvl"].size == 2 &&
                            p["lvl"].all? { |n| n.is_a?(Integer) && n.between?(1, 15) } && p["lvl"][0] <= p["lvl"][1])
        problem(f, "#{where}: pool lvl should be [lowest, highest], like [1, 3].")
      end
      if p.key?("types") && !(p["types"].is_a?(Array) && !p["types"].empty? && (p["types"] - TEMPLATES).empty?)
        problem(f, "#{where}: pool types should be a list of item types from #{TEMPLATES.join(', ')}.")
      end
      return unless p.key?("items") && !(p["items"].is_a?(Array) && p["items"].size.between?(1, 15))

      problem(f, "#{where}: pool items should be a list of 1 to 15 item ids.")
    end

    def check_stickers(list, f)
      return problem(f, "stickers should be a list of up to 32.") unless list.is_a?(Array) && list.size <= 32

      list.each_with_index do |s, i|
        where = "sticker #{i + 1}"
        next problem(f, "#{where} should look like {id: star, asset: star, title: Star}.") unless s.is_a?(Hash)

        unknown_keys(s, %w[id asset title], f, where)
        problem(f, "#{where}: the id should be small letters, numbers, - or _.") unless str?(s["id"], LOCAL_ID_RE)
        ref(s["asset"], "sticker", f, "#{where}: the asset", required: true)
        text(s["title"], f, "#{where}: the title", max: 32, required: true)
      end
    end

    def check_cast(list, f)
      return problem(f, "cast should be a list of up to 8.") unless list.is_a?(Array) && list.size <= 8

      list.each_with_index do |c, i|
        where = "cast member #{i + 1}"
        next problem(f, "#{where} should look like {id: pilot, name: Pilot Pip}.") unless c.is_a?(Hash)

        unknown_keys(c, %w[id name role asset], f, where)
        problem(f, "#{where}: the id should be small letters, numbers, - or _.") unless str?(c["id"], LOCAL_ID_RE)
        text(c["name"], f, "#{where}: the name", max: 16, required: true)
        text(c["role"], f, "#{where}: the role", max: 16) if c.key?("role")
        ref(c["asset"], "cast", f, "#{where}: the asset") if c.key?("asset")
      end
    end

    def check_credits(list, f)
      unless list.is_a?(Array) && list.size.between?(1, 8)
        return problem(f, "credits should be a list of 1 to 8 entries, like " \
                          "{assets: ['*'], license: CC0-1.0, credit: Drawn by Robin}.")
      end

      list.each_with_index do |c, i|
        where = "credit #{i + 1}"
        next problem(f, "#{where} should look like {assets: ['*'], license: CC0-1.0, credit: Drawn by Robin}.") unless c.is_a?(Hash)

        unknown_keys(c, %w[assets license credit source], f, where)
        unless c["assets"].is_a?(Array) && c["assets"].size.between?(1, 8) && c["assets"].all? { |a| str?(a, CREDIT_PATTERN_RE) }
          problem(f, "#{where}: assets should be a list of picture names; '*' matches any run of letters.")
        end
        problem(f, "#{where} has the license #{c['license'].inspect}. Everything here is #{LICENSE}.") if c["license"] != LICENSE
        text(c["credit"], f, "#{where}: the credit line", max: 80, required: true)
        url(c["source"], f, "#{where}: source") if c.key?("source")
      end
    end

    def check_asset_list(list, f)
      unless list.is_a?(Array) && list.all? { |n| str?(n, ASSET_NAME_RE) }
        return problem(f, "assets should be a list of picture names (small letters, numbers and _), like [circle, square].")
      end

      list.tally.each { |n, c| problem(f, "lists the picture #{n} #{c} times in assets.") if c > 1 }
    end

    # ---- items ------------------------------------------------------------------------------------------------

    def load_items(manifest)
      if manifest.key?("items")
        list = manifest["items"]
        if list.is_a?(Array)
          add_items(list, "pack.yaml")
        else
          problem("pack.yaml", "items should be a list.")
        end
      end
      Dir.glob("items/*.{yaml,yml}", base: dir).sort_by(&:b).each do |rel|
        list = load_yaml(rel)
        next if list == :error

        if list.nil?
          problem(rel, "is empty. Put a list of items in it, or delete it.")
        elsif list.is_a?(Array)
          add_items(list, rel)
        else
          problem(rel, "should be a list of items, each starting with '- id:'.")
        end
      end
      @item_count = @items.size
      problem(".", "has no items yet. Add some in items/*.yaml.") if @items.empty?
      return unless @items.size > ITEMS_MAX

      problem(".", "has #{@items.size} items. A community pack has at most #{ITEMS_MAX}, so it stays easy to " \
                   "review; split it into two packs.")
    end

    def add_items(list, file)
      list.each_with_index do |item, i|
        if item.is_a?(Hash) && item.key?("generate")
          expand(item["generate"], file, i).each { |gen| @items << [gen, file, %(item "#{gen['id']}")] }
        else
          label = item.is_a?(Hash) && item["id"].is_a?(String) ? %(item "#{item['id']}") : "item #{i + 1}"
          @items << [item, file, label]
        end
      end
    end

    # Expands a `generate` block into count items, as the rubymoon gem does.
    def expand(block, file, index)
      where = "generate block #{index + 1}"
      unless block.is_a?(Hash)
        problem(file, "#{where} should be a list of fields.")
        return []
      end

      bad = (block.keys - GENERATE_KEYS)
      bad.each { |k| problem(file, "#{where} has a field called #{k}, which generate blocks don't use.") }
      missing = GENERATE_REQUIRED - block.keys
      missing.each { |k| problem(file, "#{where} needs #{k}.") }
      ranges_ok = %w[a b].all? do |k|
        v = block[k]
        ok = v.is_a?(Array) && v.size == 2 && v.all? { |n| n.is_a?(Integer) && n.between?(0, 20) } && v[0] <= v[1]
        problem(file, "#{where}: #{k} should be [lowest, highest] between 0 and 20.") if block.key?(k) && !ok
        ok
      end
      kind_ok = %w[add sub].include?(block["kind"])
      problem(file, "#{where}: kind should be add or sub.") if block.key?("kind") && !kind_ok
      max_ok = block["max_result"].is_a?(Integer) && block["max_result"].between?(0, 20)
      problem(file, "#{where}: max_result should be a number from 0 to 20.") if block.key?("max_result") && !max_ok
      prefix_ok = str?(block["id_prefix"], ITEM_ID_RE)
      problem(file, "#{where}: id_prefix should be small letters, numbers, - or _.") if block.key?("id_prefix") && !prefix_ok
      return [] unless bad.empty? && missing.empty? && ranges_ok && kind_ok && max_ok && prefix_ok

      add = block["kind"] == "add"
      (block["a"][0]..block["a"][1]).flat_map do |a|
        (block["b"][0]..block["b"][1]).filter_map do |b|
          result = add ? a + b : a - b
          next unless result.between?(0, block["max_result"])

          prompt = {"icon" => block["kind"]}
          prompt["text"] = block["text"] if block.key?("text")
          item = {"id" => "#{block['id_prefix']}-#{a}-#{b}", "rev" => 1, "type" => "count", "skill" => block["skill"],
                  "lvl" => block["lvl"], "diff" => block["diff"], "prompt" => prompt}
          item["response"] = "dial" if block["response"] == "dial"
          item["scene"] = {"groups" => [{"sprite" => block["sprite"], "n" => a},
                                        {"sprite" => block["sprite"], "n" => b, "op" => add ? "+" : "-"}],
                           "layout" => block["layout"]}
          item["answer"] = result
          block["response"] == "dial" ? item["range"] = [0, 20] : item["options"] = "auto"
          item
        end
      end
    end

    def check_item(item, f, label, manifest)
      unless item.is_a?(Hash)
        return problem(f, "#{label} isn't an item. Each item starts with '- id:' and has type, skill and so on.")
      end

      type = item["type"]
      known = ITEM_COMMON + ITEM_TYPE_KEYS.fetch(type, [])
      unknown_keys(item, known, f, label)
      (ITEM_REQUIRED - item.keys).each { |k| problem(f, "#{label} needs #{k}.") }
      (ITEM_TYPE_REQUIRED.fetch(type, []) - item.keys).each { |k| problem(f, "#{label} needs #{k} (#{type} items always have it).") }

      id = item["id"]
      if item.key?("id")
        if str?(id, ITEM_ID_RE)
          @item_ids ||= {}
          if @item_ids.key?(id)
            problem(f, "#{label}: the id #{id} is already used in #{@item_ids[id]}. Every item needs its own id.")
          end
          @item_ids[id] ||= f
          @item_types ||= {}
          @item_types[id] = type
        else
          problem(f, "#{label}: the id should be small letters, numbers, - or _, at most 40 characters.")
        end
      end
      int(item["rev"], f, "#{label}: rev", 1, 255) if item.key?("rev")
      if item.key?("type")
        if PROJECT_TEMPLATES.include?(type) || !TEMPLATES.include?(type)
          template(type, f, label)
        end
      end
      check_item_skill(item, f, label, manifest)
      int(item["diff"], f, "#{label}: diff", 1, 9) if item.key?("diff")
      prompt(item["prompt"], f, label) if item.key?("prompt")
      check_response(item, f, label)
      text(item["hint"], f, "#{label}: the hint", max: 80) if item.key?("hint")
      text(item["fact"], f, "#{label}: the fact", max: 160) if item.key?("fact")
      url(item["source"], f, "#{label}: source") if item.key?("source")
      if item.key?("fact") && item["skill"].is_a?(String) && item["skill"].match?(/\A(moon|planets|earth)\./) &&
         !item.key?("source")
        problem(f, "#{label} has a Moon, planet or Earth fact, so it needs a source: the page the fact comes from.")
      end
      if item.key?("checked") && !(item["checked"].is_a?(String) && DATE_RE.match?(item["checked"]))
        problem(f, "#{label}: checked should be a date like '2026-10-18'.")
      end
      bool(item["self_read"], f, "#{label}: self_read") if item.key?("self_read")
      problem(f, "#{label} has private: true. Community items are for sharing.") if item["private"] == true
      if item.key?("tags") && !(item["tags"].is_a?(Array) && item["tags"].size <= 8 && item["tags"].uniq.size == item["tags"].size &&
                               item["tags"].all? { |t| str?(t, TAG_RE) })
        problem(f, "#{label}: tags should be up to 8 short words in small letters, like [b1, b2].")
      end

      case type
      when "choice" then check_choice(item, f, label)
      when "truefalse" then bool(item["answer"], f, "#{label}: answer", required: true) if item.key?("answer")
      when "sequence" then check_sequence(item, f, label)
      when "count" then check_count(item, f, label)
      when "match" then check_match(item, f, label)
      when "story" then check_story(item, f, label)
      end

      size = JSON.generate(item).bytesize
      return unless size > ITEM_BYTES_MAX

      problem(f, "#{label} is #{size} bytes once compiled; an item is at most #{ITEM_BYTES_MAX}. Make it shorter.")
    end

    def check_item_skill(item, f, label, manifest)
      return unless item.key?("skill")

      skill = item["skill"]
      return problem(f, "#{label}: skill should be a skill id like shapes.flat.") unless str?(skill, SKILL_RE)

      entry = Array(manifest["skills"]).find { |s| s.is_a?(Hash) && s["id"] == skill }
      return problem(f, "#{label} uses the skill #{skill}, which isn't in the skills list in pack.yaml.") unless entry

      return unless item.key?("lvl")

      int(item["lvl"], f, "#{label}: lvl", 1, 15)
      levels = entry["levels"]
      return unless item["lvl"].is_a?(Integer) && levels.is_a?(Integer) && item["lvl"] > levels

      problem(f, "#{label} is level #{item['lvl']}, but #{skill} has only #{levels} levels in pack.yaml.")
    end

    def prompt(p, f, label)
      unless p.is_a?(Hash)
        return problem(f, "#{label}: prompt should look like {icon: find, text: Find the circle.}.")
      end

      unknown_keys(p, %w[icon text parent_line img strip], f, "#{label}: prompt")
      unless PROMPT_ICONS.include?(p["icon"])
        problem(f, "#{label}: the prompt icon should be one of #{PROMPT_ICONS.join(', ')}.")
      end
      text(p["text"], f, "#{label}: the prompt text", max: 80) if p.key?("text")
      text(p["parent_line"], f, "#{label}: the grown-up line", max: 80) if p.key?("parent_line")
      ref(p["img"], "hero", f, "#{label}: the prompt picture") if p.key?("img")
      return unless p.key?("strip")

      strip = p["strip"]
      unless strip.is_a?(Array) && strip.size.between?(2, 6)
        return problem(f, "#{label}: the pattern strip should have 2 to 6 tiles.")
      end

      strip.each_with_index { |t, j| tile(t, f, "#{label}: strip tile #{j + 1}", role: "strip") }
    end

    def check_response(item, f, label)
      return unless item.key?("response")

      case item["response"]
      when "buttons" then nil
      when "dial"
        problem(f, "#{label}: the dial is for count items only.") unless item["type"] == "count"
        problem(f, "#{label}: a dial needs a range, like [0, 10].") unless item.key?("range")
      when "adult_judged"
        problem(f, "#{label}: adult_judged is for choice items only.") unless item["type"] == "choice"
      else
        problem(f, "#{label}: response should be buttons, dial or adult_judged.")
      end
    end

    def check_choice(item, f, label)
      bool(item["shuffle"], f, "#{label}: shuffle") if item.key?("shuffle")
      options = item["options"]
      return unless item.key?("options")
      return problem(f, "#{label}: options should be a list of 2 to 4 tiles.") unless options.is_a?(Array)

      min = item["response"] == "adult_judged" ? 1 : 2
      unless options.size.between?(min, 4)
        problem(f, "#{label} has #{plural(options.size, 'option')}; a choice item has #{min} to 4.")
      end
      options.each_with_index { |o, j| tile(o, f, "#{label}: option #{j + 1}", option: true) }
      oks = options.count { |o| o.is_a?(Hash) && o["ok"] == true }
      return if oks == 1

      problem(f, "#{label} needs exactly one option marked ok: true (it has #{oks}).")
    end

    def check_sequence(item, f, label)
      bool(item["fixed_first"], f, "#{label}: fixed_first") if item.key?("fixed_first")
      seq = item["seq"]
      return unless item.key?("seq")
      unless seq.is_a?(Array) && seq.size.between?(3, 4)
        return problem(f, "#{label}: seq should be 3 or 4 tiles in the right order.")
      end

      problem(f, "#{label}: every tile in seq should be different.") unless seq.uniq.size == seq.size
      seq.each_with_index { |t, j| tile(t, f, "#{label}: seq tile #{j + 1}") }
    end

    def check_count(item, f, label)
      scene = item["scene"]
      if item.key?("scene")
        if scene.is_a?(Hash)
          unknown_keys(scene, %w[bg groups layout seed], f, "#{label}: scene")
          ref(scene["bg"], "bg", f, "#{label}: the background") if scene.key?("bg")
          groups = scene["groups"]
          if groups.is_a?(Array) && groups.size.between?(1, 2)
            groups.each_with_index do |g, j|
              where = "#{label}: group #{j + 1}"
              next problem(f, "#{where} should look like {sprite: apple, n: 3}.") unless g.is_a?(Hash)

              unknown_keys(g, %w[sprite n op], f, where)
              ref(g["sprite"], "sprite", f, "#{where}: the sprite", required: true)
              int(g["n"], f, "#{where}: n", 0, 20, required: true)
              problem(f, "#{where}: op should be + or -.") if g.key?("op") && !%w[+ -].include?(g["op"])
            end
          else
            problem(f, "#{label}: scene groups should be 1 or 2 groups, like [{sprite: apple, n: 3}].")
          end
          if scene.key?("layout") && !%w[scatter grid row tenframe].include?(scene["layout"])
            problem(f, "#{label}: layout should be scatter, grid, row or tenframe.")
          end
          int(scene["seed"], f, "#{label}: seed", 0, 65_535) if scene.key?("seed")
        else
          problem(f, "#{label}: scene should list what to count, like {groups: [{sprite: apple, n: 3}]}.")
        end
      end
      answer = item["answer"]
      int(answer, f, "#{label}: answer", 0, 20) if item.key?("answer")
      if item.key?("options") && item["options"] != "auto"
        opts = item["options"]
        if opts.is_a?(Array) && opts.size.between?(2, 4) && opts.uniq.size == opts.size &&
           opts.all? { |n| n.is_a?(Integer) && n.between?(0, 20) }
          problem(f, "#{label}: options should include the answer, #{answer}.") unless opts.include?(answer)
        else
          problem(f, "#{label}: options should be auto, or 2 to 4 different numbers from 0 to 20.")
        end
      end
      return unless item.key?("range")

      r = item["range"]
      if r.is_a?(Array) && r.size == 2 && r.all? { |n| n.is_a?(Integer) && n.between?(0, 20) } && r[0] < r[1]
        problem(f, "#{label}: the dial range should include the answer, #{answer}.") if answer.is_a?(Integer) && !answer.between?(r[0], r[1])
      else
        problem(f, "#{label}: range should be [lowest, highest] between 0 and 20.")
      end
    end

    def check_match(item, f, label)
      mode = item["mode"]
      problem(f, "#{label}: mode should be memory or pairs.") if item.key?("mode") && !%w[memory pairs].include?(mode)
      pairs = item["pairs"]
      if item.key?("pairs")
        if pairs.is_a?(Array) && [2, 3, 4, 6].include?(pairs.size)
          pairs.each_with_index do |p, j|
            where = "#{label}: pair #{j + 1}"
            next problem(f, "#{where} should look like {a: {img: cat}, b: {word: Cat}}.") unless p.is_a?(Hash)

            unknown_keys(p, %w[a b], f, where)
            tile(p["a"], f, "#{where} a")
            tile(p["b"], f, "#{where} b") if p.key?("b")
            problem(f, "#{where} needs a b tile (pairs mode matches each a with its b).") if mode == "pairs" && !p.key?("b")
          end
        else
          problem(f, "#{label}: a match item has 2, 3, 4 or 6 pairs.")
        end
      end
      return unless item.key?("grid")

      g = item["grid"]
      if g.is_a?(Hash) && (g.keys - %w[cols rows]).empty? && g["cols"].is_a?(Integer) && g["cols"].between?(2, 4) &&
         g["rows"].is_a?(Integer) && g["rows"].between?(1, 3)
        if pairs.is_a?(Array) && g["cols"] * g["rows"] != 2 * pairs.size
          problem(f, "#{label}: a #{g['cols']}x#{g['rows']} grid doesn't fit #{pairs.size * 2} cards.")
        end
      else
        problem(f, "#{label}: grid should be {cols: 2 to 4, rows: 1 to 3}.")
      end
    end

    def check_story(item, f, label)
      pages = item["pages"]
      return unless item.key?("pages")
      return problem(f, "#{label}: a story has 1 to 10 pages.") unless pages.is_a?(Array) && pages.size.between?(1, 10)

      pages.each_with_index do |pg, j|
        where = "#{label}: page #{j + 1}"
        next problem(f, "#{where} should look like {img: fox, text: The fox wakes up.}.") unless pg.is_a?(Hash)

        unknown_keys(pg, %w[img anim text parent_line], f, where)
        ref(pg["img"], "hero", f, "#{where}: the picture", required: true)
        ref(pg["anim"], "anim", f, "#{where}: the animation") if pg.key?("anim")
        text(pg["text"], f, "#{where}: the text", max: 120) if pg.key?("text")
        text(pg["parent_line"], f, "#{where}: the grown-up line", max: 80) if pg.key?("parent_line")
      end
    end

    def tile(t, f, where, option: false, role: "tile")
      return problem(f, "#{where} should be a tile like {img: circle} or {word: Moon}.") unless t.is_a?(Hash)

      unknown_keys(t, %w[img glyph word label] + (option ? %w[ok] : []), f, where)
      kinds = %w[img glyph word].select { |k| t.key?(k) }
      unless kinds.size == 1
        problem(f, "#{where} needs exactly one of img, glyph or word (it has #{kinds.empty? ? 'none' : kinds.join(' and ')}).")
      end
      ref(t["img"], role, f, "#{where}: the picture") if t.key?("img")
      if t.key?("glyph") && !str?(t["glyph"], GLYPH_RE)
        problem(f, "#{where}: a glyph is 1 to 3 capital letters, numbers or + - = ?.")
      end
      text(t["word"], f, "#{where}: the word", max: 12) if t.key?("word")
      text(t["label"], f, "#{where}: the label", max: 12) if t.key?("label")
      bool(t["ok"], f, "#{where}: ok") if option && t.key?("ok")
    end

    # Story `then` and activity `pool.items` point at items; activities should pick at least one item.
    def check_item_links(manifest)
      ids = @item_types || {}
      @items.each do |item, f, label|
        next unless item.is_a?(Hash) && item["type"] == "story" && item.key?("then")
        next if %w[choice truefalse].include?(ids[item["then"]])

        problem(f, "#{label}: then should be the id of a choice or truefalse item in this pack.")
      end
      Array(manifest["activities"]).each_with_index do |a, i|
        next unless a.is_a?(Hash) && a["pool"].is_a?(Hash)

        where = a["id"].is_a?(String) ? "activity #{a['id']}" : "activity #{i + 1}"
        pool = a["pool"]
        if pool["items"].is_a?(Array)
          pool["items"].each do |id|
            problem("pack.yaml", "#{where}: pool item #{id} isn't an item in this pack.") unless ids.key?(id)
          end
        end
        next if @items.empty? || @items.any? { |item, _, _| pool_picks?(pool, item) }

        problem("pack.yaml", "#{where} doesn't pick any item. Check its pool skills, lvl and types.")
      end
    end

    def pool_picks?(pool, item)
      return false unless item.is_a?(Hash)
      return Array(pool["items"]).include?(item["id"]) if pool.key?("items")

      skills_ok = !pool.key?("skills") || Array(pool["skills"]).any? { |g| g.is_a?(String) && glob_match?(g, item["skill"].to_s) }
      lvl = pool["lvl"]
      lvl_ok = !lvl.is_a?(Array) || (item["lvl"].is_a?(Integer) && lvl.size == 2 && item["lvl"].between?(lvl[0].to_i, lvl[1].to_i))
      types_ok = !pool.key?("types") || Array(pool["types"]).include?(item["type"])
      skills_ok && lvl_ok && types_ok
    end

    def glob_match?(glob, skill)
      glob.end_with?(".*") ? skill.start_with?(glob.delete_suffix("*")) : glob == skill
    end

    # ---- pictures ---------------------------------------------------------------------------------------------

    def check_assets(manifest)
      names = manifest["assets"].is_a?(Array) ? manifest["assets"].grep(String) : []
      entries = load_asset_manifest(names)
      svgs = Dir.glob("assets/*.svg", base: dir).sort
      @picture_count = svgs.size
      used_src = {}

      entries.each do |name, (e, f)|
        problem(f, "#{name} is described here but isn't in the assets list in pack.yaml.") unless names.include?(name)
        used_src[e["src"]] = true if e["src"].is_a?(String)
      end
      names.each do |n|
        next if entries.key?(n)

        problem("pack.yaml", "lists the picture #{n} in assets, but assets/manifest.yml doesn't describe it.")
      end
      svgs.each do |rel|
        problem(rel, "isn't used by any entry in assets/manifest.yml.") unless used_src[rel]
        size = entries.values.find { |e, _| e["src"] == rel }&.first&.fetch("size", nil)
        check_svg(rel, size)
      end

      local = @refs.reject { |r| r[:pack] }
      names.each do |n|
        next if local.any? { |r| r[:name] == n }

        problem("pack.yaml", "lists the picture #{n} in assets, but nothing in the pack uses it.")
      end
      credit_patterns = Array(manifest["credits"]).flat_map { |c| c.is_a?(Hash) ? Array(c["assets"]) : [] }.grep(String)
      names.each do |n|
        next if credit_patterns.any? { |p| File.fnmatch?(p, n) }

        problem("pack.yaml", "the picture #{n} isn't covered by any credits entry. {assets: ['*'], ...} covers them all.")
      end

      local.each do |r|
        unless names.include?(r[:name])
          problem(r[:file], "#{r[:where]} is #{r[:name]}, which isn't in the assets list in pack.yaml.")
          next
        end
        e, = entries[r[:name]]
        next unless e && e["size"].is_a?(Array) && e["size"].size == 2 && e["size"].all?(Integer)

        w, h = e["size"]
        if r[:role] == "tile" && [w, h] != [112, 112]
          problem(r[:file], "#{r[:where]} is #{r[:name]}, which is #{w}x#{h}. Answer tiles are 112x112.")
        elsif r[:role] == "hero" && (w > 440 || h > 360)
          problem(r[:file], "#{r[:where]} is #{r[:name]}, which is #{w}x#{h}. Big pictures are at most 440x360.")
        end
      end
      @refs.select { |r| r[:pack] == "rm.core" }.each do |r|
        next if Array(manifest["requires"]).any? { |q| q.is_a?(Hash) && q["id"] == "rm.core" }

        problem(r[:file], "#{r[:where]} borrows #{r[:name]} from rm.core, so pack.yaml needs " \
                          "requires: [{id: rm.core, min_version: 1.0.0}].")
      end
    end

    # => {name => [entry, file]}
    def load_asset_manifest(names)
      rel = "assets/manifest.yml"
      unless File.file?(File.join(dir, rel))
        problem(".", "has pictures in its assets list but no assets/manifest.yml to describe them.") unless names.empty?
        return {}
      end
      list = load_yaml(rel)
      return {} if list == :error
      unless list.is_a?(Array)
        problem(rel, "should be a list of pictures, each starting with '- id:'.")
        return {}
      end

      out = {}
      list.each_with_index do |e, i|
        unless e.is_a?(Hash)
          problem(rel, "entry #{i + 1} should describe one picture (id, src, size, license, credit, source_url).")
          next
        end
        name = e["id"]
        where = str?(name, ASSET_NAME_RE) ? name : "entry #{i + 1}"
        problem(rel, "#{where}: the id should be small letters, numbers and _, at most 32.") unless str?(name, ASSET_NAME_RE)
        unknown_keys(e, ASSET_KEYS, rel, where) do |k|
          k == "photo" ? "#{where} is marked as a photo. For now every picture is an SVG drawing." : nil
        end
        (ASSET_REQUIRED - e.keys).each { |k| problem(rel, "#{where} needs #{k}.") }
        check_asset_entry(e, rel, where)
        next unless str?(name, ASSET_NAME_RE)

        problem(rel, "#{name} is described twice.") if out.key?(name)
        out[name] = [e, rel]
      end
      out
    end

    def check_asset_entry(e, rel, where)
      if e.key?("src")
        src = e["src"]
        if src.is_a?(String) && src.match?(%r{\Aassets/[A-Za-z0-9_-][A-Za-z0-9_.-]*\.svg\z}) && !src.include?("..")
          problem(rel, "#{where}: the file #{src} isn't there.") unless File.file?(File.join(dir, src))
        else
          problem(rel, "#{where}: src should be an SVG file in this pack's assets folder, like assets/circle.svg.")
        end
      end
      if e.key?("size")
        w, h = e["size"].is_a?(Array) && e["size"].size == 2 ? e["size"] : [nil, nil]
        if w.is_a?(Integer) && h.is_a?(Integer) && w.positive? && h.positive?
          problem(rel, "#{where}: the size #{w}x#{h} should use multiples of 8, like 112x112.") unless (w % 8).zero? && (h % 8).zero?
          problem(rel, "#{where}: the size #{w}x#{h} is bigger than the screen (480x800).") if w > 480 || h > 800
        else
          problem(rel, "#{where}: size should be [width, height], like [112, 112].")
        end
      end
      if e.key?("mode") && e["mode"] != "1bit"
        problem(rel, "#{where}: pictures are black-and-white (mode: 1bit). Use a pattern where you want grey.")
      end
      if e.key?("dither") && e["dither"] != "none"
        problem(rel, "#{where}: drawings use dither: none (or leave it out).")
      end
      if e.key?("mask") && !%w[alpha opaque none].include?(e["mask"])
        problem(rel, "#{where}: mask should be alpha, opaque or none.")
      end
      int(e["frames"], rel, "#{where}: frames", 1, 8) if e.key?("frames")
      int(e["frame_ms"], rel, "#{where}: frame_ms", 100, 5000) if e.key?("frame_ms")
      bool(e["static_only"], rel, "#{where}: static_only") if e.key?("static_only")
      if e.key?("license") && e["license"] != LICENSE
        problem(rel, "#{where} has the license #{e['license'].inspect}. Every picture here is #{LICENSE}.")
      end
      text(e["credit"], rel, "#{where}: the credit", max: 80) if e.key?("credit")
      url(e["source_url"], rel, "#{where}: source_url") if e.key?("source_url") && !e["source_url"].nil?
    end

    def check_svg(rel, size)
      path = File.join(dir, rel)
      bytes = File.size(path)
      if bytes > PICTURE_BYTES_MAX
        return problem(rel, "is #{kib(bytes)}. A picture is at most #{kib(PICTURE_BYTES_MAX)}; simplify the drawing.")
      end

      info, messages = Svg.check(File.binread(path))
      messages.uniq.each { |m| problem(rel, m) }
      return unless info && size.is_a?(Array) && size.size == 2 && size.all? { |n| n.is_a?(Integer) && n.positive? }

      vw, vh = info[:view_box]
      w, h = size
      return if (vw * h - vh * w).abs <= 0.01 * vw * h

      problem(rel, "has a viewBox of #{fmt(vw)}x#{fmt(vh)}, but assets/manifest.yml says #{w}x#{h}. Make the " \
                   "shapes match so the picture isn't squashed.")
    end

    # ---- small helpers ----------------------------------------------------------------------------------------

    def problem(file, message)
      @problems << Problem.new(file, message)
      nil
    end

    def ref(value, role, f, where, required: false)
      if value.nil?
        problem(f, "#{where} is missing.") if required
        return
      end
      m = value.is_a?(String) && ASSET_REF_RE.match(value)
      return problem(f, "#{where} should be a picture name, like circle.") unless m

      pack = m[1]
      if pack && pack != "rm.core"
        return problem(f, "#{where} borrows from #{pack}. Community packs can borrow pictures from rm.core only.")
      end

      @refs << {name: m[2], pack: pack, role: role, file: f, where: where}
    end

    def text(value, f, where, max:, required: false)
      if value.nil?
        problem(f, "#{where} is missing.") if required
        return
      end
      unless value.is_a?(String)
        if [true, false].include?(value)
          return problem(f, "#{where} should be text, but YAML read it as #{value}. Words like Yes, No, On and " \
                            "Off need quotes around them, like 'No'.")
        end
        return problem(f, "#{where} should be text, but YAML read it as #{value.inspect}. Put quotes around it, " \
                          "like '#{value}'.")
      end
      return problem(f, "#{where} is empty.") if value.strip.empty?

      problem(f, "#{where} is #{value.length} characters; keep it to #{max} or fewer.") if value.length > max
      unless TEXT_RE.match?(value)
        bad = value.chars.reject { |c| TEXT_RE.match?(c) }.uniq.map(&:inspect).join(", ")
        problem(f, "#{where} uses #{bad}, which the screen can't show. Curly quotes and emoji are the usual " \
                   "culprits; use plain letters and punctuation.")
      end
      problem(f, "#{where} has a web or email address in it. Packs never carry links or addresses.") if LINK_RE.match?(value)
    end

    def url(value, f, where)
      return if value.is_a?(String) && HTTPS_RE.match?(value) && value.length <= 200

      problem(f, "#{where} should be a web address starting with https://, at most 200 characters.")
    end

    def int(value, f, where, min, max, required: false)
      if value.nil?
        problem(f, "#{where} is missing.") if required
        return
      end
      return if value.is_a?(Integer) && value.between?(min, max)

      problem(f, "#{where} should be a whole number from #{min} to #{max}.")
    end

    def bool(value, f, where, required: false)
      return if [true, false].include?(value) || (value.nil? && !required)

      problem(f, "#{where} should be true or false.")
    end

    def unknown_keys(hash, allowed, f, where)
      (hash.keys - allowed).each do |k|
        custom = block_given? ? yield(k) : nil
        problem(f, custom || "#{where} has a field called #{k}, which doesn't belong there.")
      end
    end

    def str?(value, re) = value.is_a?(String) && re.match?(value)
    def plural(n, word) = PackCheck.plural(n, word)
    def kib(bytes) = "#{(bytes / 1024.0).ceil} KiB"
    def fmt(n) = n == n.to_i ? n.to_i.to_s : n.to_s
  end

  # A strict reader for the small part of SVG that packs use: plain shapes filled with black, white or patterns.
  # Anything outside that subset is reported, not interpreted.
  module Svg
    NS = "http://www.w3.org/2000/svg"
    ELEMENTS = %w[svg g defs pattern rect circle ellipse line polyline polygon path].freeze
    PAINT_ATTRS = %w[fill stroke stroke-width stroke-linejoin stroke-linecap stroke-miterlimit stroke-dasharray
                     stroke-dashoffset fill-rule transform id].freeze
    ATTRS = {
      "svg" => PAINT_ATTRS + %w[xmlns viewBox width height version],
      "g" => PAINT_ATTRS,
      "defs" => %w[id],
      "pattern" => PAINT_ATTRS + %w[x y width height patternUnits patternContentUnits patternTransform viewBox],
      "rect" => PAINT_ATTRS + %w[x y width height rx ry],
      "circle" => PAINT_ATTRS + %w[cx cy r],
      "ellipse" => PAINT_ATTRS + %w[cx cy rx ry],
      "line" => PAINT_ATTRS + %w[x1 y1 x2 y2],
      "polyline" => PAINT_ATTRS + %w[points],
      "polygon" => PAINT_ATTRS + %w[points],
      "path" => PAINT_ATTRS + %w[d]
    }.freeze
    WORDS = "has words in it. Pictures carry no text: draw letters as shapes, or use a word tile in the item."
    BLOCKED = {
      "text" => WORDS, "tspan" => WORDS, "textPath" => WORDS,
      "title" => "has a title or description inside it. Leave those out; pictures carry no text.",
      "desc" => "has a title or description inside it. Leave those out; pictures carry no text.",
      "script" => "has a script. Pictures are drawings only and never run code.",
      "image" => "has an embedded or linked image. Draw the picture with shapes instead.",
      "foreignObject" => "has embedded web content. Pictures are drawings only.",
      "style" => "has a style sheet. Set fill and stroke on each shape instead.",
      "a" => "has a link. Pictures never link anywhere.",
      "use" => "reuses a shape by reference (<use>). Copy the shape instead.",
      "linearGradient" => "has a gradient. The screen is black and white only; use a pattern for grey.",
      "radialGradient" => "has a gradient. The screen is black and white only; use a pattern for grey.",
      "filter" => "has a filter effect (blur, shadow and so on). Use plain shapes and patterns.",
      "animate" => "has an animation. Pictures are still drawings.",
      "set" => "has an animation. Pictures are still drawings.",
      "animateTransform" => "has an animation. Pictures are still drawings.",
      "animateMotion" => "has an animation. Pictures are still drawings."
    }.freeze
    BLACK = %w[#000 #000000 black].freeze
    WHITE = %w[#fff #ffffff white].freeze
    NUMBER = /[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?/
    LENGTH_RE = /\A\s*#{NUMBER}(?:px)?\s*\z/
    NUMBER_LIST_RE = /\A[\d\s,.+eE-]*\z/
    PATH_RE = /\A[MmZzLlHhVvCcSsQqTtAa\d\s,.+eE-]*\z/
    TRANSFORM_RE = /\A(?:\s*(?:matrix|translate|scale|rotate|skewX|skewY)\s*\([\d\s,.+eE-]*\)\s*,?)*\s*\z/
    ID_RE = /\A[A-Za-z_][\w.-]*\z/
    NAME_RE = /[A-Za-z_][\w.:-]*/
    LENGTH_ATTRS = %w[x y width height cx cy r rx ry x1 y1 x2 y2 stroke-width stroke-miterlimit
                      stroke-dashoffset].freeze
    ENUMS = {
      "stroke-linejoin" => %w[miter round bevel arcs miter-clip], "stroke-linecap" => %w[butt round square],
      "fill-rule" => %w[nonzero evenodd], "patternUnits" => %w[userSpaceOnUse objectBoundingBox],
      "patternContentUnits" => %w[userSpaceOnUse objectBoundingBox]
    }.freeze

    Element = Struct.new(:name, :attrs, :children, :text)

    module_function

    # => [info or nil, Array<String>]. info is {view_box: [w, h]} for a drawing that passed.
    def check(bytes)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      return [nil, ["isn't saved as UTF-8 text. Save it again as plain SVG."]] unless text.valid_encoding?

      return [nil, [BLOCKED["script"]]] if text.match?(/<\s*script\b/i)

      root, error = parse(text.delete_prefix("\uFEFF"))
      return [nil, [error]] if error

      messages = []
      messages << "isn't an SVG drawing (its outer element is <#{root.name}>)." unless root.name == "svg"
      messages << %(needs xmlns="#{NS}" on its <svg> element.) unless root.attrs["xmlns"] == NS
      view_box = root.attrs["viewBox"].to_s.strip.split(/[\s,]+/)
      if view_box.size == 4 && view_box.all? { |n| n.match?(/\A#{NUMBER}\z/) } && view_box[2].to_f.positive? &&
         view_box[3].to_f.positive?
        view_box = view_box[2, 2].map(&:to_f)
      else
        messages << 'needs a viewBox on its <svg> element, like viewBox="0 0 112 112".'
        view_box = nil
      end
      patterns = []
      paint_refs = []
      walk(root) do |el|
        if (why = BLOCKED[el.name])
          messages << why
          next
        end
        messages << WORDS if el.text
        unless ELEMENTS.include?(el.name)
          messages << "uses <#{el.name}>, which isn't one of the drawing elements a pack can use " \
                      "(#{ELEMENTS.join(', ')}). Drawing apps add extras like this; save as plain SVG."
          next
        end
        patterns << el.attrs["id"] if el.name == "pattern" && el.attrs["id"]
        el.attrs.each { |name, value| check_attr(el.name, name, value, messages, paint_refs) }
      end
      (paint_refs - patterns).uniq.each do |id|
        messages << "fills with url(##{id}), but there's no <pattern id=\"#{id}\"> in the file."
      end
      [messages.empty? ? {view_box: view_box} : nil, messages]
    end

    def check_attr(el, name, value, messages, paint_refs)
      if name.start_with?("on")
        return messages << "has an event handler (#{name}), which is a script. Pictures never run code."
      end
      return messages << "links to another file or address (#{name}). Pictures are self-contained." if name.include?("href")
      return messages << 'uses a style attribute. Set fill and stroke as their own attributes, like fill="#000".' if name == "style"
      return messages << "uses class names (styles). Set fill and stroke on each shape instead." if name == "class"
      if %w[opacity fill-opacity stroke-opacity].include?(name)
        return messages << "makes shapes see-through (#{name}), which turns them grey. Use a pattern for grey."
      end
      if name.include?(":")
        return messages << "has #{name}, which drawing apps add. Save as plain SVG (in Inkscape: Save As, " \
                           "Plain SVG) so only the drawing is left."
      end
      unless ATTRS.fetch(el).include?(name)
        return messages << "has #{name} on <#{el}>, which isn't one of the attributes a pack's pictures use."
      end

      ok = case name
           when "fill", "stroke" then paint?(value, paint_refs, messages)
           when "xmlns" then value == NS
           when "viewBox" then value.match?(NUMBER_LIST_RE)
           when "version" then value.match?(/\A[\d.]+\z/)
           when "id" then value.match?(ID_RE)
           when "points" then value.match?(NUMBER_LIST_RE)
           when "d" then value.match?(PATH_RE)
           when "transform", "patternTransform" then value.match?(TRANSFORM_RE)
           when "stroke-dasharray" then value.strip == "none" || value.match?(NUMBER_LIST_RE)
           when *ENUMS.keys then ENUMS[name].include?(value.strip)
           when *LENGTH_ATTRS then value.match?(LENGTH_RE)
           else false
           end
      messages << "has #{name}=\"#{value[0, 40]}\" on <#{el}>, which isn't a plain value a picture can use." unless ok
    end

    # Black, white, none, or a pattern defined in the same file.
    def paint?(value, paint_refs, messages)
      v = value.strip.downcase
      return true if BLACK.include?(v) || WHITE.include?(v) || v == "none"

      if (m = value.strip.match(/\Aurl\(\s*#([A-Za-z_][\w.-]*)\s*\)\z/))
        paint_refs << m[1]
        return true
      end
      if v.start_with?("url(")
        messages << "fills with #{value.strip[0, 40]}, which points outside the file. Use a pattern defined in " \
                    "the same file, like url(#dots)."
        return true
      end
      messages << "uses the colour #{value.strip[0, 40]}. Pictures use only black (#000), white (#fff), and " \
                  "patterns made of them."
      true
    end

    def walk(el, &block)
      yield el
      el.children.each { |c| walk(c, &block) }
    end

    # => [root Element, nil] or [nil, message]
    def parse(text)
      s = StringScanner.new(text)
      s.skip(/\s*<\?xml\s[^?<>]*\?>/)
      stack = []
      root = nil
      until s.eos?
        if s.skip(/<!--/)
          return [nil, "has a comment that never ends (<!-- without -->)."] unless s.skip_until(/-->/)
        elsif s.check(/<!/)
          return [nil, "has a DOCTYPE, entity or CDATA section. Save it as plain SVG without them."]
        elsif s.check(/<\?/)
          return [nil, "has a processing instruction (<?...?>). Only the first <?xml ...?> line is allowed."]
        elsif s.skip(%r{</})
          name = s.scan(NAME_RE)
          return [nil, "has a broken closing tag."] unless name && s.skip(/\s*>/)
          return [nil, "closes </#{name}> without opening it."] unless stack.last&.name == name

          stack.pop
        elsif s.skip(/</)
          name = s.scan(NAME_RE) or return [nil, "has a broken tag (a < that doesn't start an element)."]
          attrs = {}
          closed = false
          loop do
            spaced = s.skip(/\s+/)
            if s.skip(%r{/>})
              closed = true
              break
            elsif s.skip(/>/)
              break
            elsif spaced && (attr = s.scan(NAME_RE))
              return [nil, "has an attribute #{attr} without a value on <#{name}>."] unless s.skip(/\s*=\s*/)

              quote = s.scan(/["']/) or return [nil, "has an attribute #{attr} without quotes on <#{name}>."]
              value = s.scan_until(quote == '"' ? /"/ : /'/) or return [nil, "has an attribute that never ends on <#{name}>."]
              value = value.chop
              return [nil, "has a < inside the attribute #{attr} on <#{name}>."] if value.include?("<")
              if value.include?("&")
                return [nil, "uses an & character code in #{attr} on <#{name}>. Plain drawings don't need them."]
              end
              return [nil, "has the attribute #{attr} twice on <#{name}>."] if attrs.key?(attr)

              attrs[attr] = value
            else
              return [nil, "has a broken tag <#{name}>."]
            end
          end
          el = Element.new(name, attrs, [], false)
          if stack.empty?
            return [nil, "has more than one outer element. Everything belongs inside one <svg>."] if root

            root = el
          else
            stack.last.children << el
          end
          stack << el unless closed
        else
          chunk = s.scan(/[^<]+/)
          next if chunk.strip.empty?
          return [nil, "has text outside the drawing."] if stack.empty?

          stack.last.text = true
        end
      end
      return [nil, "has <#{stack.last.name}> that is never closed."] unless stack.empty?
      return [nil, "is empty or isn't an SVG drawing."] unless root

      [root, nil]
    end
  end

  module_function

  # annotate: also print GitHub Actions annotations, so messages show next to the files in a pull request.
  def run(argv, out: $stdout, root: ROOT, base: Dir.pwd, annotate: false)
    if argv.intersect?(%w[-h --help])
      out.puts "usage: ruby scripts/check_packs.rb [pack folder ...]"
      out.puts "With no folders it checks every pack in packs/."
      return 0
    end

    stray = []
    dirs = if argv.empty?
             packs = File.join(root, "packs")
             all = Dir.exist?(packs) ? Dir.children(packs).sort.map { |n| File.join(packs, n) } : []
             stray = all.reject { |p| File.directory?(p) && !File.symlink?(p) }
             all - stray
           else
             argv
           end
    if dirs.empty? && stray.empty?
      out.puts "No packs found. Packs live in folders under packs/, like packs/cm.example.shapes."
      return 1
    end

    stray.each { |p| out.puts "#{display(p, base)}: only pack folders belong in packs/; move or delete this." }
    results = dirs.map { |d| Checker.new(d).run }
    results.each { |r| report(r, out, base, annotate) }

    bad = results.reject(&:ok?)
    count = bad.sum { |r| r.problems.size } + stray.size
    out.puts
    if count.zero?
      out.puts(results.size == 1 ? "The pack looks good." : "All #{results.size} packs look good.")
      0
    else
      packs = bad.size == 1 ? "1 pack" : "#{bad.size} packs"
      out.puts "Found #{count} #{count == 1 ? 'problem' : 'problems'}#{bad.empty? ? '' : " in #{packs}"}. " \
               "Fix #{count == 1 ? 'it' : 'them'} and run the checker again; CONTRIBUTING.md explains each rule."
      1
    end
  end

  def report(result, out, base, annotate)
    name = display(result.dir, base)
    if result.ok?
      out.puts "#{name}: looks good (#{plural(result.item_count, 'item')}, #{plural(result.picture_count, 'picture')})"
      return
    end

    out.puts
    out.puts "#{name}: #{plural(result.problems.size, 'problem')}"
    result.problems.group_by(&:file).each do |file, problems|
      out.puts "  #{file == '.' ? 'the pack folder' : file}"
      problems.each do |p|
        out.puts "    - #{p.message}"
        out.puts annotation(result.dir, file, p.message, base) if annotate
      end
    end
  end

  def annotation(dir, file, message, base)
    path = display(file == "." ? dir : File.join(dir, file), base)
    escaped = message.gsub("%", "%25").gsub("\r", "%0D").gsub("\n", "%0A")
    "::error file=#{path.gsub('%', '%25').gsub(',', '%2C').gsub(':', '%3A')}::#{escaped}"
  end

  def display(path, base)
    full = File.expand_path(path)
    full.start_with?("#{base}/") ? full.delete_prefix("#{base}/") : full
  end

  def plural(n, word) = "#{n} #{word}#{n == 1 ? '' : 's'}"
end

exit(PackCheck.run(ARGV, annotate: ENV["GITHUB_ACTIONS"] == "true")) if $PROGRAM_NAME == __FILE__
