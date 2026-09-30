"""aios-context - master context (spec 02). Implemented in step 5 of the plan."""

import sys


def main(argv: list[str]) -> int:
    print(f"aios-context {' '.join(argv)}: not implemented yet (step 5)", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
