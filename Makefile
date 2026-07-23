DOTFILES := $(shell pwd)
HOME := $(HOME)

.PHONY: all install update clean

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
	@echo "=> Applying .claude-cincoders symlinks..."
	@mkdir -p "$(HOME)/.claude-cincoders"
	@for item in $(DOTFILES)/.claude/*; do \
		base=$$(basename "$$item"); \
		[ "$$base" = "settings.local.json" ] && continue; \
		[ "$$base" = "settings.json" ] && continue; \
		target="$(HOME)/.claude-cincoders/$$base"; \
		if [ -e "$$target" ] || [ -L "$$target" ]; then \
			rm -rf "$$target"; \
		fi; \
		ln -sf "$$item" "$$target"; \
		echo "  -> $$target"; \
	done
	@for item in $(DOTFILES)/.claude-cincoders/*; do \
		base=$$(basename "$$item"); \
		[ "$$base" = "settings.local.json" ] && continue; \
		target="$(HOME)/.claude-cincoders/$$base"; \
		if [ -e "$$target" ] || [ -L "$$target" ]; then \
			rm -rf "$$target"; \
		fi; \
		ln -sf "$$item" "$$target"; \
		echo "  -> $$target"; \
	done
	@echo "=> Applying skills symlinks (canonical .agents + both Claude accounts)..."
	@for skdir in "$(HOME)/.agents/skills" "$(HOME)/.claude/skills" "$(HOME)/.claude-cincoders/skills"; do \
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
	@for item in $(DOTFILES)/.claude/* $(DOTFILES)/.claude-cincoders/*; do \
		base=$$(basename "$$item"); \
		[ "$$base" = "settings.local.json" ] && continue; \
		target="$(HOME)/.claude-cincoders/$$base"; \
		if [ -L "$$target" ]; then \
			rm -rf "$$target"; \
			echo "  -> removed: $$target"; \
		fi; \
	done
	@for skdir in "$(HOME)/.agents/skills" "$(HOME)/.claude/skills" "$(HOME)/.claude-cincoders/skills"; do \
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
