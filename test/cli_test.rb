# frozen_string_literal: true

require_relative "test_helper"

class CliTest < PackTest
  def run_checker(args = [])
    out = StringIO.new
    code = PackCheck.run(args, out: out, root: @tmp, base: @tmp)
    [code, out.string]
  end

  def test_good_pack_exits_zero
    code, out = run_checker([@pack])
    assert_equal 0, code
    assert_includes out, "packs/cm.example.shapes: looks good (4 items, 4 pictures)"
    assert_includes out, "The pack looks good."
  end

  def test_no_arguments_checks_every_pack
    code, out = run_checker
    assert_equal 0, code
    assert_includes out, "packs/cm.example.shapes: looks good"
  end

  def test_problems_are_grouped_by_file_and_exit_one
    write(PackTest::ITEMS, read(PackTest::ITEMS).sub("hint: A circle is round all the way around.", "hint: #{'x' * 90}"))
    change_manifest { |m| m["license"] = "MIT" }
    code, out = run_checker
    assert_equal 1, code
    assert_includes out, "packs/cm.example.shapes: 2 problems"
    assert_includes out, "  pack.yaml\n    - has the license \"MIT\""
    assert_includes out, "  items/10-shapes.yaml\n    - item \"find-circle\": the hint is 90 characters"
    assert_includes out, "Found 2 problems in 1 pack."
  end

  def test_stray_files_in_packs_folder
    File.write(File.join(@tmp, "packs", "notes.txt"), "hello")
    code, out = run_checker
    assert_equal 1, code
    assert_includes out, "packs/notes.txt: only pack folders belong in packs/"
  end

  def test_no_packs_at_all
    FileUtils.rm_rf(File.join(@tmp, "packs"))
    code, out = run_checker
    assert_equal 1, code
    assert_includes out, "No packs found"
  end

  def test_github_annotations
    change_manifest { |m| m["license"] = "MIT" }
    out = StringIO.new
    PackCheck.run([], out: out, root: @tmp, base: @tmp, annotate: true)
    assert_includes out.string, "::error file=packs/cm.example.shapes/pack.yaml::has the license"
    refute_includes run_checker.last, "::error"
  end

  def test_help
    code, out = run_checker(["--help"])
    assert_equal 0, code
    assert_includes out, "usage: ruby scripts/check_packs.rb"
  end

  def test_runs_as_a_script
    script = File.expand_path("../scripts/check_packs.rb", __dir__)
    ok = system(RbConfig.ruby, script, @pack, out: File::NULL)
    assert ok, "the checker should exit 0 on the example"
    change_manifest { |m| m["license"] = "MIT" }
    refute system(RbConfig.ruby, script, @pack, out: File::NULL), "the checker should exit 1 on a broken pack"
  end
end
