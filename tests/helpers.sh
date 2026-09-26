# Tiny assertion helpers for the bash test suites (bash 3.2 compatible).

TESTS_RUN=0
TESTS_FAILED=0

assert_eq() { # name expected actual
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$2" != "$3" ]; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"
  fi
}

assert_contains() { # name needle haystack
  TESTS_RUN=$((TESTS_RUN + 1))
  case "$3" in
    *"$2"*) ;;
    *)
      TESTS_FAILED=$((TESTS_FAILED + 1))
      printf 'FAIL %s\n  expected to contain: %s\n  actual: %s\n' "$1" "$2" "$3"
      ;;
  esac
}

# Reads one key from key=value output.
kv() { # key text
  printf '%s\n' "$2" | awk -F= -v k="$1" '$1 == k { sub(/^[^=]*=/, ""); print; exit }'
}

finish() {
  if [ "$TESTS_FAILED" -eq 0 ]; then
    printf 'ok   %s (%d assertions)\n' "$(basename "$0")" "$TESTS_RUN"
  else
    printf 'FAIL %s: %d of %d assertions failed\n' "$(basename "$0")" "$TESTS_FAILED" "$TESTS_RUN"
    exit 1
  fi
}
