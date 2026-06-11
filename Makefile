.PHONY: test

test:
	nvim --headless -u NONE -l tests/markdown_spec.lua
	nvim --headless -u NONE -l tests/command_spec.lua
