// Copyright 2025-present the zvec project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
#pragma once

#include <functional>
#include <zvec/core/framework/index_helper.h>
#include <zvec/core/framework/index_holder.h>
#include <zvec/core/framework/index_meta.h>
#include <zvec/core/framework/index_runner.h>

namespace zvec {
namespace core {

class IndexBuilder : public IndexRunner {
 public:
  typedef std::shared_ptr<IndexBuilder> Pointer;

  //! Progress callback type: (current_count, total_count)
  using ProgressCallback = std::function<void(uint32_t, uint32_t)>;

  //! Destructor
  virtual ~IndexBuilder(void) {}

  //! Set progress callback for build operations
  void set_progress_callback(ProgressCallback callback) {
    progress_callback_ = std::move(callback);
  }

  //! Initialize the builder
  virtual int init(const IndexMeta & /*meta*/,
                   const ailego::Params & /*params*/) {
    return IndexError_NotImplemented;
  }

  //! Train and build the index
  static int TrainAndBuild(const IndexBuilder::Pointer &builder,
                           IndexHolder::Pointer holder) {
    auto two_pass_holder = IndexHelper::MakeTwoPassHolder(std::move(holder));
    int ret = builder->train(two_pass_holder);
    if (ret == 0) {
      ret = builder->build(std::move(two_pass_holder));
    }
    return ret;
  }

  //! Train, build and dump the index
  static int TrainBuildAndDump(const IndexBuilder::Pointer &builder,
                               IndexHolder::Pointer holder,
                               const IndexDumper::Pointer &dumper) {
    int ret = IndexBuilder::TrainAndBuild(builder, std::move(holder));
    if (ret == 0) {
      ret = builder->dump(dumper);
    }
    return ret;
  }
 protected:
  ProgressCallback progress_callback_;
};

}  // namespace core
}  // namespace zvec
