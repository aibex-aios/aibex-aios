"""Dialog of the writing commands: plan, one confirmation, abort (spec 01, I7)."""

import sys


class Abort(Exception):
    """Stop the command with a message, nothing (more) is written."""


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
            print(("      " if action else "      (") + text + ("" if action else ")"))

    def run(self):
        for _, action in self.steps:
            if action:
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
    plan.show()
    if not ask(question):
        print(f"   {cancelled}")
        return False
    plan.run()
    return True


def say(text):
    print(text)


def warn(text):
    print(f"   warning: {text}", file=sys.stderr)
