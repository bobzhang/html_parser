# JustHTML Fixtures

This directory vendors fixture data from the local reference checkout at
`.repos/justhtml`.

The reference project is MIT licensed; see `LICENSE.justhtml`. The Python
reference checkout itself is intentionally ignored and is not part of this
repository. MoonBit tests should read fixture data from this directory so the
test suite is reproducible without a sibling checkout.

Keep fixture updates mechanical:

- Copy upstream data files without local edits.
- Add MoonBit harness code separately.
- Record any intentionally disabled fixture group in the test harness.
