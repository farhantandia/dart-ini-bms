.PHONY: test publish

#################################################################################
# GLOBALS                                                                       #
#################################################################################

PROJECT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
PROJECT_NAME = dart-ini

IMAGE_NAME ?= google/dart:2.12
DOCKER_RUN = docker run \
			 --rm \
			 --user $(shell id -u) \
			 --volume $(CURDIR):/project \
			 --volume $(CURDIR)/.pub-cache:/.pub-cache \
			 --workdir /project \
			 --interactive \
			 --tty \
			 $(IMAGE_NAME)

#################################################################################
# COMMANDS                                                                      #
#################################################################################

## Install pub dependencies
install : .make/install

.make/install : pubspec.yaml pubspec.lock
	$(DOCKER_RUN) pub get
	touch .make/install

## Update dart dependencies
upgrade : install
	$(DOCKER_RUN) pub upgrade

## Run the tests
test : install
	$(DOCKER_RUN) pub run test --platform vm --timeout 30s --concurrency=6 --test-randomize-ordering-seed=random --reporter=expanded

## Publish new version.
## This will make you sad, you'll have to exec into the container and curl the callback url.
publish : install
	$(DOCKER_RUN) pub publish

#################################################################################
# PROJECT RULES                                                                 #
#################################################################################



#################################################################################
# Self Documenting Commands                                                     #
#################################################################################

.DEFAULT_GOAL := help

# Inspired by <http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html>
# sed script explained:
# /^##/:
# 	* save line in hold space
# 	* purge line
# 	* Loop:
# 		* append newline + line to hold space
# 		* go to next line
# 		* if line starts with doc comment, strip comment character off and loop
# 	* remove target prerequisites
# 	* append hold space (+ newline) to line
# 	* replace newline plus comments by `---`
# 	* print line
# Separate expressions are necessary because labels cannot be delimited by
# semicolon; see <http://stackoverflow.com/a/11799865/1968>
.PHONY: help
help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@echo
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')

