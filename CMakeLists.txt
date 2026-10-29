# This file is part of the TrinityCore Project. See AUTHORS file for Copyright information
#
# This file is free software; as a special exception the author gives
# unlimited permission to copy and/or distribute it, with or without
# modifications, as long as this notice is preserved.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY, to the extent permitted by law; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

cmake_minimum_required(VERSION 3.24)

# add this options before PROJECT keyword
set(CMAKE_DISABLE_SOURCE_CHANGES ON)
set(CMAKE_DISABLE_IN_SOURCE_BUILD ON)

# Set projectname (must be done AFTER setting configurationtypes)
project(WoWForever)

if(POLICY CMP0144)
  cmake_policy(SET CMP0144 NEW) # find_package() uses upper-case <PACKAGENAME>_ROOT variables
endif()

if(POLICY CMP0153)
  cmake_policy(SET CMP0153 NEW) # The exec_program() command should not be called
endif()

# ---------------------------------------------------------------------------
# Forever local customization (leewheel, 2026-10-01) -- Simplified Chinese / UTF-8 support
# Built with Visual Studio 2026 on a Chinese (codepage 936 / GBK) system.
# Core targets already receive /utf-8 via trinity-compile-option-interface, but the
# third-party libraries under dep/ and the .rc resource compiler do NOT.  On a GBK
# system any UTF-8 Simplified Chinese comment or string literal in those files is
# misread as GBK, producing C4819 warnings or garbled literals.  Apply UTF-8
# globally so every target (dep included) treats sources as UTF-8.
if(MSVC)
  # /utf-8: source charset AND execution charset are both UTF-8 (implies /validate-charset)
  add_compile_options(/utf-8)
  # rc.exe (resource compiler): interpret resource scripts as UTF-8 (codepage 65001)
  set(CMAKE_RC_FLAGS "${CMAKE_RC_FLAGS} /c65001")
  # /Zm200: raise MSVC's compiler memory-allocation limit. A full (post-clean) rebuild compiles
  # scripts/game/PlayerbotV2 in parallel, and each cl.exe loads the huge scriptPCH; the default
  # heap then trips "C3859: could not create virtual memory for PCH" / "C1076: compiler limit:
  # internal heap limit reached". Incremental builds were unaffected, so this only bites on a
  # clean rebuild of the whole tree.
  add_compile_options(/Zm200)
  message(STATUS "Forever: /utf-8 enabled globally - Simplified Chinese comments/strings safe in ALL targets (incl. dep/ and .rc)")
endif()
# ---------------------------------------------------------------------------

# Set RPATH-handing (CMake parameters)
set(CMAKE_SKIP_BUILD_RPATH 0)
set(CMAKE_BUILD_WITH_INSTALL_RPATH 0)
list(APPEND CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH 1)

# set macro-directory
list(APPEND CMAKE_MODULE_PATH
  "${CMAKE_SOURCE_DIR}/cmake/macros")

# build in Release-mode by default if not explicitly set
if(CMAKE_GENERATOR STREQUAL "Ninja Multi-Config")
  set(CMAKE_DEFAULT_BUILD_TYPE "RelWithDebInfo" CACHE INTERNAL "")
endif()
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "RelWithDebInfo")
endif()

include(CheckCXXSourceRuns)
include(CheckIncludeFiles)
include(ConfigureScripts)

# set default buildoptions and print them
include(cmake/options.cmake)

# turn off PCH totally if enabled (hidden setting, mainly for devs)
if(NOPCH)
  set(USE_COREPCH 0)
  set(USE_SCRIPTPCH 0)
endif()

include(ConfigureBaseTargets)
include(CheckPlatform)

include(GroupSources)
include(AutoCollect)

find_package(PCHSupport)

if(NOT WITHOUT_GIT)
  find_package(Git 1.7)
endif()

# find mysql client binary (needed by genrev)
find_package(MySQL OPTIONAL_COMPONENTS binary)

# Find revision ID and hash of the sourcetree
include(cmake/genrev.cmake)

# print out the results before continuing
include(cmake/showoptions.cmake)

# add dependencies
add_subdirectory(dep)

# add core sources
add_subdirectory(src)

include(CTest)
if(BUILD_TESTING)
  list(APPEND CMAKE_MODULE_PATH
    "${Catch2_SOURCE_DIR}/extras")
  include(Catch)

  add_subdirectory(tests)

  # Catch cmakefile messes with our settings we explicitly leave up to the user
  # restore user preference
  if (NOT WITH_SOURCE_TREE STREQUAL "hierarchical-folders")
    set_property(GLOBAL PROPERTY USE_FOLDERS OFF)
  endif()
endif()
