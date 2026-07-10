# frozen_string_literal: true

require "test_helper"

class AssetTest < ActiveSupport::TestCase
  test "exactly eight supported assets with expected keys" do
    expected = %w[btc eth dji spx nifty banknifty gold silver]
    assert_equal expected, Asset.keys
    assert_equal 8, Asset.all.size
  end

  test "find and find!" do
    assert_equal "Bitcoin", Asset.find("btc").name
    assert_nil Asset.find("nope")
    assert_raises(ArgumentError) { Asset.find!("nope") }
  end
end
