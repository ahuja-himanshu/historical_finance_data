# frozen_string_literal: true

# Catalog of supported investable assets for historical performance analysis.
class Asset
  Record = Data.define(:key, :name, :symbol, :category, :currency_label)

  ALL = [
    Record.new(key: "btc", name: "Bitcoin", symbol: "BTC", category: "crypto", currency_label: "USD"),
    Record.new(key: "eth", name: "Ethereum", symbol: "ETH", category: "crypto", currency_label: "USD"),
    Record.new(key: "dji", name: "Dow Jones", symbol: "DJI", category: "equity_index", currency_label: "pts"),
    Record.new(key: "spx", name: "S&P 500", symbol: "SPX", category: "equity_index", currency_label: "pts"),
    Record.new(key: "nifty", name: "Nifty 50", symbol: "NIFTY", category: "equity_index", currency_label: "pts"),
    Record.new(key: "banknifty", name: "Bank Nifty", symbol: "BANKNIFTY", category: "equity_index", currency_label: "pts"),
    Record.new(key: "gold", name: "Gold", symbol: "XAU", category: "commodity", currency_label: "USD/oz"),
    Record.new(key: "silver", name: "Silver", symbol: "XAG", category: "commodity", currency_label: "USD/oz")
  ].freeze

  KEYS = ALL.map(&:key).freeze

  class << self
    def all
      ALL
    end

    def find(key)
      ALL.find { |a| a.key == key.to_s }
    end

    def find!(key)
      find(key) || raise(ArgumentError, "Unsupported asset: #{key.inspect}")
    end

    def keys
      KEYS
    end

    def supported?(key)
      KEYS.include?(key.to_s)
    end
  end
end
