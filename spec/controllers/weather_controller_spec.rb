# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeatherController, type: :controller do
  include Devise::Test::ControllerHelpers

  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
  end

  describe 'GET #index' do
    context 'when location param is provided' do
      let(:fake_result) { WeatherFetcher::Result.new({ temp: 25 }, false) }

      before do
        allow(WeatherFetcher).to receive(:new).with('Paris').and_return(double(call: fake_result))
        get :index, params: { location: 'Paris' }
      end

      it 'assigns @weather from result.data' do
        expect(controller.instance_variable_get(:@weather)).to eq({ temp: 25 })
      end

      it 'assigns @from_cache from result.from_cache' do
        expect(controller.instance_variable_get(:@from_cache)).to be false
      end

      it 'does not set a flash alert' do
        expect(flash.now[:alert]).to be_nil
      end
    end

    context 'when WeatherFetcher raises UnknownLocationError' do
      before do
        allow(WeatherFetcher).to receive(:new).and_raise(WeatherFetcher::UnknownLocationError)
        get :index, params: { location: 'Invalid' }
      end

      it 'sets flash.now[:alert] with resolution message' do
        expect(flash.now[:alert]).to match(/Could not resolve 'Invalid'/)
      end
    end

    context 'when unexpected error occurs' do
      before do
        allow(WeatherFetcher).to receive(:new).and_raise(RuntimeError.new('boom'))
        get :index, params: { location: 'BoomTown' }
      end

      it 'sets flash.now[:alert] with error message' do
        expect(flash.now[:alert]).to match(/Weather error: boom/)
      end
    end
  end
end
