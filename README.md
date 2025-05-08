# Simple Rails Application

This guide covers the steps to get a minimal Ruby on Rails application running, using the included `Gemfile`.

---

## Prerequisites

* **Ruby**: 3.0.2 (managed via rbenv, rvm, or chruby)
* **Bundler**: `gem install bundler`
* **PostgreSQL**: v10+
* **Node.js & Yarn**: Optional; only needed if adding JS packages beyond importmaps
* **Redis**: Optional; required if you enable Action Cable in production

---

## Setup & Installation

1. **Clone the repo**

   ```bash
   git clone https://github.com/shimroz1992/weather_forecast.git
   cd weather_forecast
   ```

2. **Install gems**

   ```bash
   bundle install
   ```

---

## Database

1. **Create & migrate**

   ```bash
   bin/rails db:create
   bin/rails db:migrate
   ```

2. **(Optional) Seed data**

   ```bash
   bin/rails db:seed
   ```

---

## Running the App

* **Start the Rails server**

  ```bash
  bin/rails server
  ```

* **Access**
  Open [http://localhost:3000](http://localhost:3000) in your browser.

---

## Test Suite

This project uses RSpec for testing and SimpleCov for coverage reports.

1. **Run specs**

   ```bash
   bundle exec rspec
   ```

2. **View coverage**
   After spec run, open `coverage/index.html` in your browser.

---

## Development Tools

* **Debugging**: `debug` gem; insert `byebug` or `binding.irb` in code
* **Console**:

  ```bash
  bin/rails console
  ```
* **Rubocop** for style checks:

  ```bash
  bundle exec rubocop
  ```

---

## Services & Background Jobs

* **Action Cable**: configured to use Redis in production (uncomment `redis` gem)
* **Sidekiq / Active Job**: configure adapters in `config/application.rb` if needed

---

## Deployment

1. **Precompile assets**

   ```bash
   RAILS_ENV=production bin/rails assets:precompile
   ```

2. **Database setup** on your host:

   ```bash
   RAILS_ENV=production bin/rails db:create db:migrate
   ```

3. **Start with Puma**

   ```bash
   RAILS_ENV=production bundle exec puma -C config/puma.rb
   ```

4. **Env vars**
   Ensure `SECRET_KEY_BASE`, `DATABASE_URL`, and any API keys are set in your environment.

---

## Further Reading

* [Rails Guides](https://guides.rubyonrails.org/)
* [RSpec Rails](https://github.com/rspec/rspec-rails)
* [Importmap Rails](https://github.com/rails/importmap-rails)
* [Hotwire (Turbo & Stimulus)](https://hotwired.dev/)

---

*Happy coding!*
