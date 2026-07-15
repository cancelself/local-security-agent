SCRIPTS := $(wildcard tools/*.sh)

.PHONY: lint test

lint:
	@echo "== syntax =="
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck $(SCRIPTS); \
	else \
		for s in $(SCRIPTS); do bash -n $$s && echo "bash -n OK: $$s"; done; \
	fi
	@echo "== read-only guard (no mutating commands in tools/) =="
	@! grep -nE '(^|[^a-zA-Z_-])(rm |launchctl (bootout|unload|remove)|defaults write|tee |> */(etc|Library|System))' $(SCRIPTS) \
		|| (echo "FORBIDDEN mutating command found in tools/"; exit 1)
	@echo "lint OK"

test:
	@echo "== smoke: inventory runs cleanly (prompt-prone collectors skipped) =="
	@INVENTORY_NO_PROMPT=1 bash tools/startup-inventory.sh > /dev/null
	@echo "test OK"
