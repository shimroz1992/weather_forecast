# frozen_string_literal: true

require 'httparty'

class IpLocationService
  include HTTParty
  base_uri ENV.fetch('IPAPI_BASE_URI', 'https://ipapi.co')
  CACHE_EXPIRY = 1.day

  class << self
    def fetch(ip)
      ip_str = sanitize_ip(ip)
      return nil if ip_str.blank?

      key = cache_key(ip_str)
      return from_cache(key) if cached?(key)

      lookup_and_cache(ip_str, key)
    end

    private

    def sanitize_ip(ip)
      ip.to_s.strip
    end

    def cache_key(ip_str)
      "ip:#{ip_str}"
    end

    def cached?(key)
      Rails.cache.exist?(key)
    end

    def from_cache(key)
      Rails.cache.read(key)
    end

    def lookup_and_cache(ip_str, key)
      response = request_api(ip_str)
      data = parse_response(response)
      location = extract_location(data)

      Rails.cache.write(key, location, expires_in: CACHE_EXPIRY)
      location
    rescue StandardError => e
      Rails.logger.error("IpLocationService.fetch error for '#{ip_str}': #{e.message}")
      nil
    end

    def request_api(ip_str)
      self.class.get("/#{ip_str}/json/")
    end

    def parse_response(response)
      raise "HTTP error #{response.code}: #{response.message}" unless response.success?

      JSON.parse(response.body)
    end

    def extract_location(data)
      return nil if data['error']

      data['postal'] || data['city']
    end
  end
end
