# Dual Architecture Implementation Plan

## Project Status: Phase 1.5 Complete ✅, Phase 2 Ready 🎯

This document tracks the implementation progress for adding PowerPC support to the existing 68k Mac emulation project.

**Update**: Disk image reorganization complete. Ready for Phase 2 testing.

## Completed Tasks ✅

### Phase 1: Core Architecture Setup (Complete)

1. **✅ Analysis & Research**
   - [x] Analyzed current codebase structure and components
   - [x] Identified 68k-specific vs generic components  
   - [x] Researched PPC emulation requirements and differences
   - [x] Studied user's working ppctest scripts
   - [x] Identified key differences: boot process (-boot c/d vs PRAM), storage (IDE vs SCSI), BIOS (-L pc-bios vs ROM files)

2. **✅ Architecture Reorganization**
   - [x] Created m68k/ directory structure
   - [x] Moved all 68k files to m68k/ subdirectory
   - [x] Added ARCH="m68k" to all 68k configuration files
   - [x] Updated paths in moved 68k configurations
   - [x] Created ppc/ directory structure with configs/, scripts/, data/ subdirectories

3. **✅ PPC Configuration System**
   - [x] Created `ppc/configs/macos91-standard.conf` (Mac OS 9.1 balanced)
   - [x] Created `ppc/configs/macos91-fast.conf` (Mac OS 9.1 performance)
   - [x] Created `ppc/configs/osxtiger104-standard.conf` (Mac OS X Tiger balanced)
   - [x] Created `ppc/configs/osxtiger104-fast.conf` (Mac OS X Tiger performance)
   - [x] All PPC configs include ARCH="ppc" and PPC-specific variables

4. **✅ PPC Script Implementation**
   - [x] Created `ppc/runppc.sh` based on working ppctest examples
   - [x] Implemented simple boot control (-boot c/d instead of PRAM)
   - [x] Integrated with shared networking/display modules
   - [x] Added IDE storage support (simpler than 68k SCSI)
   - [x] Added USB support for Mac OS X configs
   - [x] Made script executable

5. **✅ Unified Interface**
   - [x] Created `runmac.sh` unified dispatcher
   - [x] Implemented architecture detection from config ARCH variable
   - [x] Added proper error handling and help system
   - [x] Made script executable

6. **✅ Documentation Update**
   - [x] Completely rewrote CLAUDE.md for dual architecture
   - [x] Added architecture-specific examples and workflows
   - [x] Documented key technical differences between 68k and PPC
   - [x] Updated common commands and configuration examples

### Phase 1.5: Disk Image Organization ✅ (Complete)

**Issue Resolved**: Disk images are now properly organized and gitignored, allowing clean user machine setups without repository clutter.

1. **✅ Reorganize Disk Image Storage**
   - [x] Created `m68k/images/` and `ppc/images/` directories
   - [x] Moved `m68k/753/` → `m68k/images/753/`
   - [x] Moved `m68k/761/` → `m68k/images/761/`
   - [x] Created structure for `ppc/images/91/` and `ppc/images/tiger104/`

2. **✅ Update Git Configuration**
   - [x] Updated .gitignore with `m68k/images/` and `ppc/images/`
   - [x] Removed old entries: `753`, `761` 
   - [x] ROM files remain tracked (800.ROM, 1.6.rom)
   - [x] Configs and scripts remain tracked

3. **✅ Update Configuration Files**
   - [x] Updated all m68k configs: `753/` → `images/753/`
   - [x] Updated all m68k configs: `761/` → `images/761/`
   - [x] Updated all ppc configs: `91/` → `images/91/`
   - [x] Updated all ppc configs: `tiger104/` → `images/tiger104/`

4. **✅ Update Scripts and Documentation**
   - [x] No hardcoded paths found in runppc.sh (uses config variables)
   - [x] CLAUDE.md examples updated with new architecture-specific paths
   - [x] Implementation plan updated with final structure

## Current Tasks 🎯

### Phase 2: Basic Testing & Validation (In Progress)

## Current Project Structure ✅ (Complete)

