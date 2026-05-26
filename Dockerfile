# syntax=docker/dockerfile:1
FROM ruby:3.3-slim AS base

ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential git libpq-dev ffmpeg curl ca-certificates libyaml-dev cmake && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

FROM base AS deps
COPY Gemfile Gemfile.lock ./
RUN bundle install

FROM deps AS app
COPY . .
EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
