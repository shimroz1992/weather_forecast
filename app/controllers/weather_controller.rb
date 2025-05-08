# frozen_string_literal: true

class WeatherController < ApplicationController
  def index
    raw_input = params[:location].presence || request.remote_ip
    result = WeatherFetcher.new(raw_input).call
    @weather = result.data
    @from_cache = result.from_cache
  rescue WeatherFetcher::UnknownLocationError
    flash.now[:alert] = "Could not resolve '#{params[:location]}'"
  rescue StandardError => e
    flash.now[:alert] = "Weather error: #{e.message}"
  end
end
