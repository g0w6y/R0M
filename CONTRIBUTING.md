# Contributing

```sh
./build.sh --no-install
scripts/test.sh
build/R0M.app/Contents/MacOS/R0M --diagnose
```

- `Sources/R0M/` holds the probes. Each reads data and returns a plain struct.
- `Sources/R0M/Views/` holds one file per sidebar page.
- Use `@Local` instead of `@State`. The newest SDK needs Xcode for `@State`, and `@Local` builds with the Command Line Tools alone.
- Anything that deletes files or needs admin rights must go through the Cleaner's safety check or `Admin.run`, and have a test.
- No dependencies, no network access, no analytics.
