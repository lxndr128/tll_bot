no_docker_build:
	apt-get install ruby -y
	apt-get install ruby-bundler -y
	bundle install

no_docker_run:
	ruby main.rb start

no_docker_stop:
	-pkill -f "ruby main.rb"
	-pkill -9 -f "ruby main.rb" 
	rm -f ./bot.pid
	echo "Bot stopped"

no_docker_restart: no_docker_stop no_docker_run
	@echo "Bot restarted"

build: 
	docker build -t summer_bot .
run:
	docker run --rm -it -v ./:/usr/src/app summer_bot
b:
	docker run --rm -it -v ./:/usr/src/app summer_bot bash
