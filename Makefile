SHELL := /bin/sh

.PHONY: check check-prereqs check-public-safety

check: check-prereqs check-public-safety

check-prereqs:
	./scripts/check-prereqs.sh

check-public-safety:
	./scripts/check-public-safety.sh
