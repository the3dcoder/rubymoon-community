# frozen_string_literal: true

require_relative "test_helper"

class FolderTest < PackTest
  def test_the_example_pack_passes
    assert_clean(EXAMPLE)
    assert_clean
  end

  def test_id_must_be_a_community_id
    rename_pack("rm.shapes.copy")
    assert_problem(/isn't a community pack id/, file: ".")
    assert_problem(/isn't a community pack id/, file: "pack.yaml")
  end

  def test_id_must_have_a_handle_and_a_name
    rename_pack("cm.shapes")
    assert_problem(/isn't a community pack id/)
  end

  def test_id_must_fit_in_32_characters
    rename_pack("cm.robin.a-very-long-pack-name-xy")
    assert_problem(/is 33 characters long. Pack ids are at most 32/)
  end

  def test_id_must_match_the_folder
    change_manifest { |m| m["id"] = "cm.example.circles" }
    assert_problem(/the folder is called cm.example.shapes/, file: "pack.yaml")
  end

  def test_readme_and_changelog_are_needed
    File.delete(path("README.md"))
    File.delete(path("CHANGELOG.md"))
    assert_problem(/needs a README.md/, file: ".")
    assert_problem(/needs a CHANGELOG.md/, file: ".")
  end

  def test_pack_yaml_is_needed
    File.delete(path("pack.yaml"))
    assert_problem(/needs a pack.yaml/, file: ".")
  end

  def test_unexpected_files_are_reported
    write("notes.txt", "hello")
    write("pack.json", "{}")
    assert_problem(/isn't something a pack holds/, file: "notes.txt")
    assert_problem(/Community packs use pack.yaml/, file: "pack.json")
  end

  def test_photos_and_bitmaps_are_reported
    write("assets/cat.png", "\x89PNG\r\n".b)
    assert_problem(/is a photo or bitmap file/, file: "assets/cat.png")
  end

  def test_links_are_reported
    File.symlink("/etc/hostname", path("assets/link.svg"))
    assert_problem(/is a link to somewhere else/, file: "assets/link.svg")
  end

  def test_pack_size_is_capped
    write("items/90-big.yaml", "# #{'x' * PackCheck::PACK_BYTES_MAX}\n")
    assert_problem(/A community pack stays under 1024 KiB/, file: ".")
  end

  def test_broken_yaml_is_reported
    write(ITEMS, "- id: find-circle\n  rev: [1\n")
    assert_problem(/can't be read as YAML/, file: ITEMS)
  end
end

class ManifestTest < PackTest
  def test_license_must_be_cc0
    change_manifest { |m| m["license"] = "MIT" }
    assert_problem(/has the license "MIT". Everything here is shared as CC0-1.0/, file: "pack.yaml")
  end

  def test_credit_license_must_be_cc0
    change_manifest { |m| m["credits"][0]["license"] = "CC-BY-4.0" }
    assert_problem(/credit 1 has the license "CC-BY-4.0"/, file: "pack.yaml")
  end

  def test_required_fields
    change_manifest { |m| %w[title description credits].each { |k| m.delete(k) } }
    assert_problem(/needs a title field/, file: "pack.yaml")
    assert_problem(/needs a description field/, file: "pack.yaml")
    assert_problem(/needs a credits field/, file: "pack.yaml")
  end

  def test_version_must_be_three_numbers
    change_manifest { |m| m["version"] = 1.0 }
    assert_problem(/version should look like 1.0.0/, file: "pack.yaml")
  end

  def test_author_must_be_community
    change_manifest { |m| m["author"] = {"kind" => "release", "name" => "Someone"} }
    assert_problem(/Community packs use kind: community/, file: "pack.yaml")
  end

  def test_author_url_is_not_used
    change_manifest { |m| m["author"]["url"] = "https://example.com" }
    assert_problem(/author has a url/, file: "pack.yaml")
  end

  def test_private_and_system_are_refused
    change_manifest do |m|
      m["private"] = true
      m["system"] = true
    end
    assert_problem(/has private: true/, file: "pack.yaml")
    assert_problem(/has system: true/, file: "pack.yaml")
  end

  def test_scripts_and_unknown_fields_are_refused
    change_manifest do |m|
      m["scripts"] = []
      m["colour"] = "red"
    end
    assert_problem(/has a scripts section/, file: "pack.yaml")
    assert_problem(/has a field called colour/, file: "pack.yaml")
  end

  def test_requires_only_rm_core
    change_manifest { |m| m["requires"] = [{"id" => "cm.robin.farm", "min_version" => "1.0.0"}] }
    assert_problem(/may borrow pictures from rm.core only/, file: "pack.yaml")
  end

  def test_borrowing_from_rm_core_needs_requires
    change_manifest { |m| m["icon"] = "rm.core:icon_find" }
    assert_problem(/borrows icon_find from rm.core, so pack.yaml needs requires/, file: "pack.yaml")
  end

  def test_borrowing_from_other_packs_is_refused
    change_manifest { |m| m["icon"] = "cm.robin.farm:cow" }
    assert_problem(/Community packs can borrow pictures from rm.core only/, file: "pack.yaml")
  end

  def test_title_limit_and_characters
    change_manifest { |m| m["title"] = "Find the Shape and Then Find Another One" }
    assert_problem(/The title is 40 characters; keep it to 32 or fewer/, file: "pack.yaml")
  end

  def test_activity_basics
    change_manifest do |m|
      a = m["activities"][0]
      a["template"] = "rocket"
      a["world"] = "ocean"
      a["bands"] = ["B9"]
    end
    assert_problem(/uses the rocket template/, file: "pack.yaml")
    assert_problem(/world should be one of/, file: "pack.yaml")
    assert_problem(/bands should be a list of ages/, file: "pack.yaml")
  end

  def test_activity_that_picks_nothing
    change_manifest { |m| m["activities"][0]["pool"]["lvl"] = [3, 3] }
    assert_problem(/activity find-shape doesn't pick any item/, file: "pack.yaml")
  end

  def test_pool_skill_must_exist
    change_manifest { |m| m["activities"][0]["pool"]["skills"] = ["moon.*"] }
    assert_problem(/pool skill moon.\* doesn't match any skill/, file: "pack.yaml")
  end

  def test_pool_items_must_exist
    change_manifest { |m| m["activities"][0]["pool"] = {"items" => ["find-hexagon"]} }
    assert_problem(/pool item find-hexagon isn't an item in this pack/, file: "pack.yaml")
  end

  def test_skill_must_be_from_the_taxonomy
    change_manifest { |m| m["skills"] << {"id" => "shapes.flatt", "levels" => 3} }
    assert_problem(/skill shapes.flatt isn't one of Ruby Moon's skills/, file: "pack.yaml")
  end

  def test_skill_levels_and_start_match_the_taxonomy
    change_manifest do |m|
      m["skills"][0]["levels"] = 5
      m["skills"][0]["start"] = [1, 1, 1, 1, 1]
      m["skills"] << {"id" => "addsub.add", "levels" => 3, "prereq" => [{"skill" => "count.objects", "lvl" => 1}]}
    end
    assert_problem(/skill shapes.flat has 3 levels in Ruby Moon, so use levels: 3/, file: "pack.yaml")
    assert_problem(/skill shapes.flat: start should be \[1, 1, 2, 3, 3\]/, file: "pack.yaml")
    assert_problem(/skill addsub.add: prereq should be \{skill: count.objects, lvl: 3\}/, file: "pack.yaml")
  end

  def test_manifest_size_is_capped
    change_manifest do |m|
      m["skills"] += (1..60).map { |i| {"id" => "shapes.extra#{i}", "levels" => 3, "title" => "A long skill title, number #{i}"} }
    end
    assert_problem(/once compiled; a manifest is at most 4096/, file: "pack.yaml")
  end
end

class ItemTest < PackTest
  def test_text_limits
    change_items do |list|
      item(list, "find-circle")["hint"] = "A circle is round all the way around, with no corners and no straight sides at all."
      item(list, "find-square")["prompt"]["text"] = "Find the square. " * 5
      item(list, "find-triangle")["options"][1] = {"word" => "A round circle"}
      item(list, "square-corners")["fact"] = "x" * 161
    end
    assert_problem(/item "find-circle": the hint is 83 characters; keep it to 80 or fewer/, file: ITEMS)
    assert_problem(/item "find-square": the prompt text is 85 characters/, file: ITEMS)
    assert_problem(/item "find-triangle": option 2: the word is 14 characters; keep it to 12/, file: ITEMS)
    assert_problem(/item "square-corners": the fact is 161 characters; keep it to 160/, file: ITEMS)
  end

  def test_characters_the_screen_cannot_show
    change_items { |list| item(list, "find-circle")["prompt"]["text"] = "Find the circle\u2019s edge \u{1F315}" }
    assert_problem(/uses "\u2019", "\u{1F315}", which the screen can't show/, file: ITEMS)
  end

  def test_links_and_addresses_in_text
    address = ["robin", "example.org"].join("@") # built here so the repository holds no address
    change_items do |list|
      item(list, "find-circle")["hint"] = "More at www.example.org"
      item(list, "find-square")["hint"] = "Write to #{address}"
    end
    assert_problem(/item "find-circle": the hint has a web or email address/, file: ITEMS)
    assert_problem(/item "find-square": the hint has a web or email address/, file: ITEMS)
  end

  def test_yaml_yes_and_no_need_quotes
    write(ITEMS, read(ITEMS).sub("- {img: square}\n  hint: A circle", "- {word: No}\n  hint: A circle"))
    assert_problem(/the word should be text, but YAML read it as false. Words like Yes, No/, file: ITEMS)
  end

  def test_exactly_one_right_answer
    change_items do |list|
      item(list, "find-circle")["options"][1]["ok"] = true
      item(list, "find-square")["options"][0].delete("ok")
    end
    assert_problem(/item "find-circle" needs exactly one option marked ok: true \(it has 2\)/, file: ITEMS)
    assert_problem(/item "find-square" needs exactly one option marked ok: true \(it has 0\)/, file: ITEMS)
  end

  def test_option_count
    change_items { |list| item(list, "find-circle")["options"] = [{"img" => "circle", "ok" => true}] }
    assert_problem(/item "find-circle" has 1 option; a choice item has 2 to 4/, file: ITEMS)
  end

  def test_tile_needs_one_kind
    change_items { |list| item(list, "find-circle")["options"][1] = {"img" => "square", "word" => "Square"} }
    assert_problem(/needs exactly one of img, glyph or word \(it has img and word\)/, file: ITEMS)
  end

  def test_item_types
    change_items do |list|
      item(list, "find-circle")["type"] = "rocket"
      item(list, "find-square")["type"] = "quiz"
    end
    assert_problem(/item "find-circle" uses the rocket template/, file: ITEMS)
    assert_problem(/item "find-square": "quiz" isn't a template/, file: ITEMS)
  end

  def test_item_ids
    change_items do |list|
      item(list, "find-square")["id"] = "find-circle"
      item(list, "find-triangle")["id"] = "Find Triangle"
    end
    assert_problem(/the id find-circle is already used/, file: ITEMS)
    assert_problem(/the id should be small letters, numbers, - or _/, file: ITEMS)
  end

  def test_skill_and_level
    change_items do |list|
      item(list, "find-circle")["skill"] = "shapes.solid"
      item(list, "find-square")["lvl"] = 4
    end
    assert_problem(/uses the skill shapes.solid, which isn't in the skills list/, file: ITEMS)
    assert_problem(/item "find-square" is level 4, but shapes.flat has only 3 levels/, file: ITEMS)
  end

  def test_required_and_unknown_fields
    change_items do |list|
      item(list, "find-circle").delete("rev")
      item(list, "find-square")["colour"] = "red"
      item(list, "square-corners").delete("fact")
    end
    assert_problem(/item "find-circle" needs rev/, file: ITEMS)
    assert_problem(/item "find-square" has a field called colour/, file: ITEMS)
    assert_problem(/item "square-corners" needs fact \(truefalse items always have it\)/, file: ITEMS)
  end

  def test_private_items_are_refused
    change_items { |list| item(list, "find-circle")["private"] = true }
    assert_problem(/has private: true. Community items are for sharing/, file: ITEMS)
  end

  def test_space_facts_need_a_source
    change_manifest { |m| m["skills"] << {"id" => "moon.facts", "levels" => 3} }
    change_items do |list|
      list << {"id" => "moon-round", "rev" => 1, "type" => "truefalse", "skill" => "moon.facts", "lvl" => 1,
               "diff" => 1, "prompt" => {"icon" => "yesno", "text" => "Is the Moon round?"}, "answer" => true,
               "fact" => "The Moon is shaped like a ball."}
    end
    assert_problem(/needs a source: the page the fact comes from/, file: ITEMS)
  end

  def test_item_size_is_capped
    pages = (1..10).map { |i| {"img" => "square", "text" => "Page #{i}. #{'Long words here. ' * 6}", "parent_line" => "Ask: what comes next? " * 3} }
    change_items do |list|
      list << {"id" => "long-story", "rev" => 1, "type" => "story", "skill" => "shapes.flat", "lvl" => 1, "diff" => 1, "pages" => pages}
    end
    assert_problem(/item "long-story" is \d+ bytes once compiled; an item is at most 2048/, file: ITEMS)
  end

  def test_item_count_is_capped
    many = (1..301).map do |i|
      {"id" => "find-circle-#{i}", "rev" => 1, "type" => "choice", "skill" => "shapes.flat", "lvl" => 1, "diff" => 1,
       "prompt" => {"icon" => "find"}, "options" => [{"img" => "circle", "ok" => true}, {"img" => "square"}]}
    end
    write("items/20-many.yaml", YAML.dump(many))
    assert_problem(/has 305 items. A community pack has at most 300/, file: ".")
  end

  def test_generate_blocks_expand_to_count_items
    change_items do |list|
      list << {"generate" => {"kind" => "add", "id_prefix" => "add-stars", "skill" => "shapes.flat", "lvl" => 1,
                              "diff" => 1, "a" => [0, 2], "b" => [0, 2], "max_result" => 3, "sprite" => "star",
                              "layout" => "row", "text" => "How many stars?"}}
    end
    result = checker
    assert_empty result.problems.map(&:message)
    assert_equal 4 + 8, result.item_count
  end

  def test_broken_generate_block
    change_items { |list| list << {"generate" => {"kind" => "times", "a" => [0, 30]}} }
    assert_problem(/generate block 5: kind should be add or sub/, file: ITEMS)
    assert_problem(/generate block 5: a should be \[lowest, highest\] between 0 and 20/, file: ITEMS)
    assert_problem(/generate block 5 needs id_prefix/, file: ITEMS)
  end

  def test_story_then_must_point_at_a_question
    change_items do |list|
      list << {"id" => "shape-story", "rev" => 1, "type" => "story", "skill" => "shapes.flat", "lvl" => 1, "diff" => 1,
               "pages" => [{"img" => "square", "text" => "Here is a square."}], "then" => "find-hexagon"}
    end
    assert_problem(/item "shape-story": then should be the id of a choice or truefalse item/, file: ITEMS)
  end
end
