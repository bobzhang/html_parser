#!/usr/bin/env python3
"""Check that tracked source files stay in publishable package locations."""

from __future__ import annotations

import pathlib
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]


def error(message: str) -> None:
    print(message, file=sys.stderr)


def git_tracked_files() -> set[str]:
    result = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return set(result.stdout.splitlines())


def main(argv: list[str]) -> int:
    if argv:
        error("usage: python3 scripts/check_source_layout.py")
        return 2

    tracked = git_tracked_files()
    ok = True

    required_top_level = {
        "moon.mod.json",
        "moon.pkg",
        "pkg.generated.mbti",
        "README.mbt.md",
        "README.md",
        "LICENSE",
        "Python2MoonBit.md",
        "MigrationChecklist.md",
    }
    for path in sorted(required_top_level):
        if path not in tracked:
            error(f"required top-level project file is not tracked: {path}")
            ok = False

    required_root_modules = {
        "html_parser.mbt",
        "parser.mbt",
        "tokens.mbt",
        "dom.mbt",
        "serialize.mbt",
        "sanitize.mbt",
        "transforms.mbt",
        "markdown.mbt",
        "linkify.mbt",
        "stream.mbt",
        "cli.mbt",
        "types.mbt",
    }
    for path in sorted(required_root_modules):
        if path not in tracked:
            error(f"expected root package module is not tracked: {path}")
            ok = False

    required_tokenizer_modules = {
        "tokenizer/comment_scan.mbt",
        "tokenizer/doctype.mbt",
        "tokenizer/entity.mbt",
        "tokenizer/source.mbt",
        "tokenizer/special_text.mbt",
        "tokenizer/types.mbt",
    }
    for path in sorted(required_tokenizer_modules):
        if path not in tracked:
            error(f"expected tokenizer package module is not tracked: {path}")
            ok = False

    required_tokenizer_tests = {
        "tokenizer/source_wbtest.mbt",
        "tokenizer/special_text_wbtest.mbt",
    }
    for path in sorted(required_tokenizer_tests):
        if path not in tracked:
            error(f"expected tokenizer package test module is not tracked: {path}")
            ok = False

    required_sanitize_modules = {
        "sanitize/attributes.mbt",
        "sanitize/content.mbt",
        "sanitize/css.mbt",
        "sanitize/namespaces.mbt",
        "sanitize/nodes.mbt",
        "sanitize/observer.mbt",
        "sanitize/policy.mbt",
        "sanitize/sanitize.mbt",
        "sanitize/syntax.mbt",
        "sanitize/text.mbt",
        "sanitize/types.mbt",
        "sanitize/url.mbt",
    }
    for path in sorted(required_sanitize_modules):
        if path not in tracked:
            error(f"expected sanitize package module is not tracked: {path}")
            ok = False

    required_sanitize_tests = {
        "sanitize/sanitize_wbtest.mbt",
    }
    for path in sorted(required_sanitize_tests):
        if path not in tracked:
            error(f"expected sanitize package test module is not tracked: {path}")
            ok = False

    required_linkify_modules = {
        "linkify/dom.mbt",
        "linkify/linkify.mbt",
        "linkify/punycode.mbt",
    }
    for path in sorted(required_linkify_modules):
        if path not in tracked:
            error(f"expected linkify package module is not tracked: {path}")
            ok = False

    required_linkify_tests = {
        "linkify/dom_wbtest.mbt",
        "linkify/linkify_wbtest.mbt",
        "linkify/punycode_wbtest.mbt",
    }
    for path in sorted(required_linkify_tests):
        if path not in tracked:
            error(f"expected linkify package test module is not tracked: {path}")
            ok = False

    required_selector_modules = {
        "selector/attributes.mbt",
        "selector/basic.mbt",
        "selector/budget.mbt",
        "selector/identity.mbt",
        "selector/limited.mbt",
        "selector/limits.mbt",
        "selector/parse.mbt",
        "selector/pseudo.mbt",
        "selector/query.mbt",
        "selector/selector.mbt",
        "selector/simple.mbt",
        "selector/structural.mbt",
        "selector/syntax.mbt",
        "selector/text.mbt",
        "selector/traversal.mbt",
        "selector/validation.mbt",
    }
    for path in sorted(required_selector_modules):
        if path not in tracked:
            error(f"expected selector package module is not tracked: {path}")
            ok = False

    required_selector_tests = {
        "selector/selector_wbtest.mbt",
    }
    for path in sorted(required_selector_tests):
        if path not in tracked:
            error(f"expected selector package test module is not tracked: {path}")
            ok = False

    required_transform_modules = {
        "transform/attributes.mbt",
        "transform/builders.mbt",
        "transform/decide.mbt",
        "transform/linkify.mbt",
        "transform/node_drop.mbt",
        "transform/node_edit.mbt",
        "transform/normalization.mbt",
        "transform/pipeline.mbt",
        "transform/prune.mbt",
        "transform/reporting.mbt",
        "transform/selectors.mbt",
        "transform/spec.mbt",
        "transform/url_style.mbt",
        "transform/whitespace.mbt",
    }
    for path in sorted(required_transform_modules):
        if path not in tracked:
            error(f"expected transform package module is not tracked: {path}")
            ok = False

    required_transform_tests = {
        "transform/transform_wbtest.mbt",
    }
    for path in sorted(required_transform_tests):
        if path not in tracked:
            error(f"expected transform package test module is not tracked: {path}")
            ok = False

    required_parser_modules = {
        "parser/active_formatting.mbt",
        "parser/api.mbt",
        "parser/attributes.mbt",
        "parser/body_tags.mbt",
        "parser/caption.mbt",
        "parser/column_group.mbt",
        "parser/diagnostics.mbt",
        "parser/document_shell.mbt",
        "parser/end_tags.mbt",
        "parser/fragment_context.mbt",
        "parser/frameset.mbt",
        "parser/foreign_adjustments.mbt",
        "parser/foreign_content.mbt",
        "parser/markup.mbt",
        "parser/parser.mbt",
        "parser/scaffold.mbt",
        "parser/scope.mbt",
        "parser/select.mbt",
        "parser/special_text.mbt",
        "parser/start_tags.mbt",
        "parser/stack.mbt",
        "parser/state.mbt",
        "parser/syntax.mbt",
        "parser/table_end_tags.mbt",
        "parser/table_normalize.mbt",
        "parser/table_context.mbt",
        "parser/template_context.mbt",
        "parser/template_table_context.mbt",
        "parser/text.mbt",
        "parser/types.mbt",
        "parser/xml_coercion.mbt",
    }
    for path in sorted(required_parser_modules):
        if path not in tracked:
            error(f"expected parser package module is not tracked: {path}")
            ok = False

    required_parser_tests = {
        "parser/parser_wbtest.mbt",
    }
    for path in sorted(required_parser_tests):
        if path not in tracked:
            error(f"expected parser package test module is not tracked: {path}")
            ok = False

    required_cli_modules = {
        "cli/cli.mbt",
    }
    for path in sorted(required_cli_modules):
        if path not in tracked:
            error(f"expected cli package module is not tracked: {path}")
            ok = False

    required_cli_tests = {
        "cli/cli_wbtest.mbt",
    }
    for path in sorted(required_cli_tests):
        if path not in tracked:
            error(f"expected cli package test module is not tracked: {path}")
            ok = False

    required_serializer_modules = {
        "serializer/elements.mbt",
        "serializer/escape.mbt",
        "serializer/rawtext.mbt",
        "serializer/serializer.mbt",
        "serializer/start_tag.mbt",
        "serializer/whitespace.mbt",
    }
    for path in sorted(required_serializer_modules):
        if path not in tracked:
            error(f"expected serializer package module is not tracked: {path}")
            ok = False

    required_serializer_tests = {
        "serializer/serializer_wbtest.mbt",
    }
    for path in sorted(required_serializer_tests):
        if path not in tracked:
            error(f"expected serializer package test module is not tracked: {path}")
            ok = False

    required_root_tests = {
        "builder_public_regression_test.mbt",
        "cli_test.mbt",
        "cli_public_regression_test.mbt",
        "constructor_public_regression_test.mbt",
        "dom_public_regression_test.mbt",
        "encoding_fixtures_test.mbt",
        "encoding_public_regression_test.mbt",
        "golden_output_regression_test.mbt",
        "html_parser_test.mbt",
        "linkify_dom_test.mbt",
        "linkify_fixtures_test.mbt",
        "linkify_public_regression_test.mbt",
        "linkify_test.mbt",
        "parser_public_regression_test.mbt",
        "public_api_regression_test.mbt",
        "sanitize_fixtures_test.mbt",
        "security_policy_regression_test.mbt",
        "serializer_public_regression_test.mbt",
        "selector_public_regression_test.mbt",
        "stream_test.mbt",
        "text_markdown_public_regression_test.mbt",
        "token_stream_regression_test.mbt",
        "tokenizer_fixtures_test.mbt",
        "transform_public_regression_test.mbt",
        "transforms_test.mbt",
        "treebuilder_fixtures_test.mbt",
    }
    for path in sorted(required_root_tests):
        if path not in tracked:
            error(f"expected root package test module is not tracked: {path}")
            ok = False

    package_dirs = {
        str(pathlib.PurePosixPath(path).parent)
        for path in tracked
        if pathlib.PurePosixPath(path).name == "moon.pkg"
    }
    package_dirs = {"." if package_dir == "." else package_dir for package_dir in package_dirs}
    if "." not in package_dirs:
        error("root package moon.pkg is not tracked")
        ok = False

    for package_dir in sorted(package_dirs):
        prefix = "" if package_dir == "." else f"{package_dir}/"
        interface_path = f"{prefix}pkg.generated.mbti"
        if interface_path not in tracked:
            error(f"package {package_dir} must track {interface_path}")
            ok = False
        has_package_source = any(
            path.startswith(prefix)
            and "/" not in path[len(prefix):]
            and (path.endswith(".mbt") or path.endswith(".mbt.md"))
            for path in tracked
        )
        if not has_package_source:
            error(f"package {package_dir} must contain tracked MoonBit source")
            ok = False

    package_prefixes = {"" if package_dir == "." else f"{package_dir}/" for package_dir in package_dirs}
    for path in sorted(tracked):
        if not (
            path.endswith(".mbt")
            or path.endswith(".mbt.md")
            or path.endswith(".mbti")
            or path.endswith(".c")
        ):
            continue
        parent = str(pathlib.PurePosixPath(path).parent)
        prefix = "" if parent == "." else f"{parent}/"
        if prefix not in package_prefixes:
            error(f"tracked source file is outside a MoonBit package: {path}")
            ok = False

    forbidden_prefixes = (
        ".mooncakes/",
        ".moonagent/",
        ".repos/",
        "_build/",
        "__pycache__/",
    )
    for path in sorted(tracked):
        if (
            path.startswith(forbidden_prefixes)
            or path.endswith("/.DS_Store")
            or path == ".DS_Store"
            or "/__pycache__/" in f"/{path}/"
            or path.endswith(".pyc")
        ):
            error(f"generated/reference checkout path must not be tracked: {path}")
            ok = False

    required_fixtures = {
        "tests/fixtures/justhtml/LICENSE.justhtml",
        "tests/fixtures/justhtml/README.upstream.md",
        "tests/fixtures/justhtml/data/wikipedia.html",
        "tests/fixtures/justhtml/justhtml-sanitize-tests/cases.json",
        "tests/fixtures/justhtml/justhtml-tests/entities.test",
        "tests/fixtures/justhtml/justhtml-tests/tokenizer_edge_cases.test",
        "tests/fixtures/justhtml/justhtml-tests/treebuilder_coverage.dat",
        "tests/fixtures/justhtml/linkify-it/fixtures/links.txt",
        "tests/fixtures/justhtml/linkify-it/fixtures/not_links.txt",
    }
    for path in sorted(required_fixtures):
        if path not in tracked:
            error(f"expected vendored fixture is not tracked: {path}")
            ok = False

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
