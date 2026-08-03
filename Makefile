DOTFILES := $(shell pwd)
HOME := $(HOME)

.PHONY: all install profile update clean

all: install

install:
	@echo "=> Applying .config symlinks..."
	@for item in $(DOTFILES)/.config/*; do \
		base=$$(basename "$$item"); \
		target="$(HOME)/.config/$$base"; \
		if [ -e "$$target" ] || [ -L "$$target" ]; then \
			rm -rf "$$target"; \
		fi; \
		ln -sf "$$item" "$$target"; \
		echo "  -> $$target"; \
	done
	@echo "=> Applying .claude symlinks..."
	@mkdir -p "$(HOME)/.claude"
	@for item in $(DOTFILES)/.claude/*; do \
		base=$$(basename "$$item"); \
		[ "$$base" = "settings.local.json" ] && continue; \
		target="$(HOME)/.claude/$$base"; \
		if [ -e "$$target" ] || [ -L "$$target" ]; then \
			rm -rf "$$target"; \
		fi; \
		ln -sf "$$item" "$$target"; \
		echo "  -> $$target"; \
	done
	@echo "=> Applying skills symlinks (canonical .agents + default Claude account)..."
	@for skdir in "$(HOME)/.agents/skills" "$(HOME)/.claude/skills"; do \
		mkdir -p "$$skdir"; \
		for item in $(DOTFILES)/.agents/skills/*; do \
			[ -e "$$item" ] || continue; \
			base=$$(basename "$$item"); \
			target="$$skdir/$$base"; \
			if [ -e "$$target" ] || [ -L "$$target" ]; then \
				rm -rf "$$target"; \
			fi; \
			ln -sf "$$item" "$$target"; \
			echo "  -> $$target"; \
		done; \
	done
	@echo "=> Syncing skills into existing Claude profiles..."
	@for target in $(HOME)/.claude-*; do \
		[ -d "$$target/skills" ] || continue; \
		for item in $(DOTFILES)/.agents/skills/*; do \
			[ -e "$$item" ] || continue; \
			base=$$(basename "$$item"); \
			dest="$$target/skills/$$base"; \
			if [ -e "$$dest" ] && [ ! -L "$$dest" ]; then \
				echo "  ~ keeping real file (not touched): $$dest"; \
				continue; \
			fi; \
			ln -sfn "$$item" "$$dest"; \
			echo "  -> $$dest"; \
		done; \
	done
	@echo "=> Applying .local/bin symlinks..."
	@mkdir -p "$(HOME)/.local/bin"
	@for item in $(DOTFILES)/.local/bin/*; do \
		base=$$(basename "$$item"); \
		target="$(HOME)/.local/bin/$$base"; \
		if [ -e "$$target" ] || [ -L "$$target" ]; then \
			rm -f "$$target"; \
		fi; \
		ln -sf "$$item" "$$target"; \
		chmod +x "$$item"; \
		echo "  -> $$target"; \
	done
	@echo "=> Applying .local/share/applications symlinks..."
	@mkdir -p "$(HOME)/.local/share/applications"
	@for item in $(DOTFILES)/.local/share/applications/*; do \
		base=$$(basename "$$item"); \
		target="$(HOME)/.local/share/applications/$$base"; \
		if [ -e "$$target" ] || [ -L "$$target" ]; then \
			rm -f "$$target"; \
		fi; \
		ln -sf "$$item" "$$target"; \
		echo "  -> $$target"; \
	done
	@echo "=> Done"
	@echo "=> To create an additional Claude profile: make profile"

profile:
	@printf "New Claude profile name: "; \
	read name; \
	[ -n "$$name" ] || { echo "Empty name, aborting."; exit 1; }; \
	dir_name=$$(printf '%s' "$$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'); \
	target="$(HOME)/.claude-$$dir_name"; \
	echo "=> Provisioning profile $$target"; \
	mkdir -p "$$target/skills"; \
	for item in $(DOTFILES)/.claude/*; do \
		base=$$(basename "$$item"); \
		case "$$base" in settings.json|settings.local.json) continue;; esac; \
		dest="$$target/$$base"; \
		if [ -e "$$dest" ] && [ ! -L "$$dest" ]; then \
			echo "  ~ keeping real file (not touched): $$dest"; \
			continue; \
		fi; \
		ln -sfn "$$item" "$$dest"; \
		echo "  -> $$dest"; \
	done; \
	for item in $(DOTFILES)/.agents/skills/*; do \
		[ -e "$$item" ] || continue; \
		base=$$(basename "$$item"); \
		dest="$$target/skills/$$base"; \
		if [ -e "$$dest" ] && [ ! -L "$$dest" ]; then continue; fi; \
		ln -sfn "$$item" "$$dest"; \
	done; \
	if [ ! -e "$$target/settings.json" ]; then \
		cp "$(DOTFILES)/.claude/settings.json" "$$target/settings.json"; \
		echo "  + seeded $$target/settings.json (edit freely per profile)"; \
	else \
		echo "  ~ keeping existing $$target/settings.json"; \
	fi; \
	accounts="$(HOME)/.config/claude/accounts"; \
	mkdir -p "$$(dirname "$$accounts")"; \
	if [ -f "$$accounts" ] && grep -qxF "$$name" "$$accounts"; then \
		echo "=> '$$name' already listed in $$accounts"; \
	else \
		printf '%s\n' "$$name" >> "$$accounts"; \
		echo "=> Added '$$name' to $$accounts"; \
	fi; \
	echo "=> Done. Run 'claude' and select '$$name'."

update:
	@echo "=> Updating dotfiles..."
	git pull
	@$(MAKE) install

clean:
	@echo "=> Removing symlinks..."
	@for item in $(DOTFILES)/.config/*; do \
		base=$$(basename "$$item"); \
		target="$(HOME)/.config/$$base"; \
		if [ -L "$$target" ]; then \
			rm "$$target"; \
			echo "  -> removed: $$target"; \
		fi; \
	done
	@for item in $(DOTFILES)/.claude/*; do \
		base=$$(basename "$$item"); \
		[ "$$base" = "settings.local.json" ] && continue; \
		target="$(HOME)/.claude/$$base"; \
		if [ -L "$$target" ]; then \
			rm -rf "$$target"; \
			echo "  -> removed: $$target"; \
		fi; \
	done
	@for skdir in "$(HOME)/.agents/skills" "$(HOME)/.claude/skills"; do \
		for item in $(DOTFILES)/.agents/skills/*; do \
			[ -e "$$item" ] || continue; \
			base=$$(basename "$$item"); \
			target="$$skdir/$$base"; \
			if [ -L "$$target" ]; then \
				rm -f "$$target"; \
				echo "  -> removed: $$target"; \
			fi; \
		done; \
	done
	@for item in $(DOTFILES)/.local/bin/*; do \
		base=$$(basename "$$item"); \
		target="$(HOME)/.local/bin/$$base"; \
		if [ -L "$$target" ]; then \
			rm -f "$$target"; \
			echo "  -> removed: $$target"; \
		fi; \
	done
	@for item in $(DOTFILES)/.local/share/applications/*; do \
		base=$$(basename "$$item"); \
		target="$(HOME)/.local/share/applications/$$base"; \
		if [ -L "$$target" ]; then \
			rm -f "$$target"; \
			echo "  -> removed: $$target"; \
		fi; \
	done
	@echo "=> Done"
