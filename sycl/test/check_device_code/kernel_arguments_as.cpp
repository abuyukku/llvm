// RUN: %clangxx -fsycl-device-only -Xclang -opaque-pointers -emit-llvm %s -S -o %t.ll -I %sycl_include -Wno-sycl-strict -Xclang -verify-ignore-unexpected=note,warning -Xclang -disable-llvm-passes
// RUN: FileCheck %s --input-file %t.ll --check-prefixes=CHECK,CHECK-DISABLE
// RUN: %clangxx -fsycl-device-only -Xclang -opaque-pointers -emit-llvm %s -S -o %t.ll -I %sycl_include -Wno-sycl-strict -Xclang -verify-ignore-unexpected=note,warning -Xclang -disable-llvm-passes -D__ENABLE_USM_ADDR_SPACE__
// RUN: FileCheck %s --input-file %t.ll --check-prefixes=CHECK,CHECK-ENABLE
//
// Check the address space of the pointer in accessor class.
//
// CHECK: %struct.AccWrapper = type { %"class.cl::sycl::accessor[[NUMBER_SUFFIX:\.?[0-9]*]]" }
// CHECK: %"class.cl::sycl::accessor[[NUMBER_SUFFIX]]" = type { %"class{{.*}}AccessorImplDevice", %[[UNION:.*]] }
// CHECK-DISABLE: %[[UNION]] = type { ptr addrspace(1) }
// CHECK-ENABLE: %[[UNION]] = type { ptr addrspace(5) }
// CHECK: %struct.AccWrapper.{{[0-9]+}} = type { %"class.cl::sycl::accessor.[[NUM:[0-9]+]]" }
// CHECK-NEXT: %"class.cl::sycl::accessor.[[NUM]]" = type { %"class{{.*}}LocalAccessorBaseDevice", ptr addrspace(3) }
//
// Check that kernel arguments doesn't have generic address space.
//
// CHECK-NOT: define weak_odr dso_local spir_kernel void @"{{.*}}check_adress_space"({{.*}}addrspace(4){{.*}})

#include <sycl/sycl.hpp>

using namespace sycl;

template <typename Acc> struct AccWrapper { Acc accessor; };

int main() {

  sycl::queue queue;
  int array[10] = {0};
  {
    sycl::buffer<int, 1> buf((int *)array, sycl::range<1>(10),
                             {sycl::property::buffer::use_host_ptr()});
    queue.submit([&](sycl::handler &cgh) {
      auto acc = buf.get_access<sycl::access::mode::read_write>(cgh);
      sycl::accessor<int, 1, sycl::access::mode::read_write,
                     sycl::access::target::local>
          local_acc(sycl::range<1>(10), cgh);
      auto acc_wrapped = AccWrapper<decltype(acc)>{acc};
      auto local_acc_wrapped = AccWrapper<decltype(local_acc)>{local_acc};
      cgh.parallel_for<class check_adress_space>(
          sycl::range<1>(buf.size()), [=](sycl::item<1> it) {
            auto idx = it.get_linear_id();
            acc_wrapped.accessor[idx] = local_acc_wrapped.accessor[idx];
          });
    });
    queue.wait();
  }

  return 0;
}
