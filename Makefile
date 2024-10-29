build: 
	docker build -t summer_bot .
run:
	docker run --rm -it -v ./:/usr/src/app summer_bot
b:
	docker run --rm -it -v ./:/usr/src/app summer_bot bash