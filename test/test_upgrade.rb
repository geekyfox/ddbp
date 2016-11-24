
require_relative 'test_common'

class TestUpgrade < BaseTest
  def test_upgrade
    assert_not(@db.table_exists?(:thing))
    paths = ['test/schema/pack-1/001-initial-schema.sql']
    TDP.execute(@db, paths, &:upgrade)
    assert(@db.table_exists?(:thing))
  end

  def test_upgrade_volatile
    upgrade_generic
    TDP.execute(@db) do |engine|
      engine << 'test/schema/pack-1/001-initial-schema.sql'
      engine << 'test/schema/pack-5/views.sql'
      assert_equal(1, engine.plan.length)
      engine.upgrade
    end
  end

  def test_upgrade_permanent
    upgrade_generic
    TDP.execute(@db) do |engine|
      engine << 'test/schema/pack-1'
      engine << 'test/schema/pack-2/002-minor-changes.sql'
      assert_equal(1, engine.plan.length)
      engine.upgrade
    end
  end

  def test_broken_sql
    TDP.execute(@db) do |engine|
      engine << 'test/schema/pack-5'
      assert_raise(Sequel::Error) do
        engine.upgrade
      end
    end
  end

  def test_incompatible_upgrade
    TDP.execute(@db, ['test/schema/pack-1'], &:upgrade)

    TDP.execute(@db) do |engine|
      engine << 'test/schema/pack-4'
      assert_raise(TDP::MismatchError) do
        engine.plan
      end
    end
  end
end
