# Changelog

All notable changes to this Bicep module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Data Lake Gen2 support enhancement
- Network rules configuration
- Lifecycle management policies
- Blob versioning support

## [1.0.0] - 2026-02-07

### Added
- Initial release of Storage Account module
- Storage Account creation with secure defaults
- OAuth authentication enabled by default
- Disabled shared key access and public blob access
- TLS 1.2 enforcement
- Blob container service support with variable containers
- Queue service support with variable queues
- Table service support with variable tables
- Private endpoint configuration support
- Diagnostic settings with Log Analytics workspace integration
- Default workspace fallback configuration
- Resource lock (CanNotDelete) implementation
- RBAC role assignment support
- Comprehensive tagging support
- Custom type definitions for complex parameters

### Testing
- Pester 5.x unit tests with full module validation
- Native Bicep build and what-if testing
- PSRule analysis for Azure best practices
- Test parameters and configuration files

### CI/CD
- Static analysis workflow (static-test.yaml)
- Unit testing workflow using Pester (unit-tests.yaml)
- Automated ACR deployment workflow (deploy-module.yaml)
- GitHub Actions integration with test result publishing
- Automated version tagging and release creation

### Security
- Secure by default configuration
- No public blob access
- Shared key access disabled
- OAuth authentication enforced
- TLS 1.2 minimum version

### Documentation
- Comprehensive README with usage examples
- Testing documentation and guidelines
- CI/CD workflow documentation
- Development best practices
- Demo script for student walkthrough
- Quick start guide
- Example deployment files
- Type definitions documentation

## Version History Reference

### Version 1.0.0 Features

- Production-ready storage account deployment
- Enterprise security defaults
- Governance capabilities (locks, RBAC, diagnostics)
- Multi-service support (blobs, queues, tables)
- ACR publishing ready

---

## Upgrade Guide

### From 0.x to 1.0.0

This is the initial release. No upgrade path required.

---

## Deprecation Notices

None at this time.

---

## Breaking Changes

None in version 1.0.0 (initial release).

---

## Contributors

- Microsoft Labs Training Team
- Brian Mitchell (bemitchell@cloudgeeklabs.com)

---

[Unreleased]: https://github.com/cloudgeeklabs/msftlabs-bicep-storageAccount/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/cloudgeeklabs/msftlabs-bicep-storageAccount/releases/tag/v1.0.0
