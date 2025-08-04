# QemuMac Refactoring Implementation Plan

This document outlines the implementation plan for the most valuable refactoring opportunities identified in the QemuMac project. The plan focuses on eliminating code duplication, improving maintainability, and creating a cleaner architecture.

## Current State Analysis

- **Code Duplication**: ~800+ lines of duplicated code across runner scripts
  - `m68k/run68k.sh`: 571 lines
  - `ppc/runppc.sh`: 453 lines  
  - `runmac.sh`: 135 lines (dispatcher)
- **Configuration Complexity**: Scattered config logic across multiple files
- **Storage Management**: Duplicated disk preparation logic

## Refactoring Phases

### Phase 1: Consolidate Runner Scripts (Highest Priority)

**Objective**: Eliminate massive code duplication in runner scripts by creating a unified execution system.

**Implementation Steps**:

1. **Create unified `run.sh`**
   - Replace `runmac.sh`, `m68k/run68k.sh`, and `ppc/runppc.sh`
   - Handle all argument parsing in single location
   - Auto-detect architecture from config file
   - Route execution to architecture-specific handlers

2. **Extract architecture-specific logic**
   - Create `m68k/scripts/m68k-runner.sh` for 68k-specific QEMU execution
   - Create `ppc/scripts/ppc-runner.sh` for PowerPC-specific QEMU execution
   - Keep only the unique logic (SCSI vs IDE, ROM vs BIOS, etc.)

3. **Unify common operations**
   - Single argument parsing system
   - Unified config loading
   - Common network setup
   - Shared display configuration
   - Common cleanup procedures

4. **Remove legacy scripts**
   - Delete `m68k/run68k.sh`, `ppc/runppc.sh`, and `runmac.sh`
   - Update all documentation and examples
   - Update CLAUDE.md files

**Expected Reduction**: ~600-700 lines of duplicated code

### Phase 2: Centralize Configuration System (High Priority)

**Objective**: Create a single, robust configuration management system that handles both architectures.

**Implementation Steps**:

1. **Enhance `scripts/qemu-config.sh`**
   - Make it the single source for all config operations
   - Remove config logic from individual runner scripts
   - Implement generic validation system

2. **Create architecture-agnostic validation**
   - Use associative arrays to define requirements per architecture
   - Single validation function that works for both 68k and PowerPC
   - Centralized default value assignment

3. **Consolidate config schemas**
   ```bash
   # Example structure
   declare -A ARCH_REQUIRED_VARS=(
       ["m68k"]="QEMU_ROM QEMU_PRAM QEMU_MACHINE"
       ["ppc"]="QEMU_MACHINE"
   )
   ```

4. **Update architecture handlers**
   - Remove config validation from `m68k-runner.sh` and `ppc-runner.sh`
   - Use centralized config system exclusively

**Expected Benefits**:
- Single point of configuration maintenance
- Easier to add new architectures
- Consistent error messages and validation

### Phase 3: Streamline Storage Management (Medium Priority)

**Objective**: Consolidate all disk image preparation logic into the storage module.

**Implementation Steps**:

1. **Audit current disk logic**
   - Identify duplicated disk preparation in `ppc/runppc.sh`
   - Document differences between 68k SCSI and PowerPC IDE handling

2. **Enhance `scripts/qemu-storage.sh`**
   - Move remaining disk prep logic from PowerPC script
   - Create unified `prepare_disk_images()` function
   - Handle both SCSI (68k) and IDE (PowerPC) in same module

3. **Standardize disk image handling**
   - Consistent image creation procedures
   - Unified cache mode handling
   - Common disk validation logic

4. **Update architecture handlers**
   - Remove disk preparation from `ppc-runner.sh`
   - Use storage module exclusively for all disk operations

**Expected Benefits**:
- Consistent disk image handling
- Reduced maintenance for storage features
- Easier to add new storage configurations

## Implementation Strategy

### Development Approach
- **No backward compatibility constraints** - focus on clean, modern implementation
- **Test-driven approach** - verify each phase before proceeding
- **Incremental implementation** - complete each phase fully before starting next
- **Clean removal** - delete old files once new system is proven working

### Testing Strategy
1. **Functionality Testing**
   - Test all existing configuration files with new system
   - Verify both installation (`-b` flag) and runtime modes
   - Test additional drive support (`-a` flag)
   - Validate network mode switching (`-N` parameter)

2. **Performance Testing**
   - Compare performance between old and new systems
   - Test all performance variants (standard/fast/ultimate)
   - Verify cache modes and AIO settings work correctly

3. **Platform Testing**
   - Test on both Linux (TAP networking) and macOS (user networking)
   - Verify display modes work on different platforms
   - Test file sharing functionality

### Documentation Updates
- Update main `CLAUDE.md` with new unified interface
- Update architecture-specific `CLAUDE.md` files
- Revise `README.md` examples and usage instructions
- Update `CHANGELOG.md` with breaking changes and migration notes

## Expected Benefits

### Code Quality Improvements
- **Reduce codebase by ~800+ lines** of duplicated code
- **Single maintenance point** for common functionality
- **Reduced bug surface area** from eliminating code duplication
- **Improved code organization** with clear separation of concerns

### User Experience Improvements
- **Consistent interface** - single `run.sh` for all emulation
- **Better error messages** from centralized validation
- **Easier troubleshooting** with unified logging and error handling
- **Simplified documentation** with single entry point

### Developer Experience Improvements
- **Easier to add new architectures** or configurations
- **Faster development** with shared infrastructure
- **Better testing** with unified test surface
- **Cleaner architecture** following single responsibility principle

## Risk Mitigation

### Potential Risks
- **Breaking existing workflows** during transition
- **Performance regression** from architectural changes
- **Complex testing matrix** across configurations and platforms

### Mitigation Strategies
- **Thorough testing** at each phase before proceeding
- **Performance benchmarking** to ensure no regressions
- **Incremental rollout** with ability to revert if issues found
- **Comprehensive documentation** of changes and new patterns

## Timeline Estimate

- **Phase 1**: 2-3 days (runner consolidation)
- **Phase 2**: 1-2 days (config centralization)  
- **Phase 3**: 1 day (storage streamlining)
- **Testing & Documentation**: 1-2 days

**Total Estimated Time**: 5-8 days

## Success Criteria

1. **Functionality**: All existing configurations work with new system
2. **Performance**: No performance regressions in any test scenario
3. **Code Quality**: Significant reduction in code duplication and complexity
4. **User Experience**: Simplified interface with better error handling
5. **Maintainability**: Easier to add new features and configurations

This refactoring plan will transform the QemuMac codebase into a more maintainable, extensible, and user-friendly system while eliminating hundreds of lines of duplicated code.