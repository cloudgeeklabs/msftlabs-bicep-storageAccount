# Changelog

All notable changes to this Bicep module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

### Planned
- Data Lake Gen2 support enhancement
- Network rules configuration
- Lifecycle management policies
- Blob versioning support

## [1.0.1] - 2026-02-07

### Added
- Support creating for Private Endpoints on Storage Account
- Configure PublicNetworkAccess (default=disable) and include @allowedValues(enable, disable)
- Configure publicNetworkAccess: 'string' @allowedValues('Disabled','Enabled','SecuredByPerimeter') | default='Disabled'
- Support for immutableStorageWithVersioning
- Support for setting isHnsEnabled | Default=false
- Support for configuring Availability Zones

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

---
[Unreleased]: https://github.com/cloudgeeklabs/msftlabs-bicep-storageAccount/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/cloudgeeklabs/msftlabs-bicep-storageAccount/releases/tag/v1.0.0
