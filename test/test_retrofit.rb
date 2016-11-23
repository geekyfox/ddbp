
require_relative 'test_common'

class TestRetrofit < BaseTest
  def test_retrofit
    TDP.execute(@db, &:bootstrap)
    assert_equal(0, @db[:tdp_patch].count)
    TDP.execute(@db, ['test/schema/pack-1'], &:retrofit)
    assert_equal(2, @db[:tdp_patch].count)
  end

  def test_second_retrofit
    test_retrofit
    TDP.execute(@db, ['test/schema/pack-2'], &:retrofit)
    assert_equal(1, @db[:tdp_patch].count)
  end
end
