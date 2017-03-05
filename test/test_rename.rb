require_relative 'test_common'

class TestRename < BaseTest
  def test_rename_no_changes
    paths = ['test/schema/pack-1', 'test/schema/pack-2']
    TDP.execute(@db, paths) do |engine|
      engine.upgrade
      assert_equal({}, engine.plan_rename)
      engine.rename
    end
  end

  def test_rename_with_changes
    paths = ['test/schema/pack-1', 'test/schema/pack-2']
    TDP.execute(@db, paths, &:upgrade)
    paths = ['test/schema/pack-1', 'test/schema/pack-6']
    TDP.execute(@db, paths) do |engine|
      plan = engine.plan_rename
      expected = { '002-minor-changes.sql' => '002-some-stuff.sql' }
      assert_equal(expected, plan)
      engine.rename
      plan = engine.plan_rename
      assert_equal({}, plan)
    end
  end

  def test_duplicates_in_database
    paths = ['test/schema/pack-2', 'test/schema/pack-6']
    TDP.execute(@db, paths, &:upgrade)
    assert_raise(TDP::DuplicateError) do
      TDP.execute(@db, paths, &:plan_rename)
    end
    assert_raise(TDP::DuplicateError) do
      TDP.execute(@db, paths, &:rename)
    end
  end

  def test_duplicates_in_config
    paths = ['test/schema/pack-2']
    TDP.execute(@db, paths, &:upgrade)
    paths = ['test/schema/pack-2', 'test/schema/pack-6']
    assert_raise(TDP::DuplicateError) do
      TDP.execute(@db, paths, &:plan_rename)
    end
    assert_raise(TDP::DuplicateError) do
      TDP.execute(@db, paths, &:rename)
    end
  end
end
