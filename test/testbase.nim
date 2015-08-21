import unittest, strutils, ../src/emerald

export unittest, strutils, emerald.html, emerald.filters, emerald.streams

proc diff*(actual, expected: string): bool =
    result = actual.len == expected.len
    for i in 0 .. min(actual.len, expected.len) - 1:
        if actual[i] != expected[i]:
            echo "difference at $1: $2 != $3" % [$i, $actual[i], $expected[i]]
            result = false
    if not result:
        echo "expected:\n$1\n\nactual:\n$2" % [expected, actual]