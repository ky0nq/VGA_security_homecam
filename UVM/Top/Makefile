AUTH_COVERAGE_DIRS := \
	AUTH_SUCCESS/SIM/sim/coverage.vdb \
	AUTH_LOCKOUT/SIM/sim/coverage.vdb
AUTH_MERGED_COVERAGE_DIR := AUTH_MERGED_COVERAGE

.PHONY: auth-success auth-lockout auth coverage-auth auth-all

# Each authentication test uses an independent output directory.
auth-success:
	$(MAKE) -C AUTH_SUCCESS/SIM run

auth-lockout:
	$(MAKE) -C AUTH_LOCKOUT/SIM run

auth:
	$(MAKE) -j2 auth-success auth-lockout

coverage-auth:
	rm -rf $(AUTH_MERGED_COVERAGE_DIR)/merged.vdb \
		$(AUTH_MERGED_COVERAGE_DIR)/report
	mkdir -p $(AUTH_MERGED_COVERAGE_DIR)
	urg -dir $(AUTH_COVERAGE_DIRS) \
		-dbname $(AUTH_MERGED_COVERAGE_DIR)/merged.vdb \
		-report $(AUTH_MERGED_COVERAGE_DIR)/report

# Complete both simulations before starting the coverage merge.
auth-all: auth
	$(MAKE) coverage-auth
