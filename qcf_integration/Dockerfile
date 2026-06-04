FROM ruby:3.2-slim
WORKDIR /app
COPY Gemfile Gemfile.lock* ./
RUN apt-get update && apt-get install -y build-essential libsqlite3-dev && rm -rf /var/lib/apt/lists/*
RUN bundle install --jobs 4 --retry 3
COPY . .
EXPOSE 4567
CMD ["ruby", "app.rb"]
