no_docker_build:
	apt-get install ruby -y
	apt-get install ruby-bundler -y
	bundle install

no_docker_run:
	ruby main.rb start

no_docker_stop:
	kill -9 $(cat ./bot.pid)

build: 
	docker build -t summer_bot .
run:
	docker run --rm -it -v ./:/usr/src/app summer_bot
b:
	docker run --rm -it -v ./:/usr/src/app summer_bot bash