"""Small Lua lexer helpers for test-only source audits.

This is intentionally not a Lua parser. It only skips comments and string literals
correctly enough to identify calls whose first argument is a quoted identifier.
"""

import re


IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
LONG_BRACKET = re.compile(r"\[(=*)\[")


def _long_bracket_end(source: str, start: int):
    match = LONG_BRACKET.match(source, start)
    if not match:
        return None

    closing = "]" + match.group(1) + "]"
    end = source.find(closing, match.end())
    return len(source) if end < 0 else end + len(closing)


def skip_string_or_comment(source: str, start: int):
    """Return the index immediately after a quote, long string, or comment."""

    if source.startswith("--", start):
        long_end = _long_bracket_end(source, start + 2)
        if long_end is not None:
            return long_end
        newline = source.find("\n", start + 2)
        return len(source) if newline < 0 else newline + 1

    if source[start] in "'\"":
        quote = source[start]
        index = start + 1
        while index < len(source):
            if source[index] == "\\":
                index += 2
            elif source[index] == quote:
                return index + 1
            else:
                index += 1
        return len(source)

    long_end = _long_bracket_end(source, start)
    return long_end if long_end is not None else start + 1


def skip_space_and_comments(source: str, start: int):
    index = start
    while index < len(source):
        if source[index].isspace():
            index += 1
        elif source.startswith("--", index):
            index = skip_string_or_comment(source, index)
        else:
            break
    return index


def read_quoted_string(source: str, start: int):
    if start >= len(source) or source[start] not in "'\"":
        return None, start

    quote = source[start]
    index = start + 1
    value = []
    while index < len(source):
        char = source[index]
        if char == "\\" and index + 1 < len(source):
            value.append(source[index + 1])
            index += 2
        elif char == quote:
            return "".join(value), index + 1
        else:
            value.append(char)
            index += 1
    return None, len(source)


def iter_named_calls(source: str, function_name: str):
    """Yield ``(first_string_argument, name_offset, after_argument)`` calls."""

    index = 0
    while index < len(source):
        if source[index].isspace():
            index += 1
            continue
        if source.startswith("--", index) or source[index] in "'\"[":
            index = skip_string_or_comment(source, index)
            continue

        match = IDENTIFIER.match(source, index)
        if not match:
            index += 1
            continue

        token = match.group(0)
        index = match.end()
        if token != function_name:
            continue
        if match.start() > 0 and source[match.start() - 1] == ".":
            continue

        call_index = skip_space_and_comments(source, index)
        if call_index >= len(source) or source[call_index] != "(":
            continue

        argument_index = skip_space_and_comments(source, call_index + 1)
        value, after_argument = read_quoted_string(source, argument_index)
        if value is not None:
            yield value, match.start(), after_argument


def iter_qualified_string_assignments(source: str, qualified_name: str):
    """Yield string values assigned to a dotted Lua name, ignoring non-code text."""

    parts = qualified_name.split(".")
    index = 0
    while index < len(source):
        if source[index].isspace():
            index += 1
            continue
        if source.startswith("--", index) or source[index] in "'\"[":
            index = skip_string_or_comment(source, index)
            continue

        match = IDENTIFIER.match(source, index)
        if not match:
            index += 1
            continue

        if match.group(0) != parts[0]:
            index = match.end()
            continue

        cursor = match.end()
        matched = True
        for part in parts[1:]:
            cursor = skip_space_and_comments(source, cursor)
            if cursor >= len(source) or source[cursor] != ".":
                matched = False
                break
            cursor = skip_space_and_comments(source, cursor + 1)
            part_match = IDENTIFIER.match(source, cursor)
            if not part_match or part_match.group(0) != part:
                matched = False
                break
            cursor = part_match.end()

        if matched:
            cursor = skip_space_and_comments(source, cursor)
            if cursor < len(source) and source[cursor] == "=":
                value, _ = read_quoted_string(
                    source, skip_space_and_comments(source, cursor + 1)
                )
                if value is not None:
                    yield value, match.start()

        index = match.end()


def code_without_comments_and_strings(source: str):
    """Replace ignored Lua text with spaces while preserving source positions."""

    result = list(source)
    index = 0
    while index < len(source):
        if (
            source.startswith("--", index)
            or source[index] in "'\""
            or LONG_BRACKET.match(source, index)
        ):
            end = skip_string_or_comment(source, index)
            for position in range(index, end):
                if result[position] not in "\r\n":
                    result[position] = " "
            index = end
        else:
            index += 1
    return "".join(result)


def find_call_table(source: str, after_argument: int):
    """Return the first table argument after a quoted call argument, if present."""

    index = skip_space_and_comments(source, after_argument)
    if index >= len(source) or source[index] != ",":
        return None

    index = skip_space_and_comments(source, index + 1)
    if index >= len(source) or source[index] != "{":
        return None

    end = find_matching_brace(source, index)
    return None if end is None else source[index + 1 : end]


def find_matching_brace(source: str, start: int):
    depth = 0
    index = start
    while index < len(source):
        if source.startswith("--", index) or source[index] in "'\"[":
            index = skip_string_or_comment(source, index)
            continue
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return index
        index += 1
    return None
