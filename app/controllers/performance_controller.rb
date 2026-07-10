# frozen_string_literal: true

class PerformanceController < ApplicationController
  MONTHS = (1..12).map { |m| [Date::MONTHNAMES[m], m] }.freeze

  def index
    @assets = Asset.all
    @months = MONTHS
    @asset_key = permitted_asset
    @mode = permitted_mode
    @month = permitted_month
    @lookback_years = permitted_lookback

    @result =
      if @mode == "year"
        YearPerformanceQuery.new(as_of: as_of_date).call(
          asset_key: @asset_key,
          lookback_years: @lookback_years
        )
      else
        MonthPerformanceQuery.new(as_of: as_of_date).call(
          asset_key: @asset_key,
          month: @month,
          lookback_years: @lookback_years
        )
      end
  end

  private

  def permitted_asset
    key = params[:asset].presence || "btc"
    Asset.supported?(key) ? key : "btc"
  end

  def permitted_mode
    mode = params[:mode].to_s
    %w[month year].include?(mode) ? mode : "month"
  end

  def permitted_month
    m = params[:month].to_i
    (1..12).cover?(m) ? m : Date.current.month
  end

  def permitted_lookback
    n = params[:lookback].to_i
    return 10 if n <= 0

    n.clamp(3, 20)
  end

  # Allow tests / demos to pin "today" via param without affecting production UX.
  def as_of_date
    if params[:as_of].present?
      Date.parse(params[:as_of].to_s)
    else
      Date.current
    end
  rescue ArgumentError, TypeError
    Date.current
  end
end
