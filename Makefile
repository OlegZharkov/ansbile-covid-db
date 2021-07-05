
ifdef CHECK
  CHECK_C := --check --diff
else
  CHECK_C :=
endif
ifdef DIFF
  DIFF_C := --diff
else
  DIFF_C :=
endif

help:
	@echo "Run 'make setup.yml' to re-run ansible for that machine."
	@echo ""
	@echo "Make Variables: (make ... VAR=VALUE)"
	@echo "  DIFF=1         show changes made"
	@echo "  CHECK=1      run in --check mode (implies DIFF=1)"

deps: requirements.yaml
	ansible-galaxy install -p roles -r requirements.yaml

%.yml: deps
	ansible-playbook -i inventory $@ $(CHECK_C) $(DIFF_C)

.PHONY: deps help
