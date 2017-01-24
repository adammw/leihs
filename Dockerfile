FROM ruby:2.3-slim

# Install deps required for bundling
RUN apt-get update && apt-get install -y git build-essential libmysqlclient-dev file imagemagick

# Gems
COPY Gemfile* /usr/src/app/
COPY engines/leihs_admin/ /usr/src/app/engines/leihs_admin/
COPY engines/procurement/ /usr/src/app/engines/procurement/
WORKDIR /usr/src/app
RUN bundle install --without development test

# Code
COPY . /usr/src/app
RUN bundle check
COPY config/database_env.yml /usr/src/app/config/database.yml

# Compile assets
ARG RAILS_ENV=production
RUN RAILS_ENV=${RAILS_ENV} PRECOMPILE=1 bundle exec rake assets:precompile

# Run and expose server
EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