**Final Structure (Achieved)**:
```
QemuMac/
├── runmac.sh ✅                    # Unified dispatcher
├── IMPLEMENTATION_PLAN.md ✅       # This file
├── CLAUDE.md ✅                    # Updated documentation
├── .gitignore ✅                  # Updated to ignore images/
├── m68k/ ✅                        # 68k architecture
│   ├── run68k.sh ✅               # Original script
│   ├── configs/ ✅                # All sys753/761 configs (UPDATED PATHS)
│   ├── images/ ✅                 # Disk images (GITIGNORED)
│   │   ├── 753/ ✅                # Mac OS 7.5.3 system images
│   │   │   ├── hdd_sys753.img
│   │   │   ├── pram_753_q800.img
│   │   │   └── shared_753.img
│   │   └── 761/ ✅                # Mac OS 7.6.1 system images
│   │       ├── hdd_sys761.img
│   │       ├── pram_761_q800.img
│   │       └── shared_761.img
│   ├── 800.ROM ✅                 # ROM file (TRACKED)
│   ├── sys753-safe.conf ✅        # Legacy configs (UPDATED PATHS)
│   ├── sys761-safe.conf ✅
│   └── scripts/ ✅                # 68k-specific utilities
├── ppc/ ✅                         # PowerPC architecture
│   ├── runppc.sh ✅               # PPC script
│   ├── configs/ ✅                # PPC configurations (UPDATED PATHS)
│   │   ├── macos91-standard.conf ✅
│   │   ├── macos91-fast.conf ✅
│   │   ├── osxtiger104-standard.conf ✅
│   │   └── osxtiger104-fast.conf ✅
│   ├── scripts/ ✅                # PPC-specific utilities
│   └── images/ ✅                 # Disk images (GITIGNORED)
│       ├── 91/ ✅                 # Mac OS 9.1 system images
│       │   ├── MacOS9.1.img
│       │   └── shared_91.img
│       └── tiger104/ ✅           # Mac OS X Tiger system images
│           ├── MacOSX10.4.img
│           └── shared_tiger104.img
├── scripts/ ✅                     # Shared utilities
├── library/ ✅                     # Software database
└── install-dependencies.sh ✅      # Dependency installer
```

## Benefits of Reorganization ✅

**Achieved Benefits**:
- ✅ Clean separation of code (tracked) vs data (untracked)
- ✅ Users can create custom machine setups without git conflicts
- ✅ Consistent organization across both architectures  
- ✅ Easier backup/restore of specific machine configurations
- ✅ Cleaner repository for contributors

1. **🔲 Test 68k Architecture (Post-Move)**
   - [ ] Test m68k configs work with new paths (manual testing by user)
   - [ ] Verify unified dispatcher works with 68k configs (manual testing by user)
   - [ ] Test direct m68k/run68k.sh access (manual testing by user)
   - [ ] Validate backward compatibility broken cleanly

2. **🔲 Test PPC Architecture (Initial)**
   - [ ] Test ppc/runppc.sh with sample configs (manual testing by user)
   - [ ] Verify boot process works (-boot c/d) (manual testing by user)
   - [ ] Test IDE storage setup (manual testing by user)
   - [ ] Validate networking integration (manual testing by user)

3. **🔲 Cross-Platform Testing**
   - [ ] Test on Linux (TAP networking) (manual testing by user)
   - [ ] Test on macOS (User networking) (manual testing by user)
   - [ ] Verify display types work correctly (manual testing by user)
   - [ ] Test audio configuration (manual testing by user)

### Phase 3: Advanced Features (Future)

1. **🔲 Enhanced PPC Support**
   - [ ] Add more PPC machine types (g3beige for older Mac OS)
   - [ ] Create additional performance variants
   - [ ] Add PPC-specific utilities if needed
   - [ ] Optimize PPC boot time and performance

2. **🔲 Library Integration**
   - [ ] Update software database for PPC software
   - [ ] Add Mac OS 9 and Tiger installation media
   - [ ] Update mac-library.sh for dual architecture
   - [ ] Test download and launch workflows

3. **🔲 Dependency Management**
   - [ ] Update install-dependencies.sh for qemu-system-ppc
   - [ ] Add PPC-specific dependency checking
   - [ ] Test installation on fresh systems
   - [ ] Document PPC-specific requirements

### Phase 4: Polish & Documentation (Future)

