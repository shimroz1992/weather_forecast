# frozen_string_literal: true

# spec/services/weather_fetcher_spec.rb
require 'rails_helper'

RSpec.describe WeatherFetcher do
  # Use a real in-memory cache for these examples (Rails default in test is often :null_store)
  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
    Rails.cache = original_cache
  end

  describe '#call' do
    context 'when input is blank' do
      it 'raises UnknownLocationError' do
        expect { WeatherFetcher.new('').call }
          .to raise_error(WeatherFetcher::UnknownLocationError, /Unknown location: /)
      end
    end

    context 'with a valid IP address' do
      before do
        allow(IpLocationService).to receive(:fetch).with('1.2.3.4').and_return('Berlin')
        allow(WeatherApiService).to receive(:fetch).with('Berlin').and_return({ temp: 20 })
      end

      it 'normalizes via IP, fetches, caches and toggles from_cache correctly' do
        f1 = WeatherFetcher.new(' 1.2.3.4 ')
        r1 = f1.call

        expect(r1.data).to eq(temp: 20)
        expect(r1.from_cache).to be false

        f2 = WeatherFetcher.new('1.2.3.4')
        r2 = f2.call

        expect(r2.data).to eq(temp: 20)
        expect(r2.from_cache).to be true
      end
    end

    context 'with a valid ZIP code' do
      let(:zip_result) { double(data: '10001') }

      before do
        allow(ZipLocationService).to receive(:normalize).with('12345').and_return(zip_result)
        allow(WeatherApiService).to receive(:fetch).with('10001').and_return({ temp: 25 })
      end

      it 'normalizes via ZIP, fetches, caches and toggles from_cache correctly' do
        f1 = WeatherFetcher.new('12345')
        r1 = f1.call

        expect(r1.data).to eq(temp: 25)
        expect(r1.from_cache).to be false

        f2 = WeatherFetcher.new('12345')
        r2 = f2.call

        expect(r2.data).to eq(temp: 25)
        expect(r2.from_cache).to be true
      end
    end

    context 'with a plain location string' do
      before do
        allow(WeatherApiService).to receive(:fetch).with('London').and_return({ temp: 15 })
      end

      it 'uses raw string, fetches, caches and toggles from_cache correctly' do
        f1 = WeatherFetcher.new(' London ')
        r1 = f1.call

        expect(r1.data).to eq(temp: 15)
        expect(r1.from_cache).to be false

        f2 = WeatherFetcher.new('London')
        r2 = f2.call

        expect(r2.data).to eq(temp: 15)
        expect(r2.from_cache).to be true
      end
    end

    context 'when cache entry is expired' do
      before do
        # simulate a stale entry older than CACHE_EXPIRY
        key = 'weather:stalecity'
        Rails.cache.write(
          key,
          { data: { temp: 0 },
            fetched_at: Time.current - (WeatherFetcher::CACHE_EXPIRY + 1.minute) },
          expires_in: WeatherFetcher::CACHE_EXPIRY
        )

        allow(WeatherApiService).to receive(:fetch).with('stalecity').and_return({ temp: 30 })
      end

      it 're-fetches and overwrites the stale cache' do
        wf1 = WeatherFetcher.new('stalecity')
        r1  = wf1.call

        expect(r1.data).to eq(temp: 30)
        expect(r1.from_cache).to be false

        wf2 = WeatherFetcher.new('stalecity')
        r2  = wf2.call

        expect(r2.data).to eq(temp: 30)
        expect(r2.from_cache).to be true
      end
    end
  end

  describe 'private helpers' do
    subject { WeatherFetcher.new('foo') }

    it 'identifies IPs correctly' do
      expect(subject.send(:looks_like_ip?, '192.168.0.1')).to be true
      expect(subject.send(:looks_like_ip?, 'not an ip')).to be false
    end

    it 'identifies ZIP codes correctly' do
      expect(subject.send(:looks_like_zip?, '12345')).to be true
      expect(subject.send(:looks_like_zip?, '12345-6789')).to be true
      expect(subject.send(:looks_like_zip?, '560001')).to be true
      expect(subject.send(:looks_like_zip?, 'abc')).to be false
    end

    it 'generates a normalized cache key' do
      key = subject.send(:cache_key, ' New   York City ')
      expect(key).to eq('weather:new_york_city')
    end

    it 'writes to cache with the correct options' do
      data = { foo: 'bar' }
      expect(Rails.cache).to receive(:write).with(
        'weather:test',
        hash_including(data: data, fetched_at: kind_of(Time)),
        expires_in: WeatherFetcher::CACHE_EXPIRY
      )
      subject.send(:write_cache, 'weather:test', data)
    end

    it 'normalizes location via correct service' do
      allow(IpLocationService).to receive(:fetch).with('1.2.3.4').and_return('X')
      expect(subject.send(:normalize_location, '1.2.3.4')).to eq('X')

      allow(ZipLocationService).to receive(:normalize).with('12345').and_return(double(data: 'Y'))
      expect(subject.send(:normalize_location, '12345')).to eq('Y')

      expect(subject.send(:normalize_location, 'SomeCity')).to eq('SomeCity')
    end
  end
end
