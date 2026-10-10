#pragma once
#include <string>
#include <vector>

#include "IDetector.h"

namespace ms {

// Fixed order; index i of runAll() output belongs to detectors()[i].
const std::vector<IDetector *> &detectors();

// Runs every detector whose id is not in `disabled`. Skipped and failing detectors yield
// kUnsupported. Serialised: detectors keep per-process state.
std::vector<float> runAll(const std::vector<std::string> &disabled);

}  // namespace ms
