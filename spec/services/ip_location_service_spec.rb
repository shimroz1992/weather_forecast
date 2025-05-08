# frozen_string_literal: true

# spec/services/ip_location_service_spec.rb
require 'rails_helper'

RSpec.describe IpLocationService do
  let(:expiry) { described_class::CACHE_EXPIRY }
  let(:ip)     { '1.2.3.4' }
  let(:key)    { "ip:#{ip}" }

  describe '.fetch' do
    context 'when IP is blank' do
      it 'returns nil for nil' do
        expect(described_class.fetch(nil)).to be_nil
      end

      it 'returns nil for empty string' do
        expect(described_class.fetch('')).to be_nil
      end

      it 'returns nil for whitespace-only string' do
        expect(described_class.fetch('   ')).to be_nil
      end
    end

    context 'when cached' do
      before do
        allow(Rails.cache).to receive(:exist?).with(key).and_return(true)
        allow(Rails.cache).to receive(:read).with(key).and_return('cached!')
      end

      it 'reads from cache and does not call the API' do
        expect(described_class).not_to receive(:request_api)
        expect(described_class.fetch(ip)).to eq('cached!')
      end
    end

    context 'when not cached' do
      before do
        allow(Rails.cache).to receive(:exist?).with(key).and_return(false)
      end

      def stub_response(attrs)
        double('response', attrs)
      end

      it 'strips whitespace from IP before lookup' do
        resp = stub_response(success?: true, code: 200, message: 'OK',
                             body: { 'city' => 'TrimCity' }.to_json)
        allow(described_class).to receive(:request_api).with('1.2.3.4').and_return(resp)

        expect(Rails.cache).to receive(:write).with('ip:1.2.3.4', 'TrimCity', expires_in: expiry)
        expect(described_class.fetch('  1.2.3.4  ')).to eq('TrimCity')
      end

      it 'caches and returns postal when present' do
        resp = stub_response(success?: true, code: 200, message: 'OK',
                             body: { 'postal' => '12345' }.to_json)
        allow(described_class).to receive(:request_api).with(ip).and_return(resp)

        expect(Rails.cache).to receive(:write).with(key, '12345', expires_in: expiry)
        expect(described_class.fetch(ip)).to eq('12345')
      end

      it 'caches and returns city when postal missing' do
        resp = stub_response(success?: true, code: 200, message: 'OK',
                             body: { 'city' => 'TestCity' }.to_json)
        allow(described_class).to receive(:request_api).with(ip).and_return(resp)

        expect(Rails.cache).to receive(:write).with(key, 'TestCity', expires_in: expiry)
        expect(described_class.fetch(ip)).to eq('TestCity')
      end

      it 'caches and returns nil when neither postal nor city present' do
        resp = stub_response(success?: true, code: 200, message: 'OK', body: {}.to_json)
        allow(described_class).to receive(:request_api).with(ip).and_return(resp)

        expect(Rails.cache).to receive(:write).with(key, nil, expires_in: expiry)
        expect(described_class.fetch(ip)).to be_nil
      end

      it 'caches and returns nil when API returns error key' do
        resp = stub_response(success?: true, code: 200, message: 'OK',
                             body: { 'error' => 'oops' }.to_json)
        allow(described_class).to receive(:request_api).with(ip).and_return(resp)

        expect(Rails.cache).to receive(:write).with(key, nil, expires_in: expiry)
        expect(described_class.fetch(ip)).to be_nil
      end

      it 'logs HTTP failures and returns nil' do
        resp = stub_response(success?: false, code: 500, message: 'Server Error', body: '')
        allow(described_class).to receive(:request_api).with(ip).and_return(resp)

        expect(Rails.logger).to receive(:error).with("IpLocationService.fetch error for '#{ip}': HTTP error 500: Server Error")
        expect(described_class.fetch(ip)).to be_nil
      end

      it 'logs JSON parse errors and returns nil' do
        resp = stub_response(success?: true, code: 200, message: 'OK', body: 'not_json')
        allow(described_class).to receive(:request_api).with(ip).and_return(resp)

        expect(Rails.logger).to receive(:error).with(/^IpLocationService.fetch error for '#{ip}':/)
        expect(described_class.fetch(ip)).to be_nil
      end

      it 'logs exceptions raised during lookup_and_cache and returns nil' do
        allow(described_class).to receive(:request_api).and_raise(StandardError.new('boom!'))

        expect(Rails.logger).to receive(:error).with("IpLocationService.fetch error for '#{ip}': boom!")
        expect(described_class.fetch(ip)).to be_nil
      end
    end
  end

  describe '.request_api' do
    it 'hits the `self.class.get("/#{ip_str}/json/")` line and raises NoMethodError' do
      expect do
        described_class.send(:request_api, ip)
      end.to raise_error(NoMethodError)
    end
  end
end
