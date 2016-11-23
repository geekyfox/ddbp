
require_relative 'test_common'

class TestInit < BaseTest
  def test_assign_string
    dao = TDP::DAO.new('sqlite://')
    assert dao.db.is_a?(Sequel::SQLite::Database)
  end

  def test_assign_garbage
    assert_raise ArgumentError do
      TDP::Engine.new 42
    end

    assert_raise Sequel::AdapterNotFound do
      TDP::Engine.new 'bullshit://'
    end
  end
end