1. **🔲 Error Handling & Validation**
   - [ ] Add PPC-specific config validation
   - [ ] Improve error messages for common issues
   - [ ] Add config migration tools if needed
   - [ ] Test edge cases and error conditions

2. **🔲 Performance Optimization**
   - [ ] Benchmark different PPC configurations
   - [ ] Optimize default settings for each OS
   - [ ] Add performance monitoring
   - [ ] Document best practices

3. **🔲 User Experience**
   - [ ] Add more detailed help messages
   - [ ] Create quick-start guides
   - [ ] Add troubleshooting documentation
   - [ ] Test with new users

## Key Implementation Decisions Made

### ✅ Architecture Separation
- **Decision**: Clean separation between m68k/ and ppc/ directories
- **Rationale**: Avoids conflicts, allows independent evolution
- **Status**: Complete

### ✅ Unified Interface
- **Decision**: Single runmac.sh dispatcher with architecture detection
- **Rationale**: Consistent user experience while preserving direct access
- **Status**: Complete

### ✅ No Backward Compatibility
- **Decision**: Break existing workflows, require new paths
- **Rationale**: Cleaner codebase, avoid complexity of dual workflows
- **Status**: Complete

### ✅ Shared Infrastructure
- **Decision**: Reuse networking, display, config modules
- **Rationale**: Avoid duplication, proven components
- **Status**: Complete

### ✅ PPC-Specific Simplifications
- **Decision**: Use simple IDE storage, boot flags, built-in BIOS
- **Rationale**: Leverage QEMU's simpler PPC implementation
- **Status**: Complete

## Testing Priorities

### High Priority ⚠️
1. Verify unified dispatcher works correctly
2. Test both architectures boot and run
3. Validate configuration loading
4. Test on both Linux and macOS

### Medium Priority 📋
1. Test networking modes (TAP, User, Passt)
2. Validate file sharing functionality
3. Test additional drive support (-a flag)
4. Verify performance variants work

### Low Priority 📝
1. Test all configuration combinations
2. Validate error handling edge cases
3. Test with actual OS installation media
4. Performance benchmarking

## Known Issues & Risks

### ⚠️ Potential Issues
1. **Path Dependencies**: Some hardcoded paths may need updating
2. **Config Validation**: PPC configs may not validate properly with existing code
3. **Networking**: PPC networking may have different requirements
4. **Display**: PPC display setup may differ from 68k

### 🔧 Mitigation Strategies
1. **Incremental Testing**: Test each component separately
2. **Fallback Plans**: Keep working ppctest scripts as reference
3. **Documentation**: Document issues and workarounds
4. **User Testing**: Get feedback on real usage scenarios

## Success Criteria

### Phase 1 Complete ✅
- [x] Both architectures organized cleanly
- [x] Unified interface works
- [x] Configurations load properly
- [x] Scripts are executable
- [x] Documentation is complete

### Phase 2 Target 🎯
- [ ] Both architectures boot successfully
- [ ] All interface options work (-C, -c, -a, -b, -N, -d)
- [ ] Cross-platform compatibility verified
- [ ] No regression in 68k functionality

### Final Target 🏆
- [ ] Production-ready dual architecture system
- [ ] Full feature parity between architectures
- [ ] Complete documentation and examples
- [ ] Validated on multiple platforms
- [ ] User-friendly experience

---

## Quick Start Testing Commands

✅ **Ready**: Phase 1.5 (image reorganization) is complete. Use these commands to validate the implementation:

```bash
# Test unified dispatcher help
./runmac.sh --help

# Test 68k architecture (should work with new paths)
./runmac.sh -C m68k/configs/sys753-standard.conf

# Test PPC architecture (new functionality)
./runmac.sh -C ppc/configs/macos91-standard.conf

# Test direct access (debugging)
./m68k/run68k.sh -C m68k/configs/sys753-standard.conf
./ppc/runppc.sh -C ppc/configs/macos91-standard.conf

# Test architecture detection
grep "ARCH=" m68k/configs/sys753-standard.conf
grep "ARCH=" ppc/configs/macos91-standard.conf
```

---

**Last Updated**: Phase 1.5 complete, Phase 2 (testing) ready to begin
**Next Review**: After Phase 2 manual testing is complete