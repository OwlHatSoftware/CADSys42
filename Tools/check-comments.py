#!/usr/bin/env python3
"""Find compiler directives hiding inside brace comments.

Pascal brace comments do not nest, so a { $IFDEF ... } written inside a
{ ... } comment - quoting a directive in prose, say - ends that comment at
its own closing brace, and everything after it becomes code. In a shared
include file that shows up as a wall of errors pointing nowhere near the
cause, which is why it is worth a tool rather than a careful read.

Also reports an unterminated brace comment, which fails the same way.

Usage: python3 Tools/check-comments.py [path ...]
       with no arguments, scans Sources, Test and Demos.
Exit status is 1 when anything was reported.
"""

import io
import os
import sys


def scan(path):
    """Yield (line, message) for every suspicious construct in path."""
    text = io.open(path, encoding='utf-8', errors='replace').read()
    i, n = 0, len(text)
    while i < n:
        ch = text[i]
        if ch == "'":
            # A string literal. '' inside one is an escaped quote, but for
            # this purpose stopping at the first quote is close enough:
            # the next pass just starts on the second half of the string.
            i += 1
            while i < n and text[i] != "'":
                i += 1
            i += 1
        elif ch == '{':
            directive = text[i:i + 2] == '{$'
            close = text.find('}', i)
            if close < 0:
                yield text[:i].count('\n') + 1, 'unterminated { comment'
                return
            if not directive and '{$' in text[i + 1:close]:
                at = text.index('{$', i + 1)
                yield (text[:at].count('\n') + 1,
                       'directive inside a { } comment, so the comment ends '
                       'here: ' + text[at:min(at + 40, close)])
            i = close + 1
        elif text[i:i + 2] == '(*':
            close = text.find('*)', i + 2)
            i = close + 2 if close >= 0 else n
        elif text[i:i + 2] == '//':
            close = text.find('\n', i)
            i = close + 1 if close >= 0 else n
        else:
            i += 1


def sources(roots):
    for root in roots:
        if os.path.isfile(root):
            yield root
            continue
        for base, _dirs, names in os.walk(root):
            for name in sorted(names):
                if os.path.splitext(name)[1].lower() in ('.pas', '.inc',
                                                         '.dpr', '.lpr'):
                    yield os.path.join(base, name)


def main(argv):
    roots = argv[1:]
    if not roots:
        here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        roots = [os.path.join(here, d) for d in ('Sources', 'Test', 'Demos')]
        roots = [r for r in roots if os.path.isdir(r)]
    found = 0
    for path in sources(roots):
        for line, message in scan(path):
            print('%s(%d): %s' % (path, line, message))
            found += 1
    print('%d file(s) checked, %d problem(s)'
          % (sum(1 for _ in sources(roots)), found))
    return 1 if found else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
