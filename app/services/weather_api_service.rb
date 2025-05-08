# app/services/weather_api.rb
# frozen_string_literal: true

require 'httparty'
require 'json'

class WeatherApiService
  include HTTParty
  base_uri ENV.fetch('WEATHERAPI_BASE_URI', 'http://api.weatherapi.com/v1')
  API_KEY = ENV.fetch('WEATHERAPI_KEY', 'f892e8c5e2034cb4997111023250705')
  FORECAST_PATH = '/forecast.json'
  FORECAST_HOURS = 12.hours.freeze
  INTERVAL_HOURS = 2.hours.freeze

  class << self
    def fetch(location)
      response = request_forecast(location)
      data     = parse_response(response)
      build_result(data)
    rescue StandardError => e
      Rails.logger.error("WeatherAPI.fetch error for '#{location}': #{e.message}")
      nil
    end

    private

    def request_forecast(location)
      get(
        FORECAST_PATH,
        query: { key: API_KEY, q: format_query(location), aqi: 'no' }
      )
    end

    def parse_response(response)
      raise "HTTP error #{response.code}: #{response.message}" unless response.success?

      parsed = JSON.parse(response.body)
      raise parsed['error']['message'] if parsed['error']

      parsed
    end

    def build_result(parsed)
      loc      = parsed['location']
      today    = parsed.dig('forecast', 'forecastday', 0)
      localtime = Time.zone.parse(loc['localtime'])

      {
        city: loc['name'],
        country: loc['country'],
        temperature: parsed.dig('current', 'temp_c'),
        condition: parsed.dig('current', 'condition', 'text'),
        icon: parsed.dig('current', 'condition', 'icon'),
        high: today.dig('day', 'maxtemp_c'),
        low: today.dig('day', 'mintemp_c'),
        forecast_day: build_forecast_day(today),
        hourly_forecast: build_hourly_forecast(today['hour'], localtime)
      }
    end

    def build_forecast_day(day_data)
      {
        date: day_data['date'],
        condition: day_data.dig('day', 'condition', 'text'),
        icon: day_data.dig('day', 'condition', 'icon'),
        high: day_data.dig('day', 'maxtemp_c'),
        low: day_data.dig('day', 'mintemp_c')
      }
    end

    def build_hourly_forecast(hours, localtime)
      upcoming = hours.select do |h|
        ft = Time.zone.parse(h['time'])
        ft >= localtime && ft <= (localtime + FORECAST_HOURS)
      end

      result = []
      next_time = localtime
      upcoming.each do |hour|
        ft = Time.zone.parse(hour['time'])
        next unless ft >= next_time

        result << {
          time: ft.strftime('%H:%M'),
          condition: hour.dig('condition', 'text'),
          icon: hour.dig('condition', 'icon'),
          temp_c: hour['temp_c']
        }
        next_time += INTERVAL_HOURS
      end
      result
    end

    def format_query(location)
      location.match?(/^\d{4,6}$/) ? location.strip : location
    end
  end
end
