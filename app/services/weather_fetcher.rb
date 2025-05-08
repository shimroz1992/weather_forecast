# frozen_string_literal: true

class WeatherFetcher
  # Raised when the raw input cannot be normalized
  class UnknownLocationError < StandardError; end

  # Returns both data and whether it came from cache
  Result = Struct.new(:data, :from_cache)

  CACHE_EXPIRY = 30.minutes

  def initialize(location_input)
    @raw        = location_input.to_s.strip
    @from_cache = false
  end

  def call
    location = normalize_location(@raw)
    raise UnknownLocationError, "Unknown location: #{@raw}" if location.blank?

    key   = cache_key(location)
    entry = Rails.cache.read(key)
    if entry && entry[:fetched_at] > Time.current - CACHE_EXPIRY
      @from_cache = true
      data = entry[:data]
    else
      data = WeatherApiService.fetch(location)
      write_cache(key, data)
    end

    Result.new(data, @from_cache)
  end

  private

  def normalize_location(raw)
    if looks_like_ip?(raw)
      IpLocationService.fetch(raw)
    elsif looks_like_zip?(raw)
      ZipLocationService.normalize(raw).data
    else
      raw
    end
  end

  def looks_like_ip?(str)
    !!(str =~ /\A\d{1,3}(?:\.\d{1,3}){3}\z/)
  end

  def looks_like_zip?(str)
    !!(str =~ /\A(?:\d{5}(?:-\d{4})?|\d{6})\z/)
  end

  def cache_key(loc)
    "weather:#{loc.downcase.strip.gsub(/\s+/, '_')}"
  end

  def write_cache(key, data)
    Rails.cache.write(
      key,
      { data: data, fetched_at: Time.current },
      expires_in: CACHE_EXPIRY
    )
  end
end
