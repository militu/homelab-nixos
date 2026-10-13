.PHONY: ci

# Evaluate every declared system and run the checks of the runner architecture.
# The weekly workflow proposes the lock; this gate owns its validation.
ci:
	nix flake check --no-update-lock-file --print-build-logs
	@build=1; \
	if [ -n "$${CI_BASE:-}" ]; then \
		changed="$$(git diff --name-only "$${CI_BASE}...HEAD")" || exit 1; \
		local_changes="$$(git diff --name-only HEAD)" || exit 1; \
		if ! printf '%s\n%s\n' "$$changed" "$$local_changes" | grep -qvE '^(\.github/|renovate\.json$$|mise\.toml$$|$$)'; then build=0; fi; \
	fi; \
	if [ "$$build" = 1 ]; then \
		nix build --no-update-lock-file .#nixosConfigurations.titan.config.system.build.toplevel --no-link --print-build-logs; \
	fi
