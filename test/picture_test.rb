# frozen_string_literal: true

require_relative "test_helper"

class AssetManifestTest < PackTest
  def test_picture_license_must_be_cc0
    change_pictures { |list| list[0]["license"] = "CC-BY-SA-4.0" }
    assert_problem(/circle has the license "CC-BY-SA-4.0". Every picture here is CC0-1.0/, file: "assets/manifest.yml")
  end

  def test_picture_needs_credit_and_source_url
    change_pictures { |list| %w[credit source_url].each { |k| list[0].delete(k) } }
    assert_problem(/circle needs credit/, file: "assets/manifest.yml")
    assert_problem(/circle needs source_url/, file: "assets/manifest.yml")
  end

  def test_photos_are_not_accepted_yet
    change_pictures { |list| list[0]["photo"] = true }
    assert_problem(/circle is marked as a photo/, file: "assets/manifest.yml")
  end

  def test_pictures_are_one_bit
    change_pictures { |list| list[0]["mode"] = "2bit" }
    assert_problem(/pictures are black-and-white \(mode: 1bit\)/, file: "assets/manifest.yml")
  end

  def test_size_uses_multiples_of_eight
    change_pictures { |list| list[3]["size"] = [100, 100] }
    assert_problem(/star: the size 100x100 should use multiples of 8/, file: "assets/manifest.yml")
  end

  def test_answer_tiles_are_112
    change_pictures { |list| list[0]["size"] = [96, 96] }
    write("assets/circle.svg", read("assets/circle.svg").gsub('viewBox="0 0 112 112"', 'viewBox="0 0 96 96"'))
    assert_problem(/option 1: the picture is circle, which is 96x96. Answer tiles are 112x112/, file: ITEMS)
  end

  def test_src_must_be_an_svg_in_the_pack
    change_pictures do |list|
      list[0]["src"] = "../../secret.svg"
      list[1]["src"] = "assets/missing.svg"
    end
    assert_problem(/circle: src should be an SVG file in this pack's assets folder/, file: "assets/manifest.yml")
    assert_problem(/square: the file assets\/missing.svg isn't there/, file: "assets/manifest.yml")
  end

  def test_listed_picture_without_an_entry
    change_pictures { |list| list.delete_at(0) }
    assert_problem(/lists the picture circle in assets, but assets\/manifest.yml doesn't describe it/, file: "pack.yaml")
    assert_problem(/isn't used by any entry in assets\/manifest.yml/, file: "assets/circle.svg")
  end

  def test_entry_not_in_the_assets_list
    change_manifest do |m|
      m["assets"].delete("star")
      m["icon"] = "circle"
      m["activities"][0]["icon"] = "circle"
    end
    assert_problem(/star is described here but isn't in the assets list/, file: "assets/manifest.yml")
  end

  def test_unused_picture
    change_manifest do |m|
      m["icon"] = "circle"
      m["activities"][0]["icon"] = "circle"
    end
    assert_problem(/lists the picture star in assets, but nothing in the pack uses it/, file: "pack.yaml")
  end

  def test_item_uses_a_picture_that_is_not_listed
    change_items { |list| item(list, "find-circle")["options"][1]["img"] = "hexagon" }
    assert_problem(/the picture is hexagon, which isn't in the assets list/, file: ITEMS)
  end

  def test_every_picture_needs_a_credit
    change_manifest { |m| m["credits"][0]["assets"] = ["circle", "square", "triangle"] }
    assert_problem(/the picture star isn't covered by any credits entry/, file: "pack.yaml")
  end
end

class SvgTest < PackTest
  CIRCLE = '<circle cx="56" cy="56" r="44" fill="#fff" stroke="#000" stroke-width="6"/>'

  def picture(body = CIRCLE, **opts)
    write("assets/circle.svg", svg(body, **opts))
  end

  def assert_svg_problem(pattern)
    assert_problem(pattern, file: "assets/circle.svg")
  end

  def test_plain_drawing_passes
    picture
    assert_clean
  end

  def test_patterns_pass
    picture('<defs><pattern id="hatch" width="8" height="8" patternUnits="userSpaceOnUse">' \
            '<path d="M0 8 L8 0" stroke="black" stroke-width="2"/></pattern></defs>' \
            '<rect x="16" y="16" width="80" height="80" fill="url(#hatch)" stroke="#000000"/>')
    assert_clean
  end

  def test_colours_are_refused
    picture('<circle cx="56" cy="56" r="44" fill="#ff0000"/>')
    assert_svg_problem(/uses the colour #ff0000. Pictures use only black/)
  end

  def test_grey_is_refused
    picture('<circle cx="56" cy="56" r="44" fill="#808080"/>')
    assert_svg_problem(/uses the colour #808080/)
  end

  def test_see_through_is_refused
    picture('<circle cx="56" cy="56" r="44" fill="#000" opacity="0.5"/>')
    assert_svg_problem(/makes shapes see-through \(opacity\)/)
  end

  def test_gradients_are_refused
    picture('<defs><linearGradient id="g"/></defs><circle cx="56" cy="56" r="44" fill="url(#g)"/>')
    assert_svg_problem(/has a gradient/)
  end

  def test_missing_pattern_is_reported
    picture('<circle cx="56" cy="56" r="44" fill="url(#dots)"/>')
    assert_svg_problem(/fills with url\(#dots\), but there's no <pattern id="dots">/)
  end

  def test_outside_paint_is_refused
    picture('<circle cx="56" cy="56" r="44" fill="url(https://example.org/p.svg#dots)"/>')
    assert_svg_problem(/points outside the file/)
  end

  def test_text_elements_are_refused
    picture('<text x="10" y="50">Hello</text>')
    assert_svg_problem(/has words in it/)
  end

  def test_loose_words_are_refused
    picture("<g>Hello there</g>")
    assert_svg_problem(/has words in it/)
  end

  def test_titles_are_refused
    picture("<title>A circle</title>#{CIRCLE}")
    assert_svg_problem(/has a title or description inside it/)
  end

  def test_scripts_are_refused
    picture("<script>alert(1)</script>#{CIRCLE}")
    assert_svg_problem(/has a script/)
  end

  def test_event_handlers_are_refused
    picture('<circle cx="56" cy="56" r="44" fill="#000" onclick="alert(1)"/>')
    assert_svg_problem(/has an event handler \(onclick\)/)
  end

  def test_linked_images_are_refused
    picture('<image href="https://example.org/cat.png" width="112" height="112"/>')
    assert_svg_problem(/has an embedded or linked image/)
  end

  def test_embedded_rasters_are_refused
    picture('<image href="data:image/png;base64,iVBORw0KGgo=" width="112" height="112"/>')
    assert_svg_problem(/has an embedded or linked image/)
  end

  def test_links_are_refused
    picture('<a href="https://example.org">' + CIRCLE + "</a>")
    assert_svg_problem(/has a link/)
  end

  def test_href_on_a_shape_is_refused
    picture('<rect x="0" y="0" width="8" height="8" fill="#000" href="https://example.org"/>')
    assert_svg_problem(/links to another file or address \(href\)/)
  end

  def test_style_is_refused
    picture('<style>circle { fill: red; }</style>' + CIRCLE)
    assert_svg_problem(/has a style sheet/)
    picture('<circle cx="56" cy="56" r="44" style="fill:#000"/>')
    assert_svg_problem(/uses a style attribute/)
  end

  def test_doctype_and_entities_are_refused
    write("assets/circle.svg", %(<?xml version="1.0"?>\n<!DOCTYPE svg [<!ENTITY a "aaaa">]>\n) + svg(CIRCLE).lines[1..].join)
    assert_svg_problem(/has a DOCTYPE, entity or CDATA section/)
  end

  def test_character_codes_are_refused
    picture('<circle cx="56" cy="56" r="44" fill="&#35;000"/>')
    assert_svg_problem(/uses an & character code/)
  end

  def test_editor_extras_are_refused
    picture('<circle cx="56" cy="56" r="44" fill="#000" inkscape:label="Layer 1"/>')
    assert_svg_problem(/has inkscape:label, which drawing apps add/)
  end

  def test_unknown_elements_are_refused
    picture("<switch>#{CIRCLE}</switch>")
    assert_svg_problem(/uses <switch>, which isn't one of the drawing elements/)
  end

  def test_odd_values_are_refused
    picture('<circle cx="56" cy="calc(10px)" r="44" fill="#000"/>')
    assert_svg_problem(/has cy="calc\(10px\)" on <circle>/)
  end

  def test_needs_xmlns_and_view_box
    write("assets/circle.svg", "<svg>#{CIRCLE}</svg>\n")
    assert_svg_problem(/needs xmlns="http:\/\/www.w3.org\/2000\/svg"/)
    assert_svg_problem(/needs a viewBox/)
  end

  def test_must_be_an_svg
    write("assets/circle.svg", "<html><body/></html>\n")
    assert_svg_problem(/isn't an SVG drawing/)
  end

  def test_broken_markup_is_reported
    write("assets/circle.svg", svg("<g>#{CIRCLE}"))
    assert_svg_problem(/closes <\/svg> without opening it|is never closed/)
  end

  def test_view_box_must_match_the_size
    picture(CIRCLE, view_box: "0 0 224 112")
    assert_svg_problem(/has a viewBox of 224x112, but assets\/manifest.yml says 112x112/)
  end

  def test_picture_size_is_capped
    picture(CIRCLE + ("<!-- #{'x' * 70} -->\n" * 1000))
    assert_svg_problem(/A picture is at most 64 KiB/)
  end
end
