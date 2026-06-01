# Re-exporting Concrete Types and Constructors

This note uses the tokenizer facade as a concrete motivation for polishing
MoonBit re-export semantics.

## Motivation

MoonBit already has a compact facade mechanism:

```moonbit
pub using @tok {
  type HtmlToken,
  type TagKind,
  type TagToken,
}
```

That works well for grouping public APIs at package boundaries. The rough edge
appears when a re-exported type is concrete and its constructors or fields are
part of the intended public contract.

In this repository, changing the public tokenizer package to re-export
`TagKind` from `bobzhang/html_parser/internal/tokenizer` makes blackbox tests
fail unless the root package also imports the internal tokenizer package:

```text
Cannot destruct value of type
@bobzhang/html_parser/internal/tokenizer.TagKind:
package bobzhang/html_parser/internal/tokenizer is not imported.
```

That is surprising because the visible facade API still says that `TagKind` is
available through the public tokenizer package, while practical use of
`StartTag` and `EndTag` still depends on the original defining package.

## Design Goals

1. A public facade should be enough for downstream users to construct and
   destruct values that the facade intentionally exposes.
2. Re-exporting a concrete type from an `internal` package must be explicit
   enough that API owners notice they are committing to that representation.
3. Abstract re-exports must remain possible. A package may want to expose type
   identity without exposing constructors, record literals, or mutable fields.
4. Generated interfaces should show the real public contract. If a facade
   exports constructors, the `.mbti` should not force readers to discover an
   implementation package by compiler error.
5. Constructor availability should preserve the original type visibility:
   abstract types expose no representation, read-only types allow observation,
   and `pub(all)` types allow the full public construction and pattern surface.

## Current Friction

Today, `pub using @pkg { type T }` gives the facade a public type name, but
constructor use still follows the defining package identity. This creates three
practical problems:

1. A concrete enum re-export is not self-contained for pattern matching.
2. Public blackbox tests may need an otherwise-unused import of an internal
   package, leading to `unused_package` warnings.
3. The generated interface can make the facade look concrete while the compiler
   still asks users to import the underlying internal package for constructors.

The tokenizer example is small, but the issue generalizes to any package that
wants to centralize exports without duplicating concrete wrapper types.

## Prior Art

MoonBit already treats packages as compilation and visibility boundaries.
Package imports are declared in `moon.pkg`; `pub using` re-exports names from an
imported package; and `internal` package paths are intentionally restricted to
the parent package tree. These rules are documented in the MoonBit language and
package manuals:

- <https://docs.moonbitlang.com/en/latest/language/packages.html>
- <https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html>

Rust provides a useful comparison: `pub use` can expose an item through a public
module facade even if the defining path is not the public path users should
depend on. Rust enum variants are also importable items, so constructor names
can move with the facade when they are re-exported:

- <https://doc.rust-lang.org/reference/items/use-declarations.html>
- <https://doc.rust-lang.org/reference/visibility-and-privacy.html>

Go's `internal` package convention is relevant for the privacy side: code may
only import an internal package from within the parent tree, but a parent
package can still expose a stable public wrapper:

- <https://pkg.go.dev/cmd/go#hdr-Internal_Directories>

TypeScript separates type-only imports/exports from value exports. This is a
good reminder that type identity and constructor/value availability are related
but distinct surfaces:

- <https://www.typescriptlang.org/docs/handbook/release-notes/typescript-3-8.html>

OCaml signatures are also instructive: APIs can expose a type abstractly,
expose it as a manifest alias, or expose private/concrete representation with
different construction rights. That model suggests that MoonBit should keep
"type name" and "representation operations" explicit:

- <https://ocaml.org/manual/5.3/privatetypes.html>
- <https://ocaml.org/manual/5.3/moduleexamples.html>

## Design Options

### Option A: Keep Type-only Re-exports

`pub using @pkg { type T }` continues to export only the type name. Constructors
and fields remain available only through the defining package.

This is conservative, but it leaves concrete facade APIs in a half-exposed
state. It also pushes users toward importing implementation packages merely to
match values.

### Option B: Automatically Re-export Constructors

`pub using @pkg { type T }` re-exports constructor and field access according to
the original type's visibility.

This is ergonomic and matches many users' expectations for concrete `pub(all)`
types. The risk is that it may unintentionally expose internal representation as
public API when a facade author only wanted a type alias.

### Option C: Add Explicit Constructor Re-export Syntax

Keep `type T` as type-name-only, and add syntax for representation re-export:

```moonbit
pub using @impl {
  type TagKind(..),       // all visible constructors
  type HtmlToken(Tag),    // selected enum constructors
  type TagToken { .. },   // visible record fields and construction surface
}
```

The exact syntax is open, but the important distinction is that exporting type
identity and exporting representation operations are separate, reviewable
choices.

This gives API authors three clear modes:

1. `type T`: expose type identity only.
2. `type T(..)`: expose all visible enum constructors or record construction
   operations through the facade.
3. `type T(A, B)` or `type T { field }`: expose a selected representation
   surface if MoonBit wants finer-grained control.

### Option D: Forbid Public Re-export of Concrete Internal Types

The compiler could reject public re-exports of concrete types from `internal`
packages unless the re-exporting package defines a wrapper type.

This strongly protects internal boundaries, but it makes facade packages more
verbose and loses useful type identity sharing. It also conflicts with the
practical desire to have internal packages implement public APIs.

## Recommendation

Prefer Option C, with one compatibility-oriented extension:

1. Introduce explicit representation re-export syntax for constructors and
   fields.
2. Allow representation re-export from `internal` packages when the re-exporting
   package is allowed to import the internal package.
3. Treat the re-exporting package as a valid public access path for those
   constructors and fields. Downstream users should not need to import the
   internal package.
4. Add a warning when a public package re-exports a concrete `pub(all)` type from
   an `internal` package without also specifying whether representation is
   exposed or hidden.
5. Make `.mbti` generation preserve that decision so reviewers can tell whether
   a facade exports only type identity or also representation.

Under this design, a public tokenizer facade could choose either:

```moonbit
pub using @impl { type TagKind }
```

for an abstract-ish public type name, or:

```moonbit
pub using @impl { type TagKind(..) }
```

for a public enum whose `StartTag` and `EndTag` constructors can be matched
through the facade.

## Open Questions

1. Should `type T(..)` expose constructors in both expression and pattern
   positions, or should MoonBit distinguish pattern-only visibility for
   read-only concrete types?
2. Should selected constructor re-exports be supported initially, or is
   all-or-nothing enough for a first implementation?
3. Should re-exporting a concrete type from an internal package require a
   stronger spelling than re-exporting from a normal public package?
4. Should aliases be allowed to rename constructors, or should constructor names
   remain tied to the original type definition?
5. How should documentation search and `moon ide` present the canonical path:
   the defining package, the re-exporting package, or both?

## Suggested Compiler Tests

1. A public package re-exports `type T` from another public package. A consumer
   can name `T` but cannot use constructors unless they are explicitly exported.
2. A public package re-exports `type T(..)` from another public package. A
   consumer can construct and pattern match through the facade.
3. A public package re-exports `type T(..)` from an internal package. A consumer
   outside the internal tree can construct and pattern match through the facade
   without importing the internal package.
4. A public package re-exports `type T` from an internal package. A consumer
   outside the internal tree can pass values around but cannot name or match
   constructors.
5. Generated `.mbti` files distinguish type-only re-exports from representation
   re-exports.

