# frozen_string_literal: true

require 'test_helper'

class WeatherControllerTest < ActionDispatch::IntegrationTest
  test 'should get index' do
    get weather_index_url
    assert_response :success
  end

  test 'should get fetch' do
    get weather_fetch_url
    assert_response :success
  end
end
