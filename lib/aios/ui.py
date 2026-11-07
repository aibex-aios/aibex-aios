"""Dialog of the writing commands: plan, one confirmation, abort (spec 01, I7)."""

import os
import sys


MODE = "ask"                                        # ask | yes (--yes) | plan (--plan)


class Abort(Exception):
    """Stop the command with a message, nothing (more) is written."""


class PlanOnly(Exception):
    """--plan: the plan was shown, nothing is written (exit 0)."""


class Plan:
    """Steps shown before anything is written, executed after one confirmation."""

    def __init__(self):
        self.steps = []

    def add(self, text, action=None):
        self.steps.append((text, action))

    def __bool__(self):
        return any(action for _, action in self.steps)

    def show(self):
        print("   plan:")
        for text, action in self.steps:
            if text is None:                        # a step that only the result names (H36)
                continue
            print(("      " if action else "      (") + text + ("" if action else ")"))

    def run(self):
        """Run the actions in order. AIOS_TEST_FAIL=<n>[:crash] (tests, spec 04) lets the n-th
        action fail, or with :crash end the process there without any clean-up."""
        fail = os.environ.get("AIOS_TEST_FAIL", "")
        n = 0
        for _, action in self.steps:
            if action:
                n += 1
                if fail and fail.split(":")[0] == str(n):
                    if fail.endswith(":crash"):
                        os._exit(70)
                    raise RuntimeError(f"AIOS_TEST_FAIL: step {n} fails")
                action()


def ask(question):
    sys.stdout.write(f"   {question} [Y/n] ")
    sys.stdout.flush()
    line = sys.stdin.readline()
    if not line:                                    # no input: never write
        print()
        return False
    return line.strip().lower() in ("", "y", "yes", "j", "ja")


def confirm(plan, question, cancelled):
    """Show the plan; --plan stops here, --yes skips the question and the plan: with --yes a
    command prints only its result and errors (spec 04)."""
    if MODE != "yes":
        plan.show()
    proceed(question, cancelled)
    plan.run()
    return True


def proceed(question, cancelled):
    """After showing a plan: raise PlanOnly (--plan), go on (--yes) or ask; Abort on no."""
    if MODE == "plan":
        print("   (plan only, nothing written)")
        raise PlanOnly()
    if MODE != "yes" and not ask(question):
        print(f"   {cancelled}")
        raise Cancelled()


def extra(lines, question, hint):
    """A step with its own question after the plan (spec 04; V0.6, memos 17, 30, 49): --plan
    shows it, --yes skips it and names the hint, otherwise the lines and the question."""
    if MODE == "plan":
        for line in lines:
            print(f"   then with its own question: {line}")
        return False
    if MODE == "yes":
        if hint:
            print(f"   {hint}")
        return False
    print("   own question:")
    for line in lines:
        print(f"      {line}")
    return ask(question)


class Cancelled(Exception):
    """The user said no (exit 1)."""


def say(text):
    print(text)


def warn(text):
    print(f"   warning: {text}", file=sys.stderr)
