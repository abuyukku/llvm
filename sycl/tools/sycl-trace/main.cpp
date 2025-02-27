//==------------ main.cpp - SYCL Tracing Tool ------------------------------==//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "launch.hpp"
#include "llvm/Support/CommandLine.h"

#include <iostream>
#include <string>

using namespace llvm;

enum ModeKind { PI, ZE };
enum PrintFormatKind { PRETTY_COMPACT, PRETTY_VERBOSE, CLASSIC };

int main(int argc, char **argv, char *env[]) {
  cl::list<ModeKind> Modes(
      cl::desc("Available tracing modes:"),
      cl::values(
          // TODO graph dot
          clEnumValN(PI, "plugin", "Trace Plugin Interface calls"),
          clEnumValN(ZE, "level_zero", "Trace Level Zero calls")));
  cl::opt<PrintFormatKind> PrintFormat(
      "print-format", cl::desc("Print format"),
      cl::values(
          clEnumValN(PRETTY_COMPACT, "compact", "Human readable compact"),
          clEnumValN(PRETTY_VERBOSE, "verbose", "Human readable verbose"),
          clEnumValN(
              CLASSIC, "classic",
              "Similar to SYCL_PI_TRACE, only compatible with PI layer")));
  cl::opt<std::string> TargetExecutable(
      cl::Positional, cl::desc("<target executable>"), cl::Required);
  cl::list<std::string> Argv(cl::ConsumeAfter,
                             cl::desc("<program arguments>..."));

  cl::ParseCommandLineOptions(argc, argv);

  std::vector<std::string> NewEnv;

  {
    size_t I = 0;
    while (env[I] != nullptr)
      NewEnv.emplace_back(env[I++]);
  }

  NewEnv.push_back("XPTI_FRAMEWORK_DISPATCHER=libxptifw.so");
  NewEnv.push_back("XPTI_SUBSCRIBERS=libsycl_pi_trace_collector.so");
  NewEnv.push_back("XPTI_TRACE_ENABLE=1");

  const auto EnablePITrace = [&]() {
    NewEnv.push_back("SYCL_TRACE_PI_ENABLE=1");
  };
  const auto EnableZETrace = [&]() {
    NewEnv.push_back("SYCL_TRACE_ZE_ENABLE=1");
    NewEnv.push_back("ZE_ENABLE_TRACING_LAYER=1");
  };

  for (auto Mode : Modes) {
    switch (Mode) {
    case PI:
      EnablePITrace();
      break;
    case ZE:
      EnableZETrace();
      break;
    }
  }

  if (PrintFormat == CLASSIC) {
    NewEnv.push_back("SYCL_TRACE_PRINT_FORMAT=classic");
  } else if (PrintFormat == PRETTY_VERBOSE) {
    NewEnv.push_back("SYCL_TRACE_PRINT_FORMAT=verbose");
  } else {
    NewEnv.push_back("SYCL_TRACE_PRINT_FORMAT=compact");
  }

  if (Modes.size() == 0) {
    EnablePITrace();
    EnableZETrace();
  }

  std::vector<std::string> Args;

  Args.push_back(TargetExecutable);
  std::copy(Argv.begin(), Argv.end(), std::back_inserter(Args));

  int Err = launch(TargetExecutable.c_str(), Args, NewEnv);

  if (Err) {
    std::cerr << "Failed to launch target application. Error code " << Err
              << "\n";
    return Err;
  }

  return 0;
}
