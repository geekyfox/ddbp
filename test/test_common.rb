
class BaseTest < Test::Unit::TestCase
  def setup
    @db = Sequel.sqlite
  end

  def teardown
    @db = nil
  end

  def assert_not(test)
    assert(!test)
  end

  def upgrade_generic
    assert_not(@db.table_exists?(:thing))
    assert_not(@db.table_exists?(:weird_thing))

    TDP.execute(@db) do |engine|
      engine << 'test/schema/pack-1'
      assert_equal(2, engine.plan.length)
      engine.upgrade
    end

    assert(@db.table_exists?(:thing))
    assert(@db.table_exists?(:weird_thing))
  end
end
