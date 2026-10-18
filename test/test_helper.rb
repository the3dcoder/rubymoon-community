# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "stringio"
require "tmpdir"
require "yaml"
require_relative "../scripts/check_packs"

# Each test gets a fresh copy of the example pack in a temporary packs/ folder, changes one thing, and checks
# what the checker says about it.
class PackTest < Minitest::Test
  EXAMPLE = File.expand_path("../packs/cm.example.shapes", __dir__)
  ITEMS = "items/10-shapes.yaml"

  def setup
    @tmp = Dir.mktmpdir("rubymoon-community")
    @pack = File.join(@tmp, "packs", "cm.example.shapes")
    FileUtils.mkdir_p(File.dirname(@pack))
    FileUtils.cp_r(EXAMPLE, @pack)
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def path(rel) = File.join(@pack, rel)
  def read(rel) = File.read(path(rel))
  def write(rel, text) = File.write(path(rel), text)

  def change_yaml(rel)
    data = YAML.safe_load_file(path(rel))
    yield data
    write(rel, YAML.dump(data))
  end

  def change_manifest(&) = change_yaml("pack.yaml", &)
  def change_items(&) = change_yaml(ITEMS, &)
  def change_pictures(&) = change_yaml("assets/manifest.yml", &)
  def item(list, id) = list.find { |i| i["id"] == id }

  # Moves the pack to a new folder name (and sets the id to match unless told otherwise).
  def rename_pack(name, id: name)
    dest = File.join(File.dirname(@pack), name)
    FileUtils.mv(@pack, dest)
    @pack = dest
    change_manifest { |m| m["id"] = id }
  end

  def svg(body, view_box: "0 0 112 112", attrs: "")
    %(<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" viewBox="#{view_box}"#{attrs}>) +
      body + "</svg>\n"
  end

  def checker(dir = @pack) = PackCheck::Checker.new(dir).run
  def messages(dir = @pack) = checker(dir).problems.map { |p| "#{p.file}: #{p.message}" }

  def assert_clean(dir = @pack)
    found = messages(dir)
    assert_empty found, "expected no problems, got:\n#{found.join("\n")}"
  end

  def assert_problem(pattern, file: nil)
    found = messages
    hit = found.any? { |m| (file.nil? || m.start_with?("#{file}: ")) && m.match?(pattern) }
    assert hit, "expected #{pattern.inspect}#{file ? " in #{file}" : ''}, got:\n#{found.join("\n")}"
  end
end
