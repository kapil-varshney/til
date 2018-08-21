DATE := $(shell date +%Y/%m/%d)

server:
	hugo server -D --disableFastRender

new:
	@printf "Filename: " && read FILE && hugo new posts/$(DATE)/$$FILE
