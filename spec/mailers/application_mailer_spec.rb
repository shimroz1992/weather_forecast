# frozen_string_literal: true

# spec/mailers/application_mailer_spec.rb
require 'rails_helper'

RSpec.describe ApplicationMailer, type: :mailer do
  describe 'defaults and layout' do
    it 'sets the default from address' do
      expect(described_class.default[:from]).to eq('from@example.com')
    end

    it 'uses the mailer layout' do
      # Layout is stored in the _layout class attr by the `layout` macro
      expect(described_class._layout).to eq('mailer')
    end
  end
end
