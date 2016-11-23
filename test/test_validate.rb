
require_relative 'test_common'

class TestVerify < BaseTest
  def test_empty
    TDP.execute(@db) do |engine|
      engine.validate_upgradable
      engine.validate_compatible
    end

    TDP.execute(@db, &:validate_upgradable)
    TDP.execute(@db, &:validate_compatible)
  end

  def test_validate_upgradable
    upgrade_generic
    TDP.execute(@db) do |engine|
      assert_raise(TDP::NotConfiguredError) do
        engine.validate_upgradable
      end
      engine << 'test/schema/pack-1'
      engine.validate_upgradable
    end
  end

  def test_validate_compatible
    TDP.execute(@db) do |engine|
      engine << 'test/schema/pack-1'
      assert_raise(TDP::NotAppliedError) do
        engine.validate_compatible
      end
      engine.upgrade
      engine.validate_compatible
    end
  end

  def test_validate_volatile_mismatch
    test_validate_compatible
    paths = []
    paths << 'test/schema/pack-1/001-initial-schema.sql'
    paths << 'test/schema/pack-4/views.sql'
    assert_raise(TDP::MismatchError) do
      TDP.execute(@db, paths, &:validate_compatible)
    end
  end

  def test_validate_permanent_mismatch
    test_validate_compatible
    paths = []
    paths << 'test/schema/pack-1/views.sql'
    paths << 'test/schema/pack-4/001-initial-schema.sql'
    assert_raise(TDP::MismatchError) do
      TDP.execute(@db, paths, &:validate_compatible)
    end
  end
end
