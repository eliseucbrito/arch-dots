DOTFILES := $(shell pwd)
HOME := $(HOME)

# Claude profile dirs: ~/.claude plus one ~/.claude-<slug> per line in
# ~/.config/claude/accounts (name lowercased, spaces -> dashes).
CLAUDE_PROFILES := $(HOME)/.claude $(shell \
	if [ -f "$(HOME)/.config/claude/accounts" ]; then \
		while IFS= read -r n; do \
			[ -n "$$n" ] || continue; \
			slug=$$(printf '%s' "$$n" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'); \
			d="$(HOME)/.claude-$$slug"; \
			[ -d "$$d" ] && printf '%s ' "$$d"; \
		done < "$(HOME)/.config/claude/accounts"; \
	fi)

.PHONY: all install system profile update clean

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
	@echo "=> Applying .claude symlinks to all profiles..."
	@for profile in $(CLAUDE_PROFILES); do \
		mkdir -p "$$profile"; \
		echo "  [$$profile]"; \
		for item in $(DOTFILES)/.claude/*; do \
			base=$$(basename "$$item"); \
			case "$$base" in settings.local.json|skills) continue;; esac; \
			target="$$profile/$$base"; \
			if [ -e "$$target" ] || [ -L "$$target" ]; then \
				rm -rf "$$target"; \
			fi; \
			ln -sf "$$item" "$$target"; \
			echo "    -> $$target"; \
		done; \
	done
	@echo "=> Installing skills from skill-lock into $(DOTFILES)/.claude/skills..."
	@mkdir -p "$(HOME)/.agents/skills" "$(DOTFILES)/.claude/skills"
	@while IFS= read -r line; do \
		case "$$line" in \#*|"") continue;; esac; \
		name=$$(echo "$$line" | awk '{print $$1}'); \
		src=$$(echo "$$line" | awk '{print $$2}'); \
		case "$$src" in \
			./*) abs="$(DOTFILES)/$${src#./}";; \
			/*)   abs="$$src";; \
			*)    echo "  ! skip $$name (bad source: $$src)"; continue;; \
		esac; \
		if [ ! -e "$$abs" ] && [ ! -L "$$abs" ]; then \
			echo "  ! skip $$name (source not found: $$abs)"; \
			continue; \
		fi; \
		for skdir in "$(HOME)/.agents/skills" "$(DOTFILES)/.claude/skills"; do \
			target="$$skdir/$$name"; \
			if [ -L "$$target" ] || { [ -e "$$target" ] && [ ! -d "$$target" ]; }; then \
				rm -rf "$$target"; \
			elif [ -d "$$target" ]; then \
				continue; \
			fi; \
			ln -sf "$$abs" "$$target"; \
		done; \
		echo "  -> $$name"; \
	done < $(DOTFILES)/skill-lock
	@echo "=> Linking shared skills dir into all profiles..."
	@for profile in $(CLAUDE_PROFILES); do \
		dest="$$profile/skills"; \
		if [ -e "$$dest" ] || [ -L "$$dest" ]; then \
			rm -rf "$$dest"; \
		fi; \
		ln -sfn "$(DOTFILES)/.claude/skills" "$$dest"; \
		echo "  -> $$dest"; \
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
	@echo "=> Root-owned system config (Docker out of 172.16/12): sudo make system"

system:
	@echo "=> Installing root-owned system config (needs sudo)..."
	sudo $(DOTFILES)/system/install.sh

profile:
	@printf "New Claude profile name: "; \
	read name; \
	[ -n "$$name" ] || { echo "Empty name, aborting."; exit 1; }; \
	dir_name=$$(printf '%s' "$$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'); \
	target="$(HOME)/.claude-$$dir_name"; \
	echo "=> Provisioning profile $$target"; \
	mkdir -p "$$target/hooks"; \
	for item in $(DOTFILES)/.claude/*; do \
		base=$$(basename "$$item"); \
		case "$$base" in settings.local.json|skills) continue;; esac; \
		dest="$$target/$$base"; \
		if [ -e "$$dest" ] || [ -L "$$dest" ]; then rm -rf "$$dest"; fi; \
		ln -sfn "$$item" "$$dest"; \
		echo "  -> $$dest"; \
	done; \
	ln -sfn "$(DOTFILES)/.claude/skills" "$$target/skills"; \
	echo "  -> $$target/skills"; \
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
	@for profile in $(CLAUDE_PROFILES); do \
		for item in $(DOTFILES)/.claude/*; do \
			base=$$(basename "$$item"); \
			[ "$$base" = "settings.local.json" ] && continue; \
			target="$$profile/$$base"; \
			if [ -L "$$target" ]; then \
				rm -rf "$$target"; \
				echo "  -> removed: $$target"; \
			fi; \
		done; \
		[ -L "$$profile/skills" ] && { rm -f "$$profile/skills"; echo "  -> removed: $$profile/skills"; }; \
	done
	@while IFS= read -r line; do \
		case "$$line" in \#*|"") continue;; esac; \
		name=$$(echo "$$line" | awk '{print $$1}'); \
		target="$(HOME)/.agents/skills/$$name"; \
		if [ -L "$$target" ]; then \
			rm -f "$$target"; \
			echo "  -> removed: $$target"; \
		fi; \
	done < $(DOTFILES)/skill-lock
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
