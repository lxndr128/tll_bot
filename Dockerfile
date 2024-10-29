FROM ruby:3.0.2-alpine

RUN gem install bundler -v 2.4.18

ARG PACKAGES="build-base nano bash"
RUN apk update && apk upgrade && apk add --update $PACKAGES

ADD . /usr/src/app
WORKDIR /usr/src/app

RUN bundle install

CMD ["ruby", "main.rb"]