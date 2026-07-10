# frozen_string_literal: true

namespace :static_site do
  desc "Export lib/data/prices YAML into docs/data/prices.json for GitHub Pages"
  task export: :environment do
    require "json"

    catalog = Asset.all.map do |a|
      {
        "key" => a.key,
        "name" => a.name,
        "symbol" => a.symbol,
        "category" => a.category,
        "currency_label" => a.currency_label
      }
    end

    repo = PriceRepository.new
    prices = {}
    Asset.keys.each do |key|
      meta = repo.metadata(key)
      prices[key] = {
        "asset" => key,
        "unit" => meta["unit"],
        "frequency" => meta["frequency"],
        "source" => meta["source"],
        "series" => repo.series_for(key)
      }
    end

    out = Rails.root.join("docs/data/prices.json")
    out.dirname.mkpath
    out.write(JSON.pretty_generate("assets" => catalog, "prices" => prices))
    puts "Exported #{out} (#{out.size} bytes)"
  end
end
