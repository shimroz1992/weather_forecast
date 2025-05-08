# frozen_string_literal: true

# spec/jobs/application_job_spec.rb
require 'rails_helper'

RSpec.describe ApplicationJob, type: :job do
  it 'inherits from ActiveJob::Base' do
    expect(ApplicationJob).to be < ActiveJob::Base
  end

  it 'responds to .perform_later and .perform_now' do
    expect(ApplicationJob).to respond_to(:perform_later)
    expect(ApplicationJob).to respond_to(:perform_now)
  end
end
