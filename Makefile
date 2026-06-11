.PHONY: test

test:
	nvim --headless -u NONE -l tests/markdown_spec.lua
