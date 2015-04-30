import ../src/emerald/filters
import ../src/emerald/filters/impl
import unittest, streams

suite "filtering tests":
    setup:
        var ss: StringStream

    test "runtime filtering without escapable characters":
        ss = newStringStream()
        const input = "Lorem ipsum dolor sit amet, \"consectetuer\" adipiscing elit. Aenean commodo ligula eget dolor."
        filter(ss, escapeHtml, input)
        check ss.data == input

# TODO: doesn't work for some reason
#    test "compiletime filtering without escapable characters":
#        ss = newStringStream()
#        filter(ss, escapeHtml, "String literal containing no escapable characters")
#        check ss.data == "String literal containing no escapable characters"

    test "runtime filtering with escapable characters":
        ss = newStringStream()
        const input = "∀ ε > 0 ∃ N ∈ ℕ ∀ n >= ℕ: | a_n - a | < ε"
        filter(ss, escapeHtml, input)
        check ss.data == "∀ ε &gt; 0 ∃ N ∈ ℕ ∀ n &gt;= ℕ: | a_n - a | &lt; ε"

    test "runtime filtering with additional escapable characters":
        ss = newStringStream()
        const input = "<a href=\"example.com\">link</a>"
        filter(ss, escapeHtml, input, true)
        check ss.data == "&lt;a href=&quot;example.com&quot;&gt;link&lt;/a&gt;"