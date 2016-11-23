
require 'sequel'
require 'test/unit'
require_relative '../lib/tdp'
require_relative 'test_common'

class TestBasic < BaseTest
  def test_init
    TDP.execute(@db) do |engine|
      assert_equal(0, engine.plan.length)
    end
  end

  def test_create_patch
    filename = 'test/schema/pack-1/001-initial-schema.sql'
    p = TDP::Patch.new(filename)
    assert_equal(filename, p.full_filename)
    assert_equal('001-initial-schema.sql', p.name)
    assert(p.permanent?)
    assert_nothing_raised do
      p.signature
      p.content
    end
  end

  def test_permanent_filename
    assert TDP.permanent_patch_file?('001-patch.sql')
    assert_not TDP.permanent_patch_file?('views.sql')
  end

  def test_volatile_filename
    assert TDP.volatile_patch_file?('views.sql')
    assert_not TDP.volatile_patch_file?('001-patch.sql')
  end

  def test_add_volatile_patch
    plan = TDP.execute(@db) do |engine|
      engine << 'test/schema/pack-1/views.sql'
      engine.plan
    end
    assert_equal(1, plan.length)
    assert_equal('views.sql', plan[0].name)
    assert(plan[0].volatile?)
  end

  def test_add_permanent_patch
    plan = TDP.execute(@db) do |engine|
      engine << 'test/schema/pack-1/001-initial-schema.sql'
      engine.plan
    end
    assert_equal(1, plan.length)
    assert_equal('001-initial-schema.sql', plan[0].name)
    assert(plan[0].permanent?)
  end

  def test_repeated_add
    plan = TDP.execute(@db) do |engine|
      engine << 'test/schema/pack-1/views.sql'
      engine << 'test/schema/pack-3/views.sql'
      engine.plan
    end
    assert_equal(1, plan.length)
    assert_equal('views.sql', plan[0].name)
    assert(plan[0].volatile?)
  end

  def test_non_existant_file
    TDP.execute(@db) do |engine|
      assert_raise(Errno::ENOENT) do
        engine << 'not-exist.sql'
      end
    end
  end

  def test_add_patches
    TDP.execute(@db) do |engine|
      engine << 'test/schema/pack-1'
      assert_equal(2, engine.plan.length)

      engine << 'test/schema/pack-2'
      assert_equal(3, engine.plan.length)

      engine << 'test/schema/pack-3'
      assert_equal(3, engine.plan.length)
    end
  end

  def test_add_mismatching_patches
    TDP.execute(@db) do |engine|
      engine << 'test/schema/pack-1'

      assert_raise(TDP::ContradictionError) do
        engine << 'test/schema/pack-4'
      end
      assert_equal(2, engine.plan.length)
    end
  end
end
