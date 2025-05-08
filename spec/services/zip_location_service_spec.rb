# frozen_string_literal: true

# spec/services/zip_location_service_spec.rb
require 'rails_helper'

RSpec.describe ZipLocationService, type: :service do
  describe '.normalize' do
    subject(:result) { described_class.normalize(input) }

    let(:zip_str)   { input.to_s.strip }
    let(:cache_key) { "zip:#{zip_str}" }

    before do
      allow(Rails.cache).to receive(:exist?).and_return(false)
    end

    shared_examples 'nil result' do
      it 'returns nil data' do
        expect(result.data).to be_nil
      end
    end

    context 'when zip contains letters (raw)' do
      let(:input) { ' abc123 ' }

      it 'returns the stripped raw input' do
        expect(result.data).to eq('abc123')
      end

      it 'does not call the API or cache' do
        expect(Rails.cache).not_to have_received(:exist?)
        expect(described_class).not_to receive(:request_api)
        described_class.normalize(input)
      end
    end

    context 'when a cached value exists' do
      let(:input)        { '12345' }
      let(:cached_value) { 'Cached City, P, CC' }

      before do
        allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(true)
        allow(Rails.cache).to receive(:read).with(cache_key).and_return(cached_value)
      end

      it 'returns the cached location' do
        expect(result.data).to eq(cached_value)
      end

      it 'does not hit the API' do
        expect(described_class).not_to receive(:request_api)
        described_class.normalize(input)
      end
    end

    context 'when HTTP response is unsuccessful' do
      let(:input)    { '12345' }
      # use a plain double so we can stub :message without instance_double errors
      let(:response) { double(success?: false, code: 500, message: 'Error') }

      before do
        allow(described_class).to receive(:request_api).with(zip_str).and_return(response)
      end

      it_behaves_like 'nil result'
    end

    context 'when no entry is found' do
      let(:input)    { '12345' }
      let(:parsed)   { { 'results' => { zip_str => [] } } }
      let(:response) { double(success?: true, parsed_response: parsed) }

      before do
        allow(described_class).to receive(:request_api).with(zip_str).and_return(response)
      end

      it_behaves_like 'nil result'
    end

    context 'when entry data is incomplete' do
      let(:input)    { '12345' }
      let(:entry)    { { 'city' => 'CityX' } }
      let(:parsed)   { { 'results' => { zip_str => [entry] } } }
      let(:response) { double(success?: true, parsed_response: parsed) }

      before do
        allow(described_class).to receive(:request_api).with(zip_str).and_return(response)
      end

      it_behaves_like 'nil result'
    end

    context 'when entry is complete with province & country' do
      let(:input)    { '12345' }
      let(:entry)    { { 'city' => 'CityX', 'province' => 'ProvY', 'country' => 'CZ' } }
      let(:parsed)   { { 'results' => { zip_str => [entry] } } }
      let(:response) { double(success?: true, parsed_response: parsed) }

      before do
        allow(described_class).to receive(:request_api).with(zip_str).and_return(response)
      end

      it 'returns formatted location' do
        expect(result.data).to eq('CityX, ProvY, CZ')
      end
    end

    context 'when entry has state & country_code instead of province & country' do
      let(:input)    { '12345' }
      let(:entry)    { { 'city' => 'CityX', 'state' => 'StateY', 'country_code' => 'CC' } }
      let(:parsed)   { { 'results' => { zip_str => [entry] } } }
      let(:response) { double(success?: true, parsed_response: parsed) }

      before do
        allow(described_class).to receive(:request_api).with(zip_str).and_return(response)
      end

      it 'falls back to state and country_code' do
        expect(result.data).to eq('CityX, StateY, CC')
      end
    end
  end

  describe '::request_api (private)' do
    subject(:api_call) { described_class.send(:request_api, zip_str) }

    let(:zip_str)     { '12345' }
    let(:default_key) { 'df1acd40-2b3c-11f0-a603-37638c07d609' }

    context 'when ZIPCODEBASE_API_KEY is not set in ENV' do
      before do
        allow(ENV).to receive(:fetch)
          .with('ZIPCODEBASE_API_KEY', default_key)
          .and_return(default_key)
        allow(described_class).to receive(:get)
          .with('/search', query: { codes: zip_str, apikey: default_key })
          .and_return(:ok_default)
      end

      it 'uses the default API key and calls get' do
        expect(api_call).to eq(:ok_default)
      end
    end

    context 'when ZIPCODEBASE_API_KEY is set in ENV' do
      let(:custom_key) { 'custom-KEY-123' }

      before do
        allow(ENV).to receive(:fetch)
          .with('ZIPCODEBASE_API_KEY', default_key)
          .and_return(custom_key)
        allow(described_class).to receive(:get)
          .with('/search', query: { codes: zip_str, apikey: custom_key })
          .and_return(:ok_custom)
      end

      it 'uses the ENV API key and calls get' do
        expect(api_call).to eq(:ok_custom)
      end
    end
  end
end
