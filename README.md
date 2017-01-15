# commandLineArgumentsParser

This is currently a wrapper around `cliargs` to provide a more useful API as there is not an implementation of `DocOpt` for Lua that works. In the future we may replace `cliargs` as the quality of its code, and its design, is poor, with attrocious naming (`set_colsz` instead of `set_option_and_description_column_sizes`), a failure to separate concerns and a developer who doesn't fully understand the differeces in pass-by-reference and pass-by-copy. Documentation is intentionally not provided at this time as the API is extremely unstable.

The license is MIT.
