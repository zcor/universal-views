# Curve Universal Views

This github contains smart contracts (and accompanying tests) on a Universal Views contract for running useful math (ie `get_dy` and `get_dx`) on any generic Curve pool.

# For developers

### To run tests:

```
> ape test
```

### To contribute

In order to contribute, please fork off of the `main` branch and make your changes there. Your commit messages should detail why you made your change in addition to what you did (unless it is a tiny change).

If you need to pull in any changes from `main` after making your fork (for example, to resolve potential merge conflicts), please avoid using `git merge` and instead, `git rebase` your branch

Please also include sufficient test cases, and sufficient docstrings. All tests must pass before a pull request can be accepted into `main`

### Smart Contract Security Vulnerability Reporting

Please refrain from reporting any smart contract vulnerabilities publicly. The best place to report first is [security@curve.fi](mailto:security@curve.fi).

### License

(c) Curve.Fi, 2023 - [All rights reserved](LICENSE).
