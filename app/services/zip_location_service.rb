# app/services/zip_location_service.rb
# frozen_string_literal: true

require 'httparty'

class ZipLocationService
  include HTTParty
  base_uri 'https://app.zipcodebase.com/api/v1'

  Result = Struct.new(:data)
  CACHE_EXPIRY = 1.day

  class << self
    def normalize(zip)
      zip_str = sanitize_input(zip)
      return wrap_raw(zip_str) if raw?(zip_str)

      key = cache_key(zip_str)
      return from_cache(key) if cached?(key)

      lookup_and_cache(zip_str, key)
    end

    private

    def sanitize_input(zip)
      zip.to_s.strip
    end

    def raw?(zip_str)
      zip_str.match?(/[A-Za-z]/)
    end

    def wrap_raw(zip_str)
      Result.new(zip_str)
    end

    def cache_key(zip_str)
      "zip:#{zip_str}"
    end

    def cached?(key)
      Rails.cache.exist?(key)
    end

    def from_cache(key)
      Result.new(Rails.cache.read(key))
    end

    def lookup_and_cache(zip_str, key)
      response = request_api(zip_str)
      entry    = extract_entry(response, zip_str)
      location = format_location(entry)

      Rails.cache.write(key, location, expires_in: CACHE_EXPIRY)
      Result.new(location)
    rescue StandardError => e
      Rails.logger.error("ZIP lookup failed for '#{zip_str}': #{e.message}")
      Result.new(nil)
    end

    def request_api(zip_str)
      api_key = ENV.fetch('ZIPCODEBASE_API_KEY', 'df1acd40-2b3c-11f0-a603-37638c07d609')
      get('/search', query: { codes: zip_str, apikey: api_key })
    end

    def extract_entry(response, zip_str)
      raise "HTTP error (#{response.code}): #{response.message}" unless response.success?

      entry = response.parsed_response.dig('results', zip_str)&.first
      raise "No results for '#{zip_str}'" unless entry

      entry
    end

    def format_location(entry)
      city     = entry['city']
      province = entry['province'] || entry['state']
      country  = entry['country']  || entry['country_code']
      raise "Incomplete data: #{entry.inspect}" unless city && province && country

      "#{city}, #{province}, #{country}"
    end
  end
end
