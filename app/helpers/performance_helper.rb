# frozen_string_literal: true

module PerformanceHelper
  def signed_pct(value, precision: 2)
    PerformanceCalculator.format_signed_pct(value, precision: precision)
  end

  def pct_class(value)
    return "pct-flat" if value.nil?
    return "pct-positive" if value.positive?
    return "pct-negative" if value.negative?

    "pct-flat"
  end

  def asset_badge_class(category)
    case category
    when "crypto" then "badge-crypto"
    when "equity_index" then "badge-equity"
    when "commodity" then "badge-commodity"
    else "badge-default"
    end
  end

  def mode_label(mode)
    mode == "year" ? "Year-wise" : "Month-wise"
  end

  def chart_json(result)
    {
      labels: result[:chart][:labels],
      values: result[:chart][:values],
      colors: result[:chart][:colors],
      partial: result[:chart][:partial],
      mode: result[:mode],
      title: chart_title(result)
    }.to_json
  end

  def chart_title(result)
    asset = result[:asset]
    if result[:mode] == "year"
      "#{asset.name} — Calendar year returns"
    else
      "#{asset.name} — #{result[:month_name]} returns by year"
    end
  end

  def format_price(value, asset)
    return "—" if value.nil?

    if asset.category == "crypto" || %w[gold silver].include?(asset.key)
      number_to_currency(value, unit: "$", precision: value >= 100 ? 0 : 2)
    else
      number_with_delimiter(value.round(2))
    end
  end
end
