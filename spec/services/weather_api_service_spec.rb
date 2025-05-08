# frozen_string_literal: true

# spec/services/weather_api_service_spec.rb
require 'rails_helper'

RSpec.describe WeatherApiService, type: :service do
  let(:location) { 'TestCity' }
  let(:api_key)  { WeatherApiService::API_KEY }
  let(:base_uri) { WeatherApiService.base_uri }

  describe '.fetch' do
    context 'when the API returns valid data' do
      let(:api_response) do
        {
          'location' => {
            'name' => 'TestCity',
            'country' => 'TestLand',
            'localtime' => '2025-05-08 10:00'
          },
          'current' => {
            'temp_c' => 22,
            'condition' => { 'text' => 'Sunny', 'icon' => 'icon_url' }
          },
          'forecast' => {
            'forecastday' => [
              {
                'date' => '2025-05-08',
                'day' => {
                  'maxtemp_c' => 25,
                  'mintemp_c' => 15,
                  'condition' => { 'text' => 'Clear', 'icon' => 'icon2' }
                },
                'hour' => [
                  {
                    'time' => '2025-05-08 10:00',
                    'temp_c' => 22,
                    'condition' => { 'text' => 'Sunny', 'icon' => 'icon_url' }
                  },
                  {
                    'time' => '2025-05-08 12:00',
                    'temp_c' => 24,
                    'condition' => { 'text' => 'Hot', 'icon' => 'icon3' }
                  },
                  # outside interval (e.g. 24h later) should be ignored
                  {
                    'time' => '2025-05-09 10:00',
                    'temp_c' => 18,
                    'condition' => { 'text' => 'Cool', 'icon' => 'icon4' }
                  }
                ]
              }
            ]
          }
        }
      end

      let(:response_double) do
        double(
          success?: true,
          code: 200,
          message: 'OK',
          body: api_response.to_json
        )
      end

      before do
        allow(WeatherApiService).to receive(:request_forecast)
          .with(location)
          .and_return(response_double)
      end

      it 'returns a fully structured hash' do
        result = WeatherApiService.fetch(location)

        expect(result[:city]).to        eq('TestCity')
        expect(result[:country]).to     eq('TestLand')
        expect(result[:temperature]).to eq(22)
        expect(result[:condition]).to   eq('Sunny')
        expect(result[:icon]).to        eq('icon_url')
        expect(result[:high]).to        eq(25)
        expect(result[:low]).to         eq(15)

        # forecast_day
        expect(result[:forecast_day]).to eq(
          date: '2025-05-08',
          condition: 'Clear',
          icon: 'icon2',
          high: 25,
          low: 15
        )

        # hourly_forecast only includes the two entries at 10:00 and 12:00
        hours = result[:hourly_forecast]
        expect(hours.size).to            eq(2)
        expect(hours.first[:time]).to    eq('10:00')
        expect(hours.first[:temp_c]).to  eq(22)
        expect(hours.second[:time]).to   eq('12:00')
        expect(hours.second[:temp_c]).to eq(24)
      end
    end

    context 'when HTTP returns a non-200 status' do
      let(:fail_resp) { double(success?: false, code: 500, message: 'Server Error', body: '') }

      before do
        allow(WeatherApiService).to receive(:request_forecast)
          .with(location)
          .and_return(fail_resp)
      end

      it 'logs and returns nil' do
        expect(Rails.logger).to receive(:error)
          .with("WeatherAPI.fetch error for 'TestCity': HTTP error 500: Server Error")

        expect(WeatherApiService.fetch(location)).to be_nil
      end
    end

    context 'when the API returns a JSON error key' do
      let(:error_body) { { 'error' => { 'message' => 'Bad query' } }.to_json }
      let(:error_resp) { double(success?: true, code: 200, message: 'OK', body: error_body) }

      before do
        allow(WeatherApiService).to receive(:request_forecast)
          .with(location)
          .and_return(error_resp)
      end

      it 'logs and returns nil' do
        expect(Rails.logger).to receive(:error)
          .with("WeatherAPI.fetch error for 'TestCity': Bad query")

        expect(WeatherApiService.fetch(location)).to be_nil
      end
    end

    context 'when an unexpected exception occurs' do
      before do
        allow(WeatherApiService).to receive(:request_forecast)
          .with(location)
          .and_raise(StandardError.new('boom!'))
      end

      it 'logs and returns nil' do
        expect(Rails.logger).to receive(:error)
          .with("WeatherAPI.fetch error for 'TestCity': boom!")

        expect(WeatherApiService.fetch(location)).to be_nil
      end
    end
  end

  describe 'private helpers' do
    describe '.request_forecast' do
      it 'invokes HTTParty.get with the correct path and query' do
        expect(WeatherApiService).to receive(:get).with(
          WeatherApiService::FORECAST_PATH,
          query: {
            key: api_key,
            q: location,
            aqi: 'no'
          }
        ).and_return(:some_response)

        expect(
          WeatherApiService.send(:request_forecast, location)
        ).to eq(:some_response)
      end
    end

    describe '.format_query' do
      it 'strips whitespace for numeric zip codes' do
        expect(WeatherApiService.send(:format_query, ' 12345 ')).to eq(' 12345 ')
      end

      it 'returns the raw string for non-numeric locations' do
        expect(WeatherApiService.send(:format_query, ' London ')).to eq(' London ')
      end
    end
  end
end
